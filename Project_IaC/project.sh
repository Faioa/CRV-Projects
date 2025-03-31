#!/bin/sh

MINIKUBE_OPTIONS="--driver=docker --memory=4096 --cpus=2"
DEFAULT_DIR="$(dirname $0)/configs"
REQUIRED_FILES=("redis.yaml" "redis-replica.yaml" "node-redis.yaml" "redis-react-template.yaml" "ingress.yaml" "grafana-template.yaml" "prometheus-template.yaml")
USED_FILES=("redis.yaml" "redis-replica.yaml" "node-redis.yaml" "redis-react.yaml" "ingress.yaml" "grafana.yaml" "prometheus.yaml")

help_cmd() {
  echo -e "\033[1;34mUsage : $0 {start|stop|dashboard|help} [config_dir]\033[0m"
  echo "       start - Create and start the cluster"
  echo "        stop - Stop and delete all resources"
  echo "   dashboard - Starts Minikube's dashboard, display the URL and opens it in your browser"
  echo "        help - Display details on the usage of this script"
  echo "  config_dir - Directory containing all the services' resources files (default = \"$DEFAULT_DIR\")"
  exit 0
}

check_command() {
  if [ $? -ne 0 ]; then
    echo -e "\033[0;31mAn error occured : stopping the script...\033[0m"
    exit $?
  fi
}

verify_config_dir() {
  local config_dir=$1

  if [ ! -d "$config_dir" ]; then
    echo -e "\033[0;31mError: Config directory '$config_dir' not found\033[0m" >&2
    exit 1
  fi

  for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$config_dir/$file" ]; then
      echo -e "\033[0;31mError: Required file '$config_dir/$file' not found\033[0m" >&2
      exit 1
    fi
  done

  echo -e "\033[1;34mUsing configuration from: $config_dir\033[0m"
}

start_cluster() {
  verify_config_dir "$config_dir"

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
  local TMP=$(minikube service -n ingress-nginx ingress-nginx-controller --url | head -n 1 | sed -E 's|^([a-zA-Z]+)://([^\/?]+).*|\1 \2|')
  check_command
  export INGRESS_CONTROLLER_PROT=$(echo $TMP | cut -f 1 -d ' ')
  export INGRESS_CONTROLLER_ADDR=$(echo $TMP | cut -f 2 -d ' ')
  envsubst < "$config_dir/redis-react-template.yaml" > "$config_dir/redis-react.yaml"
  envsubst < "$config_dir/grafana-template.yaml" > "$config_dir/grafana.yaml"
  envsubst < "$config_dir/prometheus-template.yaml" > "$config_dir/prometheus.yaml"

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

  echo -e "\033[1;32mCluster started successfully !\033[0m"
  echo "Access URLs:"
  echo "• Frontend: $INGRESS_CONTROLLER_PROT://$INGRESS_CONTROLLER_ADDR"
  echo "• API: $INGRESS_CONTROLLER_PROT://$INGRESS_CONTROLLER_ADDR/node-redis"
  echo "• Grafana : $INGRESS_CONTROLLER_PROT://$INGRESS_CONTROLLER_ADDR/grafana"
  echo "• Prometheus : $INGRESS_CONTROLLER_PROT://$INGRESS_CONTROLLER_ADDR/prometheus"
}

stop_cluster() {
  verify_config_dir "$config_dir"

  echo "Deleting Kubernetes resources..."
  for file in "${USED_FILES[@]}"; do
    if [ "$file" != "$config_dir/redis-react-template.yaml" ]; then
      kubectl delete -f "$config_dir/$file" >/dev/null
      check_command
    fi
  done
  kubectl delete namespace monitoring >/dev/null
  check_command
  rm "$config_dir/redis-react.yaml" >/dev/null
  check_command
  rm "$config_dir/grafana.yaml" >/dev/null
  check_command
  rm "$config_dir/prometheus.yaml" >/dev/null
  check_command
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

  echo -e "\033[1;32mCluster stopped and cleaned successfully !\033[0m"
}

dashboard() {
  minikube dashboard
}

command=$1
config_dir=$2

if [ -z "$config_dir" ]; then
  config_dir=$DEFAULT_DIR
fi

case "$1" in
  start)
    start_cluster
    ;;
  stop)
    stop_cluster
    ;;
  dashboard)
    dashboard
    ;;
  help)
    help_cmd
    ;;
  *)
    echo -e "\033[1;33mUsage : $0 {start|stop|dashboard|help} [config_dir]\033[0m"
    echo "Refer to \"$0 help\" for further details."
    exit 1
    ;;
esac
