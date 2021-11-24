# K8s first steps

## Key concepts

* A *manifest* is a text representation of the desired configuration of one or more resources

* A *namespace* is a collection of resources, mostly used to organize them under a single umbrella.

* A *pod* is a group of containers running a main process and (optionally) its sidekicks. Each pod has its own IP address, although it is not directly visible from outside the cluster.

* A *job* is a task executed once (or until it succeeds)

* A *replica set* is a way to manage a desired number of clones of the same pod.

* A *deployment* is a mechanism to control similar *replica sets* that need coordination between them (for example, to deploy a new version of the application)

* A *service* is a load balancer mechanism that facilitates exposing a tcp endpoint balanced between a number of pods

## Running simple pods

* Create the namespace file and send it to the cluster

```yaml
cat << EOF > demo-ns.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: demo-$USER
EOF

kubectl apply -f demo-ns.yaml
```

* Define and deploy a pod on it

```yaml
cat << EOF > demo-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: pokemon
  labels:
    app: pokemon
    type: webapp
spec:
  containers:
  - name: web
    image: ciberado/pokemon-nodejs:0.0.1
EOF

kubectl apply -f demo-pod.yaml --namespace demo-$USER
```

* Check the new resource, in particular how the *cluster-ip* is not publicly accessible

```bash
kubectl get pods --namespace demo-$USER -owide
```

* Expose public access to your pod by using a *service*

```bash
cat << EOF > demo-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: pokemonservice
spec:
  ports:
  - port: 80
    protocol: TCP
    targetPort: 80
  selector:
    app: pokemon
  type: LoadBalancer
EOF

kubectl apply -f demo-service.yaml --namespace demo-$USER
```

* Wait until you get a public endpoint, then press `ctrl+c`

```bash
kubectl get service -owide --namespace demo-$USER --watch
```

* Use filters and shorten-form parameters to query for the bit of information you need. For example

```
ADDR=$(kubectl get svc pokemonservice -n demo-$USER -o jsonpath="{.status.loadBalancer.ingress[0].hostname}")

echo Please, open https://$ADDR
```

* Once you are done, delete it all:

```bash
kubectl delete namespace demo-$USER
```

## Single shot tasks: Jobs

* Create the job descriptor

```yaml
cat << EOF > demo-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: demojob-$USER
  namespace: demo-$USER # <<- we want the job (not only the pod) namespaced
spec:
  template:
    spec:
      containers:
      - image: bash
        name: bashtask
        command: ["/usr/local/bin/bash"]
        args: ["-c", "for i in `seq 1 20`; do echo Hello ${i} times; sleep 1; done"]
      restartPolicy: Never
  backoffLimit: 4
EOF

kubectl create ns demo-$USER  # <<- declarative
kubectl apply -f demo-job.yaml --namespace demo-$USER
```

* Get the log of the pod created by the job

```bash
kubectl logs job/demojob-$USER -n demo-$USER --follow
```

* Cleanup

```bash
kubectl delete ns demo-$USER
```

## Resiliency with deployemnts

* Create a deployment descriptor and deploy it

```yaml
cat << EOF > demo-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demodeployment-$USER
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - image: ciberado/pokemon-nodejs:0.0.1
        name: web
EOF

kubectl create ns demo-$USER
kubectl apply -f demo-deployment.yaml -n demo-$USER
```

* Read the log of one of the replicas

```bash
kubectl logs deployment/demodeployment-$USER -n demo-$USER
```

* You have actually created a bunch of related resources:

```bash
kubectl get deployments,services,replicaset,pods -n demo-$USER
```

* Check the number of replicas using *labels* for filtering

```bash
kubectl get pods -n demo-$USER -l app=web
```

* Create a service for the deployment

```yaml
cat << EOF > demo-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: demoservice
spec:
  ports:
  - port: 80
    protocol: TCP
    targetPort: 80
  selector:
    app: web
  type: LoadBalancer
EOF
```

* Launch the service and check it is running

```bash
kubectl apply -f demo-service.yaml -n demo-$USER
kubectl get service -n demo-$USER -owide --watch
```

* Update the deployment definition and apply the new desired state

```bash
sed 's/replicas: 2/replicas: 10/g' demo-deployment.yaml | kubectl apply -f - -n demo-$USER
```

* See how the new replicas have been deployed

```bash
kubectl get pods -n demo-$USER -l app=web
```

* Clean the house

```bash
kubectl delete ns demo-$USER
```
