# Contraints

## Labels

* **Key/Value** pairs
* **Used by selectors** in queries
* Also used by **services and replication controllers** to select managed pods
* Attached to objects
* Grouped by **prefixes** acting as namespaces
* If specified prefixes **must be subdomains** (micompany.com/labelname)
* Prefixes are separated by `/` from the name


## Selectors

* Two types of selectors
* **Equality-based**: `env=prod`, `env!=prod`
* **Set-based**: `env in (production, preproduction)`, `env not in (development), `env`, `!env`
* Used in templates:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: demo
spec:
  containers:
    - name: demo
      image: demo
  nodeSelector:
    disktype: ssd-enabled
```

* Used in queries

```
kubectl get pods --selector env=production,tier=cache
```

## Exploring kops nodes

* Deploy a *kops* cluster following [../40-k8sonaws/README.md](../40-k8sonaws/README.md) instructions or use an *EKS* cluster
* Install `jq` from [stedolan.github.io](https://stedolan.github.io/jq/download/)
* Show information from nodes, increasingly filtering interesting data

```
kubectl get nodes -owide
```

## Using labels on nodes

* Retrieve the name of a worker node (Kops version)

```
FRONT_END_NODE=\
$(kubectl get nodes --output name --selector kubernetes.io/role=node | head --lines 1)
echo We are going to use $FRONT_END_NODE
```

* Retrieve the name of a worker node (EKS version)

```
FRONT_END_NODE="$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')"
echo We are going to use $FRONT_END_NODE
```

* Tag it with the new label

```
kubectl label node "$FRONT_END_NODE" programar.cloud/tier=frontend
```

* Create a deployment specifying labels:

```yaml
cat << EOF > nginx-front-end.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  labels:
    programar.cloud/tier: frontend
spec:
  replicas: 5
  selector:
    matchLabels:
      programar.cloud/tier: frontend
  template:
    metadata:
      labels:
        programar.cloud/app: demo
        programar.cloud/tier: frontend
    spec:
      containers:
      - name: nginx
        image: nginx
      nodeSelector:
        programar.cloud/tier: frontend
EOF
```
* Deploy all pods!

```bash
kubectl apply -f nginx-front-end.yaml
```

* Check the affinity between pods and nodes

```bash
kubectl get pods --output wide
```

* Clean it up

```
kubectl delete deployment frontend
```

## Interpod affinity

In the next scenario we plan to deploy two replicas of a heavy web server only on nodes that contains a node-wide memcached-based cache in order to take advantage of the locality,presumibly by injecting the node name into the client environment and using `spec.containers.ports.hostPort` on the memcached

```yaml
env:
- name: NODE_NAME
  valueFrom:
    fieldRef:
      fieldPath: spec.nodeName 
```

* Check next deployment to understand how to avoid two pods in the same node (in a real scenario, proably a [DaemonSet](https://kubernetes.io/es/docs/concepts/workloads/controllers/daemonset/) would be more appropiated to distribute a number of pods relative to the number of nodes in the cluster)

```yaml
cat << EOF > node-cache.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: node-cache-deployment
spec:
  selector:
    matchLabels:
      app: node-cache
  replicas: 2
  template:
    metadata:
      labels:
        app: node-cache
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - node-cache
            topologyKey: "kubernetes.io/hostname"
      containers:
      - name: memcached-server
        image: memcached:alpine
        ports:
          - name: memcached-port
            hostPort: 8888
            containerPort: 11211
            protocol: TCP
EOF
```

* Deploy it with

```
kubectl apply -f node-cache.yaml
```

* Check the two replicas are on separated pods

```
kubectl get pods -owide --sort-by .spec.nodeName
```

* Look at the descriptor of the [heavy-web-server.yaml](heavy-web-server.yaml) to learn how to enforce the deployment of the replicas in nodes that contains a `node-cache` but avoiding placing to servers on the same node (yes, yes: the following is also a simplification)

```yaml
cat << EOF > heavy-web-server.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: heavy-web-server-deployment
spec:
  selector:
    matchLabels:
      app: heavy-web-server
  replicas: 2
  template:
    metadata:
      labels:
        app: heavy-web-server
    spec:
      hostNetwork: true
      affinity:
        podAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - node-cache
            topologyKey: "kubernetes.io/hostname"
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - heavy-web-server
            topologyKey: "kubernetes.io/hostname"
      containers:
      - name: web-app
        image: bash
        command: ['sh', '-c', 'echo Secrets demo started && sleep 600']
        env:
        - name: NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName 
EOF
```

* Deploy the webserver and check how it shares node with the cache

```
kubectl apply -f heavy-web-server.yaml
kubectl get pods -owide --sort-by=.spec.nodeName
```

* Check you can access the cache from the other pod:

```bash
HEAVY_POD=$(kubectl get pod -l app=heavy-web-server -o jsonpath="{.items[0].metadata.name}")
kubectl exec -it $HEAVY_POD -- bash -c 'echo stats | nc $NODE_NAME 8888'
 ```

## Taints and tolerations

A *taint* allows a node to refuse a pod unless it is marked with a `toleration. They are sueful to create dedicated nodes, avoid deploying mundane pods in specialized or expensive nodes and expulse pods from existing nodes.

* Get one node, we will use it as our *taint* target

```
export SPECIAL_NODE=$(kubectl get nodes --output name | head --lines 1)
echo We are going to use $SPECIAL_NODE
```

* Mark it with a *taint* named `special` (this word is arbitrary, could be `potato`). Set its value to `true` and forbid any pod not having that combination from being scheduled on it thanks to the keyword `NoSchedule`. Other possible options are `NoExecute` (will evict existing pods in the node if they don't have the *toleration*) and `PreferNoSchedule`.

```
kubectl taint nodes $SPECIAL_NODE special=true:NoSchedule
kubectl describe $SPECIAL_NODE | grep Taints
```

* Launch ten replicas of a pod, without the toleration. 

```yaml
cat << EOF > not-special-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: not-special-deployment
spec:
  selector:
    matchLabels:
      app: not-special-pod
  replicas: 10
  template:
    metadata:
      labels:
        app: not-special-pod
    spec:
      containers:
      - name: main
        image: bash
        command: ['sh', '-c', 'echo Secrets demo started && sleep 6000']
EOF

kubectl apply -f not-special-deployment.yaml
```

* Check they have not been placed in the special node:

```bash
echo The special node is $SPECIAL_NODE

kubectl get pod \
  -o=custom-columns=NAME:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName \
  --sort-by=.spec.nodeName

```
