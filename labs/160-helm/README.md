# Helm

## Concepts

* **Helm** is a package manager for kubernetes
* A **chart** is a collection of resources (a package)
* A **repository** is a database of charts
* A **release** is a deployed copy of a chart running in a cluster
* `values.yaml` can be used to customize the deployment of a *release*

## Deploy a complete stack

* Download the [latest binary](https://github.com/helm/helm/releases) (version 3+)


* Update the repositories

```
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
```

* Deploy *wordpress* because LOL

```bash
helm search repo wordpress
helm install wp-k8s-$USER bitnami/wordpress --set serviceType=LoadBalancer 
```

* Check the chart is actually deployed

```bash
helm list
``` 

* Take a look at the created pods

```
kubectl get deployments -l app.kubernetes.io/instance=wp-k8s-$USER
kubectl get pods -l release=wp-k8s-$USER
```

* Scale up the app servers

```
kubectl scale --replicas 2 deployments wp-k8-$USER-wordpress
```

* Read the admin password secret

```bash
PASS=$(kubectl get secret --namespace demo-$USER wp-k8s-$USER-wordpress -o jsonpath="{.data.wordpress-password}" | base64 --decode)
echo The user is \"user\" and the password is \"$PASS\"
```

* Get the public url and start the admin console using `user` as username and the retreived password for authentication

```bash
export SERVICE_IP=$(kubectl get svc --namespace demo-$USER wp-k8s-$USER-wordpress --template "{{ range (index .status.loadBalancer.ingress 0) }}{{.}}{{ end }}")4
echo Go to http://$SERVICE_IP/admin
```

* Play a bit with the admin console and the deployed blog
* Cleanup everything

```
helm delete wp-k8s-$USER
```
