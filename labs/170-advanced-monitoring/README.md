# Advanced monitoring

## Prometheus (with kops)

* Most popular solution to gather metrics from kubernetes
* Started by Soundcloud
* Not designed for log aggregation or tracing
* Works well with grafana for represent information
* Pull based: it is Prometheus who pulls information from the monitored assets each 15 seconds
* Targets usually publishes `/metrics` https endpoints
* A typical record looks like this: `http_request_total{code="200",path="/status"} 2532`
* Provides a query language to search metrics named *Promql*
* **Alert definitions** allows to react if condition is met
* **Alert manager** filters duplicates on those alarms and routes them to the appropiated action
* Prometheus uses service discovery to find metrics of the deployed applications


## Deployment

* Create a *kops* cluster. Notice the **vm sizes** and the **activated RBAC**

```bash
openssl genrsa -out kops.pem 2048 
ssh-keygen -y -f kops.pem > kops.pub

export CLUSTER_NAME=<your cluster name>
export KOPS_STATE_STORE=s3://<your s3 bucket name>
export DOMAIN=<your domain>
export EDITOR=vim

kops create cluster \
  --state $KOPS_STATE_STORE \
  --name $CLUSTER_NAME.$DOMAIN \
  --master-size t2.medium \
  --master-count 3 \
  --master-zones eu-west-1a,eu-west-1b,eu-west-1c \
  --node-count 3 \
  --node-size t2.medium \
  --zones eu-west-1a,eu-west-1b,eu-west-1c \
  --networking calico  \
  --cloud-labels "Owner=kops,Project=$CLUSTER_NAME" \
  --ssh-public-key kops.pub \
  --authorization RBAC \
  --yes
```

* Wait until the cluster is online

```bash
kops cluster validate
```

* Install *helm* server components

```
helm init
```

* Configure *helm* access to kubernetes resources

```bash
kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding \
    tiller-cluster-rule \
    --clusterrole=cluster-admin \
    --serviceaccount=kube-system:tiller
kubectl patch deploy \
   --namespace kube-system \
   tiller-deploy \
   -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}' 
```

* Wait until *helm tiller* is ready

```bash
helm list
```

* Add the *coreos* repo in order to be able to use [prometheus-operator](https://github.com/coreos/prometheus-operator) to install *prometheus*

```bash
helm repo add coreos https://s3-eu-west-1.amazonaws.com/coreos-charts/stable/
helm repo update
```

* Install *operator* and wait until its pod is deployed

```bash
helm install coreos/prometheus-operator --name prometheus-operator --namespace monitoring
kubectl get pods  -n monitoring
helm install coreos/kube-prometheus --name kube-prometheus --set global.rbacEnable=true --namespace monitoring
```


* Expose using port-forwarding the *prometheus* port

```
kubectl port-forward -n monitoring prometheus-kube-prometheus-0 9090
```

* Open the browser to check the status of the different services

```
start http://localhost:9090/targets
```

## Grafana

* **Grafana** is a visualization tool
* It's very flexible and admits different datasources, including *prometheus*
* It's already installed with the previous instructions

## Connecting to grafana

* Deploy additional dashboards

```
kubectl apply -f https://raw.githubusercontent.com/giantswarm/kubernetes-prometheus/master/manifests/grafana/import-dashboards/job.yaml
```

* Forward the port of the grafana pod

```
kubectl port-forward $(kubectl get  pods --selector=app=kube-prometheus-grafana -n  monitoring --output=jsonpath="{.items..metadata.name}") -n monitoring  3000
```

* Open the dashboard in your browser

```
start http://localhost:3000
```

* Navigate to the `kubernetes-control-plane-status` dashboard. Explore around it

## Alert manager

* **Alert manager** is the component that routes the alerts to their destinations
* Check it with

```bash
kubectl port-forward -n monitoring alertmanager-kube-prometheus-0 9093
```
* Open the dashboard

```
start http://localhost:9093
```

* Cleanup the cluster

```

kubectl delete namespace monitoring
```