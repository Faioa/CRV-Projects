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

MINIKUBE_OPTIONS="--driver=docker --memory=4096 --cpus=4 --disable-driver-mounts"
REQUIRED_FILES=("monitoring-namespace.yaml"\
                "grafana/grafana.yaml"\
                "grafana/grafana-config-template.yaml"\
                "node-redis/node-redis.yaml"\
                "node-redis/node-redis-autoscaler.yaml"\
                "prometheus/prometheus-cluster-role.yaml"\
                "prometheus/prometheus-config.yaml"\
                "prometheus/prometheus-template.yaml"\
                "redis/redis.yaml"\
                "redis-react/redis-react-template.yaml"\
                "redis-replica/redis-replica.yaml"\
                "redis-replica/redis-replica-autoscaler.yaml"\
                "ingress.yaml"\
                "ingress-controller-autoscaler.yaml"\
                "node-exporter/node-exporter-cluster-role.yaml"\
                "node-exporter/node-exporter.yaml")
USED_FILES=("monitoring-namespace.yaml"\
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
            "ingress.yaml"\
            "ingress-controller-autoscaler.yaml"\
            "node-exporter/node-exporter-cluster-role.yaml"\
            "node-exporter/node-exporter.yaml")
DELETE_FILES=("grafana/grafana-config.yaml"\
              "prometheus/prometheus.yaml"\
              "redis-react/redis-react.yaml")

help_cmd() {
  echo -e "\033[1;34mUsage : $0 {start|stop|delete|update_state|force_delete|dashboard|help} [project_dir]\033[0m"
  echo "       start - Starts the cluster and create the resources if they don't exist."
  echo "               Also restarts the cluster if it was previously stopped."
  echo "        stop - Stops the cluster without cleaning the resources."
  echo "      delete - Deletes the cluster and all the generated resources files."
  echo "update_state - Debugging command that tries to update the cluster's state if it doesn't seem consistent for the user."
  echo "force_delete - Debugging command that forces the deletion of the cluster."
  echo "               It disregards the current state of the cluster and deletes any generated files."
  echo "   dashboard - Starts Minikube's dashboard associated with the cluster, display the URL and opens it in your browser."
  echo "        help - Displays details on the usage of this script"
  echo " project_dir - Directory containing the necessary files and directories for the cluster to be launched successfully."
  echo "               The default directory is \"$DEFAULT_DIR\" and it should have the following architecture :"
  echo "                 _"
  echo "                 |- configs/ : The directory containing all the required configuration files for Kubernetes"
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
    minikube -p $PROFILE_NAME addons enable dashboard >/dev/null
    check_command
    minikube -p $PROFILE_NAME addons enable ingress >/dev/null
    check_command
    echo -e "\033[1;34mDone !\033[0m"
  fi

  echo "Waiting for ingress controller to be ready..."
  kubectl wait --context=$PROFILE_NAME -n ingress-nginx \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=120s >/dev/null
  check_command
  echo -e "\033[1;34mDone !\033[0m"

  if [[ $tmp != "2" ]]; then
    echo "Adding annotations for Prometheus to scrap the ingress controller pods..."
    kubectl patch --context=$PROFILE_NAME deployment ingress-nginx-controller -n ingress-nginx --patch '
      spec:
        template:
          metadata:
            annotations:
              prometheus.io/scrape: "true"
              prometheus.io/port: "10254"
      ' >/dev/null
    check_command
    kubectl rollout --context=$PROFILE_NAME restart deployment ingress-nginx-controller -n ingress-nginx >/dev/null
    check_command
    kubectl wait --context=$PROFILE_NAME -n ingress-nginx \
      --for=condition=ready pod \
      --selector=app.kubernetes.io/component=controller \
      --timeout=120s >/dev/null
    check_command
    echo -e "\033[1;34mDone !\033[0m"
  fi

  tmp_url=$(minikube -p $PROFILE_NAME service -n ingress-nginx ingress-nginx-controller --url | head -n 1 | sed -E 's|^([a-zA-Z]+)://([^\/?]+).*|\1 \2|')
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
  exit 0
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
  exit 0
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
    rm -f "$CONFIG_DIR/$file" >/dev/null
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
  exit 0
}

