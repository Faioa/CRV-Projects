#!/bin/sh

LOG_FILE="minikube_tunnel.log"

minikube start

minikube addons enable metrics-server
minikube addons enable ingress
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

kubectl apply -f redis.yaml
kubectl apply -f redis-replica.yaml
kubectl apply -f node-redis.yaml
export SERVER_BASE_URL=$(minikube service -n ingress-nginx ingress-nginx-controller --url | head -n 1)
envsubst < redis-react-template.yaml > redis-react.yaml
kubectl apply -f redis-react.yaml
kubectl apply -f ingress.yaml
echo "Server Ready at :"
echo $SERVER_BASE_URL/dashboard
