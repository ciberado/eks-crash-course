# Limits and monitoring

## Resource limits explanation

* Both memory and cpu usage can be limited
* From v1.8 ephemeral storage performance is also considered a compute resource
* Custom compute resources can be created using [extended resources](https://kubernetes.io/docs/concepts/configuration/manage-compute-resources-container/#cluster-level-extended-resources)
* The restrictions are per container: the pod limits are the sum of all its containers
* CPU usage is measured in *milicores*: 1000m is equivalent to a whole cpu
* In most situation it is better to run two replicas with one core than one pod with two cores
* A container will not be able to use more cycles per second that those provided by its quota: if it happens kubernetes will throttle it
* A container trying to allocate more ram that specified in the quota might be restarted
* If there are no nodes with enough resources the pod will not be scheduled
* The **requests** is the minimum ammount of resources the container needs
* The **limit** is the maximum amount of the resource provided by the node and can be throttled if needed


## Experimenting with resource limits


* Learn how memory resources are constrained reading the next manifest:

```yaml
cat << EOF > stress.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: stress-demo
spec:
  selector:
    matchLabels:
      app: stress-demo
  replicas: 1
  template:
    metadata:
      labels:
        app: stress-demo
        version: 0.0.1
    spec:
      containers:
      - name: stress-demo-container
        image: containerstack/alpine-stress
        resources:
          limits:
            memory: "200Mi"
          requests:
            memory: "100Mi"
        command: ['sh', '-c', 'echo I can be stressed! && sleep 3600']
EOF
```

* Deploy de demo

```
kubectl apply -f stress.yaml
```

* Get the name of the pod

```bash
POD=$(kubectl get pods -ojsonpath="{.items[0].metadata.name}" -l app=stress-demo)
echo The pod name is $POD.
```

* Connect to the container and allocate 100Mi bytes for 60 seconds and 180 for another minute

```bash
# will fail: stress tool understands k8s hard limit
kubectl exec -it $POD -- stress --vm 1 --vm-bytes 200M --vm-hang 60 -t 60 -v
# will succeed
kubectl exec -it $POD -- stress --vm 1 --vm-bytes 100M --vm-hang 60 -t 60 -v
```

## Namespace quotas

* A **ResourceQuota** provides a way to limit the aggregated resources available to a namespace

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: development-resources
spec:
  hard:
    requests.cpu: "2000m"
    requests.memory: 10Gi
    limits.cpu: "12000m"
    limits.memory: 20Gi
```

* A **LimitRange** sets the legal limits for every container deployed in a namespace

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: development-limits
spec:
  limits:
  - max:
      memory: 2Gi
    min:
      memory: 100Mi
    type: Container
```

## Common tasks

* Resources by node

```
kubectl get nodes --no-headers | awk '{print $1}' | xargs -I {} sh -c 'echo {}; kubectl describe node {} | grep Allocated -A 5 | grep -ve Event -ve Allocated -ve percent -ve -- ; echo'
```

