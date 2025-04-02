# Report
The script uses the default minikube profile, backup your configurations before runnning it. the commande *envsubst* must be available on the **$PATH**.\
The database might not be available immediately. If the default key is not rendered in the frontend, retry after a few seconds.

#TODO :
- **better README**
- **PDF report**
- **Persistent storage** yes BUT NOT on new clusters (kubectl delete -f ... erase everything)
- Cleaner code organization
- **Modifying script to just stop and not delete pods AND ensure data persistence across clusters ?**
- Dashboards grafana predefined + source predefined ?
- Prometheus exporters on redis
- state of cluster in file
