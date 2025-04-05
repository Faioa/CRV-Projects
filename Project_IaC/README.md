# README

Version :
- Kubernetes :
    - Client Version: v1.32.3
    - Kustomize Version: v5.5.0
- Minikube : v1.35.0
- envsubst : 0.22.5
Make sure that all the commands are available on the **$PATH**.\
\
**Warning**\
If the start command fails because of a timeout during the starting phase of the pods, it might be because your Internet connexion is not good enough and the pods lost too much time pulling the images. You can check the health of the pods with the following command :


```
$ kubectl --context=crv-cluster-iac get pods -A 
```
If everything seems fine, you can run the following command to force the state of the cluster to *Running* (or you can change it manually...) :
```
$ ./project.sh update-state
```
The installation might take a few minutes, the script will keep you informed of the major milestones of this process.\
If you break the consistency of the cluster, run the following command to reset it forcefully :
```
$ ./project.sh reset
```
Thank you.
