# Horitzontal autoscaler EKS


* Ensure [helm](https://helm.sh/) is installed

```bash
wget https://get.helm.sh/helm-v3.3.4-linux-amd64.tar.gz
tar -zxvf helm-v3.3.4-linux-amd64.tar.gz
sudo cp linux-amd64/helm /usr/local/bin/

helm repo add stable https://charts.helm.sh/stable
```

* Install [metrics helm chart] to provide data to the autoscaler pod:

```bash
kubectl create namespace metrics

helm install metrics-server \
    stable/metrics-server \
    --version 2.11.1 \
    --namespace metrics
```

* Wait until its status is `True`:

```bash
kubectl get apiservice v1beta1.metrics.k8s.io -o yaml | yq - r 'status'
```

* Deploy a demo application (it is an standard one) and fix its `cpu` limits to `200m`:

```bash
kubectl create deployment php-apache --image=us.gcr.io/k8s-artifacts-prod/hpa-example
kubectl set resources deploy php-apache --requests=cpu=200m
```

* Expose the application

```bash
kubectl expose deployment php-apache --port 80
```

* Set the autoscale target for the `cpu` metric

```bash
kubectl autoscale deployment php-apache \
    --cpu-percent=50 \
    --min=1 \
    --max=10 
```

* Check if the *horitzontal pod autoscaling* resource exist

```bash
kubectl get hpa
```

* Deploy the `load-generator` in a new `tmux` pane:

```bash
tmux split-window "\
  kubectl run load-generator \
    --image=busybox \
    --restart=Never \
    --rm -it \
    -- /bin/sh -c 'while true; do wget -q -O - http://php-apache; done' \
"
```

* Use another pane to watch for the value of the metrics:

```bash
tmux split-window "\
  kubectl get hpa -w \
"
```

* Lastly, the current pane to see how many pods do we have:

```bash
kubectl get pods -w
```

* Feel free to stop the `load-generator` pod to see how scaling down is also a natural process

## Visual monitoring

* Install `cAdvisor` in the cluster

```bash
git clone https://github.com/google/cadvisor
cd /cadvisor/deploy/kubernetes/bas
kubectl kustomize . | kubectl apply -f -
```

* Install `kubebox`

```bash
curl -Lo kubebox https://github.com/astefanutti/kubebox/releases/download/v0.8.0/kubebox-linux \
chmod +x kubebox
```

* Execute `kubebox` 

```bash
./kubebox
```