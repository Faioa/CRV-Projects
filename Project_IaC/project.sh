#!/bin/sh

PROFILE_NAME="crv-cluster-iac"
DEFAULT_DIR="$(dirname $(realpath $0))"

if [[ -z $2 ]]; then
  CONFIG_DIR="$DEFAULT_DIR/configs"
  STATE_FILE="$DEFAULT_DIR/.state"
else
  if [[ ! -d $(realpath $2) ]]; then
    echo -e "\033[0;31mERROR: Directory \"$(realpath $2)\" doesn't exist.\033[0m" >&2
    exit 1
  fi
  CONFIG_DIR="$(realpath $2)/configs"
  STATE_FILE="$(realpath $2)/.state"
fi

MINIKUBE_OPTIONS="--memory=4096 --cpus=4 --disable-driver-mounts"
REQUIRED_FILES=("monitoring-namespace.yaml"\
                "grafana/grafana.yaml"\
                "grafana/grafana-pvc.yaml"\
                "grafana/grafana-config-template.yaml"\
                "node-redis/node-redis.yaml"\
                "node-redis/node-redis-autoscaler.yaml"\
                "prometheus/prometheus-cluster-role.yaml"\
                "prometheus/prometheus-config.yaml"\
                "prometheus/prometheus-pvc.yaml"\
                "prometheus/prometheus-template.yaml"\
                "redis/redis.yaml"\
                "redis/redis-pvc.yaml"\
                "redis-react/redis-react-template.yaml"\
                "redis-replica/redis-replica.yaml"\
                "redis-replica/redis-replica-autoscaler.yaml"\
                "ingress.yaml")
USED_FILES=("monitoring-namespace.yaml"\
            "grafana/grafana-pvc.yaml"\
            "prometheus/prometheus-pvc.yaml"\
            "redis/redis-pvc.yaml"\
            "grafana/grafana.yaml"\
            "grafana/grafana-config.yaml"\
            "node-redis/node-redis.yaml"\
            "node-redis/node-redis-autoscaler.yaml"\
            "prometheus/prometheus-cluster-role.yaml"\
            "prometheus/prometheus-config.yaml"\
            "prometheus/prometheus.yaml"\
            "redis/redis.yaml"\
            "redis-react/redis-react.yaml"\
            "redis-replica/redis-replica.yaml"\
            "redis-replica/redis-replica-autoscaler.yaml"\
            "ingress.yaml")
DELETE_FILES=("grafana/grafana-config.yaml"\
              "prometheus/prometheus.yaml"\
              "redis-react/redis-react.yaml")

help_cmd() {
  echo -e "\033[1;34mUsage : $0 {start|stop|delete|dashboard|help} [project_dir]\033[0m"
  echo "       start - Starts the cluster and create the resources if they don't exist"
  echo "        stop - Stops the cluster without cleaning the resources"
  echo "        stop - Stops the cluster and deletes all resources"
  echo "   dashboard - Starts Minikube's dashboard, display the URL and opens it in your browser"
  echo "        help - Displays details on the usage of this script"
  echo " project_dir - Directory containing the necessary files and directories for the cluster to be launched successfully"
  echo "               The default directory is \"$DEFAULT_DIR\" and it should follow the following architecture :"
  echo "                 _"
  echo "                 |- configs/ : The directory containing all the configuration files for Kubernetes"
  echo "                 |-   .state : The file describing the state of the cluster (0 = doesn't exist, 1 = running, 2 = stopped)"
  exit 0
}

check_command() {
  if [[ $? -ne 0 ]]; then
    echo -e "\033[0;31mERROR : stopping the script...\033[0m"
    $1 >/dev/null 2>&1
    exit $?
  fi
}

verify_CONFIG_DIR() {
  local CONFIG_DIR=$1

  if [[ ! -d $CONFIG_DIR ]]; then
    echo -e "\033[0;31mERROR: Config directory \"$CONFIG_DIR\" not found\033[0m" >&2
    exit 1
  fi

  for file in "${REQUIRED_FILES[@]}"; do
    if [[ ! -f $CONFIG_DIR/$file ]]; then
      echo -e "\033[0;31mERROR: Required file \"$CONFIG_DIR/$file\" not found\033[0m" >&2
      exit 1
    fi
  done

  echo -e "\033[1;34mUsing configuration from: \"$CONFIG_DIR\"\033[0m"
}

