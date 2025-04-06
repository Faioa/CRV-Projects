# CRV Project IaC - README
Matthieu DARTOIS - 21113417\
Vinh-Trung THIEU - 21415515

## Introduction
This project was made for the CRV class at Sorbonne Université. We are using *Minikube* to make a Kubernetes cluster. We are implementing the required infrastructure :
- A React frontend
- A Redis database
- Multiple Redis replicas
- A Nodejs server that communicates with the database
- A prometheus instance that scraps multiple pods on the cluster
- A grafana instance that can display Prometheus' metrics on custom graphs

Moreover, we chose to use an Ingress Controller instead of making all of our services as LoadBalancers or NodePorts to have a project closer to a real production infrastructure : one entry point as a LoadBalancer that distributes to the right services.

## Versions
If the project doesn't work immediatly on your machine, ensure that you have a relatively good Internet connexion and that the softwares version are not inferior to the followings :
- Kubernetes :
    - Client Version: v1.32.3
    - Kustomize Version: v5.5.0
- Minikube : v1.35.0
- envsubst : 0.22.5
Make sure that all the commands are available on the **$PATH**.\

## How to use the project
### project.sh
All the needed interactions are made through the custom bash script *project.sh*, located at the root folder of the project. If you move the script elsewhere, you will need to reference the root directory in the second argument of the program. For instance :
```
$ ./project.sh start /path/to/root/folder
```
**In the next parts, we will assume that we execute the script from the root folder of the project.**

### Starting the cluster
Nothing easier than launching the following command :
```
$ ./project.sh start
```
It might take a long time depending on you Internet connexion. In our case, it took almost 2 minutes and 30 seconds. Don't worry tho, the script will update you about the major milestones. At the end, you will get a list of the different endpoints you can contact to use the services. You can copy Prometheus' one to add a source to Grafana.\
Also, you can use this command to restart the cluster if it was previously stopped. It will take less time to start and you will still get the list of endpoints at the end.

### Debugging any timeout issues
If there is a timeout issue during the starting phase of the script, your Internet connexion was probably the one responsible. You can use the following command to try to resolve the situation :
```
$ ./project.sh update_state
```
If the situation is not resolved through the use of this command, try to use the dashboard to find the issues :
```
$ ./project.sh dashboard
```
**WARNING : the cluster as multiple namespaces, be sure to check all of them.**

### Stopping the cluster
You can stop the cluster by using the following command :
```
$ ./project.sh stop
```
This is usefull if you want to keep the data of Redis, Grafana or Prometheus as they use Peristent Volumes.

### Deleting the cluster
You have two options to do this.\
The first one is a command that verify the cluster's state before deleting anything. 
```
$ ./project.sh delete
```
Or, the second one doesn't do the check and deletes everything that might have been generated and resets the cluster state.
```
$ ./project.sh force_delete
```

### Restoring the cluster's state consistency
If the cluster was stopped (the machine was shut down), or deleted (Minikube commands) in an unexpected way, the cluster's state might not be consistent with the content of the file *.state* at the root folder of the project. Use the following command to restore the correct state :
```
$ ./project.sh update_state
```

### Dashboard
You can get a dashboard that describes the cluster with the following command:
```
$ ./project.sh dashboard
```

### Getting help
The script has a *help* command that can resume everything in this file in your Shell. Just run the following command :
```
$ ./project.sh help
```

### Debugging
If the use of *update_state* doesn't help, you can use *kubectl* to get an idea of which component caused an issue :
```
$ kubectl --context=crv-cluster-iac get pods -A 
```

---

**Thank you**
