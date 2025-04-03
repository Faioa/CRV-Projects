#!/bin/sh

MINIKUBE_OPTIONS="--memory=4096 --cpus=4 --disable-driver-mounts"
DEFAULT_DIR="$(dirname $0)"
REQUIRED_FILES=("grafana/grafana.yaml"\
                "grafana/grafana-config-template.yaml"\
                "grafana/grafana-pvc.yaml"\
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
USED_FILES=("grafana/grafana.yaml"\
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
            "ingress.yaml"\
            "grafana/grafana-pvc.yaml"\
            "prometheus/prometheus-pvc.yaml"\
            "redis/redis-pvc.yaml")
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
    exit $?
  fi
}

verify_config_dir() {
  local config_dir=$1

  if [[ ! -d $config_dir ]]; then
    echo -e "\033[0;31mERROR: Config directory \"$config_dir\" not found\033[0m" >&2
    exit 1
  fi

  for file in "${REQUIRED_FILES[@]}"; do
    if [[ ! -f $config_dir/$file ]]; then
      echo -e "\033[0;31mERROR: Required file \"$config_dir/$file\" not found\033[0m" >&2
      exit 1
    fi
  done

  echo -e "\033[1;34mUsing configuration from: \"$config_dir\"\033[0m"
}

get_state() {
  if [[ ! -f $state_file ]]; then
    echo -e "\033[0;31mERROR: File describing the state of the cluster was not found. Make sure that the cluster was started at least one time and that the file is correctly located at \"${state_file}\".\033[0m" >&2
    exit 2
  fi

  cat $state_file
}

start_cluster() {
  if [[ ! -f $state_file ]]; then
    echo "0" > $state_file
    verify_config_dir "$config_dir"
  else
    tmp=$(get_state)
    if [[ $tmp = "1" ]]; then
      echo -e "\033[0;31mERROR: A previous running instance of the cluster was found. Please delete it before starting another one.\033[0m" >&2
      exit 2
    else
      if [[ $tmp = "2" ]]; then
        echo "A previous stopped instance of the cluster was found : Restarting previous instance..."
        minikube start >/dev/null
        check_command
        echo -e "\033[1;34mDone !\033[0m"

        local tmp_url=$(minikube service -n ingress-nginx ingress-nginx-controller --url | head -n 1 | sed -E 's|^([a-zA-Z]+)://([^\/?]+).*|\1 \2|')
        check_command
        INGRESS_CONTROLLER_PROT=$(echo $tmp_url | cut -f 1 -d ' ')
        INGRESS_CONTROLLER_ADDR=$(echo $tmp_url | cut -f 2 -d ' ')

        echo "Waiting for resources to be ready..."
        kubectl wait --for=condition=ready pod -l app=redis-react --timeout=120s >/dev/null
        check_command
        kubectl wait --for=condition=ready pod -l app=redis-replica --timeout=120s >/dev/null
        check_command
        kubectl wait --for=condition=ready pod -l app=redis --timeout=120s >/dev/null
        check_command
        kubectl wait --for=condition=ready pod -l app=node-redis --timeout=120s >/dev/null
        check_command
        kubectl wait -n monitoring --for=condition=ready pod -l app=grafana --timeout=120s >/dev/null
        check_command
        kubectl wait --namespace ingress-nginx \
          --for=condition=ready pod \
          --selector=app.kubernetes.io/component=controller \
          --timeout=120s >/dev/null
        check_command
        echo -e "\033[1;34mDone !\033[0m"

        echo "Updating the cluster's state..."
        echo "1" > $state_file
        echo -e "\033[1;34mDone !\033[0m"

        echo -e "\033[1;32mCluster started successfully !\033[0m"
        echo "Access URLs:"
        echo "• Frontend: $INGRESS_CONTROLLER_PROT://$INGRESS_CONTROLLER_ADDR"
        echo "• API: $INGRESS_CONTROLLER_PROT://$INGRESS_CONTROLLER_ADDR/node-redis"
        echo "• Grafana : $INGRESS_CONTROLLER_PROT://$INGRESS_CONTROLLER_ADDR/grafana"
        echo "• Prometheus : $INGRESS_CONTROLLER_PROT://$INGRESS_CONTROLLER_ADDR/prometheus"

        exit 0
      fi
    fi
  fi

  echo "Starting Minikube cluster..."
  minikube start $MINIKUBE_OPTIONS >/dev/null
  check_command
  echo -e "\033[1;34mDone !\033[0m"

  echo "Enabling Minikube addons..."
  minikube addons enable metrics-server >/dev/null
  check_command
  minikube addons enable ingress >/dev/null
  check_command
  minikube addons enable dashboard >/dev/null
  check_command
  echo -e "\033[1;34mDone !\033[0m"

  echo "Waiting for ingress controller to be ready..."
  kubectl wait --namespace ingress-nginx \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=120s >/dev/null
  check_command
  echo -e "\033[1;34mDone !\033[0m"

  echo "Deploying services..."
  local tmp_url=$(minikube service -n ingress-nginx ingress-nginx-controller --url | head -n 1 | sed -E 's|^([a-zA-Z]+)://([^\/?]+).*|\1 \2|')
  check_command
  export INGRESS_CONTROLLER_PROT=$(echo $tmp_url | cut -f 1 -d ' ')
  export INGRESS_CONTROLLER_ADDR=$(echo $tmp_url | cut -f 2 -d ' ')
  envsubst < "$config_dir/redis-react/redis-react-template.yaml" > "$config_dir/redis-react/redis-react.yaml"
  envsubst < "$config_dir/grafana/grafana-config-template.yaml" > "$config_dir/grafana/grafana-config.yaml"
  envsubst < "$config_dir/prometheus/prometheus-template.yaml" > "$config_dir/prometheus/prometheus.yaml"

  kubectl create namespace monitoring >/dev/null
  check_command
  for file in "${USED_FILES[@]}"; do
    kubectl apply -f "$config_dir/$file" >/dev/null
    check_command
  done
  echo -e "\033[1;34mDone !\033[0m"

  echo "Waiting for pods to be ready..."
  kubectl wait --for=condition=ready pod -l app=redis-react --timeout=120s >/dev/null
  check_command
  kubectl wait --for=condition=ready pod -l app=redis-replica --timeout=120s >/dev/null
  check_command
  kubectl wait --for=condition=ready pod -l app=redis --timeout=120s >/dev/null
  check_command
  kubectl wait --for=condition=ready pod -l app=node-redis --timeout=120s >/dev/null
  check_command
  kubectl wait -n monitoring --for=condition=ready pod -l app=grafana --timeout=120s >/dev/null
  check_command
  echo -e "\033[1;34mDone !\033[0m"

  echo "Updating the cluster's state..."
  echo "1" > $state_file
  echo -e "\033[1;34mDone !\033[0m"

  echo -e "\033[1;32mCluster started successfully !\033[0m"
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

  verify_config_dir "$config_dir"

  echo "Stopping Minikube cluster..."
  minikube stop >/dev/null
  check_command
  echo -e "\033[1;34mDone !\033[0m"

  echo "Updating the cluster's state..."
  echo "2" > $state_file
  echo -e "\033[1;34mDone !\033[0m"

  echo -e "\033[1;32mCluster stopped successfully !\033[0m"
}

