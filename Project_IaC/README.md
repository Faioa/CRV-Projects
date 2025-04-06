# CRV Project IaC - README

- Matthieu DARTOIS - 21113417
- Vinh-Trung THIEU - 21415515

## Introduction

This project was made for the CRV class at Sorbonne Université. We are using _Minikube_ to make a Kubernetes cluster. We are implementing the required infrastructure :

- A React frontend
- A Redis database
- Multiple Redis replicas
- A Nodejs server that communicates with the database
- A prometheus instance that scraps multiple pods on the cluster
- A grafana instance that can display Prometheus' metrics on custom graphs

Moreover, we chose to use an Ingress Controller instead of making all of our services as LoadBalancers or NodePorts to have a project closer to a real production infrastructure : one entry point as a LoadBalancer that distributes to the right services.

## Requirements

The underlying Minikube cluster requires 6 Gigabytes of memory and 4 hearts of CPU.

## Versions

If the project doesn't work immediately on your machine, ensure that you have a relatively good Internet connection and that the softwares version are not inferior to the followings :

- **Kubernetes**:
  - Client: `v1.32.3`
  - Kustomize: `v5.5.0`
- **Minikube**: `v1.35.0`
- **envsubst**: `0.22.5`

Also, ensure all commands are available in your **$PATH**.

## How to use the project

### project.sh

All the needed interactions are made through the custom bash script `project.sh`, located at the root folder of the project. If you move the script elsewhere, you will need to reference the root directory in the second argument of the program. For instance :

```bash
$ ./project.sh start /path/to/root/folder
```

**In the next parts, we will assume that we execute the script from the root folder of the project.**

### Starting the cluster

Nothing easier than launching the following command :

```bash
$ ./project.sh start
```

It might take a long time depending on you Internet connection. In our case, it took almost 2 minutes and 30 seconds. Don't worry tho, the script will update you about the major milestones. At the end, you will get a list of the different endpoints you can contact to use the services. You can copy Prometheus' one to add a source to Grafana.\
Also, you can use this command to restart the cluster if it was previously stopped. It will take less time to start and you will still get the list of endpoints at the end.

### Debugging any timeout issues

If there is a timeout issue during the starting phase of the script, your Internet connection was probably the one responsible. You can use the following command to try to resolve the situation :

```bash
$ ./project.sh update_state
```

If the situation is not resolved through the use of this command, try to use the dashboard to find the issues :

```bash
$ ./project.sh dashboard
```

**WARNING : the cluster as multiple namespaces, be sure to check all of them.**

### Stopping the cluster

You can stop the cluster by using the following command :

```bash
$ ./project.sh stop
```

This is useful if you want to keep the data of Redis, Grafana or Prometheus as they use Peristent Volumes.

### Deleting the cluster

You have two options to do this.\
The first one is a command that verify the cluster's state before deleting anything.

```bash
$ ./project.sh delete
```

Or, the second one doesn't do the check and deletes everything that might have been generated and resets the cluster state.

```bash
$ ./project.sh force_delete
```

### Restoring the cluster's state consistency

If the cluster was stopped (the machine was shut down), or deleted (Minikube commands) in an unexpected way, the cluster's state might not be consistent with the content of the file _.state_ at the root folder of the project. Use the following command to restore the correct state :

```bash
$ ./project.sh update_state
```

### Dashboard

You can get a dashboard that describes the cluster with the following command:

```bash
$ ./project.sh dashboard
```

### Getting help

The script has a _help_ command that can resume everything in this file in your Shell. Just run the following command :

```bash
$ ./project.sh help
```

### Debugging

If the use of _update_state_ doesn't help, you can use _kubectl_ to get an idea of which component caused an issue :

```bash
$ kubectl --context=crv-cluster-iac get pods -A
```

---

**Thank you**