update_state() {
  curr_state=$(get_state)
  tmp=$(minikube profile list | grep "$PROFILE_NAME" | tr -d " ")
  check_command

  if [[ -z $tmp ]]; then
    if [[ $curr_state != "0" ]]; then
      echo -e "\033[1;35mThe cluster $PROFILE_NAME doesn't not exist.\033[0m Updating the cluster's state..."
      echo "0" > $STATE_FILE
      echo -e "\033[1;32mCluster state updated successfully !\033[0m"
    else
      echo "The cluster state was already correct : the cluster $PROFILE_NAME doesn't exist."
    fi
  else
    state=$(echo $tmp | cut -d "|" -f 8)
    if [[ $state = "Stopped" ]]; then
      if [[ $curr_state != "2" ]]; then
        echo -e "\033[1;35mThe cluster $PROFILE_NAME is stopped.\033[0m Updating the cluster's state..."
        echo "2" > $STATE_FILE
        echo -e "\033[1;32mCluster state updated successfully !\033[0m"
      else
        echo "The cluster state was already correct : the cluster $PROFILE_NAME is stopped."
      fi
    else
      if [[ $state = "Starting" ]]; then
        echo "The cluster $PROFILE_NAME is still starting, please wait for a bit before reusing this command."
        echo "Alternatively, you can use the command \"$0 force-delete\" to force the deletion of the cluster."
      else
        if [[ $state = "OK" ]]; then
          if [[ $curr_state != "1" ]]; then
            echo -e "\033[1;35mThe cluster $PROFILE_NAME is running.\033[0m Updating the cluster's state..."
            echo "1" > $STATE_FILE
            echo -e "\033[1;32mCluster state updated successfully !\033[0m"
          else
            echo "The cluster state was already correct : the cluster $PROFILE_NAME is running."
          fi
          tmp=$(minikube -p $PROFILE_NAME service -n ingress-nginx ingress-nginx-controller --url | head -n 1 | sed -E 's|^([a-zA-Z]+)://([^\/?]+).*|\1 \2|')
          check_command
          INGRESS_CONTROLLER_PROT=$(echo $tmp | cut -f 1 -d ' ')
          INGRESS_CONTROLLER_ADDR=$(echo $tmp | cut -f 2 -d ' ')
          echo "Access URLs:"
          echo "• Frontend: $INGRESS_CONTROLLER_PROT://$INGRESS_CONTROLLER_ADDR"
          echo "• API: $INGRESS_CONTROLLER_PROT://$INGRESS_CONTROLLER_ADDR/node-redis"
          echo "• Grafana : $INGRESS_CONTROLLER_PROT://$INGRESS_CONTROLLER_ADDR/grafana"
          echo "• Prometheus : $INGRESS_CONTROLLER_PROT://$INGRESS_CONTROLLER_ADDR/prometheus"
        else
          echo "\033[0;31mERROR: This script cannot infer the state of the cluster. Please run further investigation with Minikube's and Kubernetes' commands.\033[0m" >&2
          echo "Alternatively, you can use the command \"$0 force-delete\" to force the deletion of the cluster." >&2
          echo "Defaulting the cluster's state to \"Inexistant\" for the time being..." >&2
          echo "0" > $STATE_FILE
          echo -e "\033[1;34mDone !\033[0m" >&2
          exit 3
        fi
      fi
    fi
  fi
  exit 0
}

force_delete() {
  verify_CONFIG_DIR "$CONFIG_DIR" >/dev/null
  echo "Deleting the cluster..."
  for file in "${DELETE_FILES[@]}"; do
    rm -f "$CONFIG_DIR/$file" >/dev/null 2>&1
  done
  minikube delete -p $PROFILE_NAME >/dev/null 2>&1
  echo -e "\033[1;34mDone !\033[0m"

  echo "Updating the cluster's state..."
  echo "0" > $STATE_FILE
  echo -e "\033[1;34mDone !\033[0m"

  echo -e "\033[1;32mMinikube cleaned and cluster $PROFILE_NAME deleted forcefully !\033[0m"
  exit 0
}

dashboard() {
  tmp=$(get_state)
  if [[ $? -ne 0 ]]; then
    exit $?
  fi

  if [[ $tmp != "1" ]]; then
    echo -e "\033[0;31mERROR: Cannot access the dashboard as the cluster $PROFILE_NAME is not running.\033[0m" >&2
    exit 2
  fi

  minikube dashboard -p $PROFILE_NAME
  exit 0
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
  update_state)
    update_state
    ;;
  force_delete)
    force_delete
    ;;
  dashboard)
    dashboard
    ;;
  help)
    help_cmd
    ;;
  *)
    echo -e "\033[1;33mUsage : $0 {start|stop|delete|update_state|force_delete|dashboard|help} [CONFIG_DIR]\033[0m"
    echo "Refer to \"$0 help\" for further details."
    exit 1
    ;;
esac
