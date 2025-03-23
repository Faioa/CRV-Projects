## 1 - Changing the react configuration file
There is a need to change it because the project uses a hardcoded URL and we would prefer to override it with environment variables when needed.
```
export const URL = process.env.URL || "http://node-redis:3000"
```

## 2 - Launching the node-redis Service as a LoadBalancer
In both cases, we'll need to get the IP and port of the service after it's deployed. We configure a ConfigMap with the URL of the service and after its deployment we can finally deploy the frontend. Since we are using *minikube*, we need to start a tunnel to make the load balancers work.
```
$ minikube start
$ minikube tunnel >/dev/null 2>/dev/null &
$ kubectl apply -f redis-deployment.yaml 
$ kubectl apply -f node-redis-deployment.yaml 
$ echo "$(kubectl get service node-redis -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):$(kubectl get service node-redis -o jsonpath='{.spec.ports[0].port}')"
  10.107.93.52:80
```

The service uses the address **10.107.93.52** and listens on port **80**.\
We can now modify the ConfigMap and apply it.
```
$ kubectl apply -f redis-react-config.yaml
```

Finally, we can finish configuring the cluster with our front end (as a LoadBalancer to provide external access).
```
$ kubectl apply -f redis-react-deployment.yaml
$ echo "$(kubectl get service redis-react -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):$(kubectl get service redis-react -o jsonpath='{.spec.ports[0].port}')"
  10.98.46.23:80
```

We could have used NodePorts instead of LoadBalancers, but all the services would have to be on the same node, and we would have had to find out the IP of the node and the ports of each NodePort to configure the ConfigMap and access the frontend.

# 3 - DockerCompose
If we wanted to launch the project in a local environment, we could use the *docker-compose* solution. We have also added a configuration file for this option.\ We can start the project with the following command.
```
$ docker compose up
```
Or this, if docker-compose is installed as a standalone.
```
$ docker-compose up 
```