get_state() {
  if [[ ! -f $STATE_FILE ]]; then
    echo -e "\033[0;31mERROR: File describing the state of the cluster was not found. Make sure that the cluster was started at least one time and that the file is correctly located at \"${STATE_FILE}\".\033[0m" >&2
    exit 2
  fi

  cat $STATE_FILE
}

start_cluster() {
  if [[ ! -f $STATE_FILE ]]; then
    echo "0" > $STATE_FILE
    verify_CONFIG_DIR "$CONFIG_DIR"
  else
    tmp=$(get_state)
    if [[ $tmp = "1" ]]; then
      echo -e "\033[0;31mERROR: A previous running instance of the cluster was found. Please delete it before starting another one.\033[0m" >&2
      exit 2
    fi
    verify_CONFIG_DIR "$CONFIG_DIR"
  fi

  if [[ $tmp = "2" ]]; then
     echo "A previous stopped instance of the cluster was found : Restarting previous instance..."
        minikube -p $PROFILE_NAME start >/dev/null
        check_command
        echo -e "\033[1;34mDone !\033[0m"
  else
    echo "Starting Minikube cluster..."
    minikube -p $PROFILE_NAME start $MINIKUBE_OPTIONS >/dev/null
    check_command
    echo -e "\033[1;34mDone !\033[0m"

    echo "Enabling Minikube addons..."
    minikube -p $PROFILE_NAME addons enable metrics-server >/dev/null
    check_command
    minikube -p $PROFILE_NAME addons enable ingress >/dev/null
    check_command
    minikube -p $PROFILE_NAME addons enable dashboard >/dev/null
    check_command
    echo -e "\033[1;34mDone !\033[0m"
  fi

  echo "Waiting for ingress controller to be ready..."
  kubectl wait --context=$PROFILE_NAME --namespace ingress-nginx \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=120s >/dev/null
  check_command
  echo -e "\033[1;34mDone !\033[0m"


  local tmp_url=$(minikube -p $PROFILE_NAME service -n ingress-nginx ingress-nginx-controller --url | head -n 1 | sed -E 's|^([a-zA-Z]+)://([^\/?]+).*|\1 \2|')
  check_command
  export INGRESS_CONTROLLER_PROT=$(echo $tmp_url | cut -f 1 -d ' ')
  export INGRESS_CONTROLLER_ADDR=$(echo $tmp_url | cut -f 2 -d ' ')
  envsubst < "$CONFIG_DIR/redis-react/redis-react-template.yaml" > "$CONFIG_DIR/redis-react/redis-react.yaml"
  envsubst < "$CONFIG_DIR/grafana/grafana-config-template.yaml" > "$CONFIG_DIR/grafana/grafana-config.yaml"
  envsubst < "$CONFIG_DIR/prometheus/prometheus-template.yaml" > "$CONFIG_DIR/prometheus/prometheus.yaml"

  if [[ $tmp != "2" ]]; then
    echo "Deploying services..."
    for file in "${USED_FILES[@]}"; do
      kubectl apply --context=$PROFILE_NAME -f "$CONFIG_DIR/$file" >/dev/null
      check_command
    done
    echo -e "\033[1;34mDone !\033[0m"
  fi

  echo "Waiting for pods to be ready..."
  kubectl wait --context=$PROFILE_NAME --for=condition=ready pod -l app=redis --timeout=120s >/dev/null
  check_command
  kubectl wait --context=$PROFILE_NAME --for=condition=ready pod -l app=redis-replica --timeout=120s >/dev/null
  check_command
  kubectl wait --context=$PROFILE_NAME --for=condition=ready pod -l app=node-redis --timeout=120s >/dev/null
  check_command
  kubectl wait --context=$PROFILE_NAME --for=condition=ready pod -l app=redis-react --timeout=120s >/dev/null
  check_command
  kubectl wait --context=$PROFILE_NAME -n monitoring --for=condition=ready pod -l app=grafana --timeout=120s >/dev/null
  check_command
  kubectl wait --context=$PROFILE_NAME -n monitoring --for=condition=ready pod -l app=prometheus --timeout=120s >/dev/null
  check_command
  echo -e "\033[1;34mDone !\033[0m"

  echo "Updating the cluster's state..."
  echo "1" > $STATE_FILE
  echo -e "\033[1;34mDone !\033[0m"

  echo -e "\033[1;32mCluster $PROFILE_NAME started successfully !\033[0m"
  echo "Access URLs:"
  echo "• Frontend: $INGRESS_CONTROLLER_PROT://$INGRESS_CONTROLLER_ADDR"
  echo "• API: $INGRESS_CONTROLLER_PROT://$INGRESS_CONTROLLER_ADDR/node-redis"
  echo "• Grafana : $INGRESS_CONTROLLER_PROT://$INGRESS_CONTROLLER_ADDR/grafana"
  echo "• Prometheus : $INGRESS_CONTROLLER_PROT://$INGRESS_CONTROLLER_ADDR/prometheus"
}