delete_cluster() {
  tmp=$(get_state)
  if [[ $? -ne 0 ]]; then
    exit $?
  fi

  if [[ $tmp = "0" ]]; then
    echo -e "\033[0;31mERROR: Cannot delete the cluster as it doesn't exist.\033[0m" >&2
    exit 2
  else
    if [[ $tmp = "2" ]]; then
      echo "Restarting the cluster..."
      minikube start >/dev/null
      check_command
      echo -e "\033[1;34mDone !\033[0m"
    fi
  fi

  verify_config_dir "$config_dir"

  echo "Cleaning Kubernetes resources..."
  for file in "${USED_FILES[@]}"; do
      kubectl delete -f "$config_dir/$file" >/dev/null
      check_command
  done
  echo -e "\033[1;34mDone !\033[0m"

  echo "Deleting namespaces..."
  kubectl delete namespace monitoring >/dev/null
  echo -e "\033[1;34mDone !\033[0m"

  echo "Removing temporary configuration files..."
  check_command
  for file in "${DELETE_FILES[@]}"; do
    rm "$config_dir/$file" >/dev/null
    check_command
  done
  echo -e "\033[1;34mDone !\033[0m"

  echo "Disabling Minikube addons..."
  minikube addons disable metrics-server >/dev/null
  check_command
  minikube addons disable ingress >/dev/null
  check_command
  minikube addons disable dashboard >/dev/null
  check_command
  echo -e "\033[1;34mDone !\033[0m"

  echo "Stopping Minikube cluster..."
  minikube stop >/dev/null
  check_command
  echo -e "\033[1;34mDone !\033[0m"

  echo "Updating the cluster's state..."
  echo "0" > $state_file
  echo -e "\033[1;34mDone !\033[0m"

  echo -e "\033[1;32mMinikube cleaned and project deleted successfully !\033[0m"
}

dashboard() {
  tmp=$(get_state)
  if [[ $? -ne 0 ]]; then
    exit $?
  fi

  if [[ $tmp = "0" || $tmp = "2" ]]; then
    echo -e "\033[0;31mERROR: Cannot access the dashboard as the cluster is not running.\033[0m" >&2
    exit 2
  fi

  minikube dashboard
}

command=$1

if [[ -z $2 ]]; then
  config_dir="$DEFAULT_DIR/configs"
  state_file="$DEFAULT_DIR/.state"
else
  config_dir="$2/configs"
  state_file="$2/.state"
fi

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
    echo -e "\033[1;33mUsage : $0 {start|stop|delete|dashboard|help} [config_dir]\033[0m"
    echo "Refer to \"$0 help\" for further details."
    exit 1
    ;;
esac
