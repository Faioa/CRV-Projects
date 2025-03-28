- Use of Ingress instead of ConfigMap -> IP du node du service dans l'ingress ($ minikube addons enable ingress)
 
 ```
 $ kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s
```

- Prometheus on every service (redis (prometheus exporter) + node-redis)
- Graphana