stop_cluster() {
  tmp=$(get_state)
  if [[ $? -ne 0 ]]; then
    exit $?
  fi

  if [[ $tmp = 0 ]]; then
    echo -e "\033[0;31mERROR: Cannot stop the cluster as it doesn't exist.\033[0m" >&2
    exit 2
  else
    if [[ $tmp = "2" ]]; then
      echo -e "\033[0;31mERROR: The cluster was already stopped.\033[0m" >&2
    exit 2
    fi
  fi

  echo "Stopping Minikube cluster..."
  minikube stop -p $PROFILE_NAME >/dev/null
  check_command
  echo -e "\033[1;34mDone !\033[0m"

  echo "Updating the cluster's state..."
  echo "2" > $STATE_FILE
  echo -e "\033[1;34mDone !\033[0m"

  echo -e "\033[1;32mCluster $PROFILE_NAME stopped successfully !\033[0m"
}

delete_cluster() {
  tmp=$(get_state)
  if [[ $? -ne 0 ]]; then
    exit $?
  fi

  if [[ $tmp = "0" ]]; then
    echo -e "\033[0;31mERROR: Cannot delete the cluster $PROFILE_NAME as it doesn't exist.\033[0m" >&2
    exit 2
  fi

  verify_CONFIG_DIR "$CONFIG_DIR"

  echo "Deleting temporary configuration files..."
  for file in "${DELETE_FILES[@]}"; do
    rm "$CONFIG_DIR/$file" >/dev/null
    check_command
  done
  echo -e "\033[1;34mDone !\033[0m"

  echo "Deleting the cluster..."
  minikube delete -p $PROFILE_NAME >/dev/null
  check_command
  echo -e "\033[1;34mDone !\033[0m"

  echo "Updating the cluster's state..."
  echo "0" > $STATE_FILE
  echo -e "\033[1;34mDone !\033[0m"

  echo -e "\033[1;32mMinikube cleaned and cluster $PROFILE_NAME deleted successfully !\033[0m"
}

dashboard() {
  tmp=$(get_state)
  if [[ $? -ne 0 ]]; then
    exit $?
  fi

  if [[ $tmp = "0" || $tmp = "2" ]]; then
    echo -e "\033[0;31mERROR: Cannot access the dashboard as the cluster $PROFILE_NAME is not running.\033[0m" >&2
    exit 2
  fi

  minikube dashboard -p $PROFILE_NAME
}

case "$1" in
  start)
    start_cluster
    ;;
  stop)
    stop_cluster
    ;;
  delete)
    delete_cluster
    ;;
  dashboard)
    dashboard
    ;;
  help)
    help_cmd
    ;;
  *)
    echo -e "\033[1;33mUsage : $0 {start|stop|delete|dashboard|help} [CONFIG_DIR]\033[0m"
    echo "Refer to \"$0 help\" for further details."
    exit 1
    ;;
esac
