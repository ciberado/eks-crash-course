# Kubernetes crash course

## Docker introduction

```bash
git clone https://github.com/ciberado/pokemon-nodejs
cd pokemon-nodejs
```

```bash
docker build -t pokemon-nodejs-$USER:0.0.1 .
docker images
```

```bash
PORT=$(( $(echo $USER | tr -dc '0-9') + 8100)); echo $PORT
docker run -d -p $PORT:80 pokemon-nodejs-$USER:0.0.1
curl localhost:$PORT
```

## Configuration

```bash
kubectl config set-context --namespace demo-$USER --current
```

## Namespaces

```bash
cat << EOF > demo-ns.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: demo-$USER
EOF
```

```bash
kubectl apply -f demo-ns.yaml
```

## Pod

```bash
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
    env:
      - name: PORT
        value: "3000"
  - name: nginx
    image: ciberado/nginx
EOF
```

```
kubectl apply -f demo-pod.yaml --namespace demo-$USER
kubectl get pods
```

## Service
 
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
```

```bash
kubectl apply -f demo-service.yaml --namespace demo-$USER
kubectl get services
``` 

```bash
ADDR=$(kubectl get services pokemonservice -ojsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo Open http://$ADDR
```

```bash
kubectl delete -f demo-pod.yaml
```

## Elasticity

```bash
cat << EOF > demo-replicaset.yaml

apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: demoreplicaset-$USER
  labels:
    app: pokemon
spec:
  replicas: 2
  selector:
    matchLabels:
      app: pokemon
  template:
    metadata:
      labels:
        app: pokemon
    spec:
      containers:
      - image: ciberado/pokemon-nodejs:0.0.1
        name: web
EOF
```

```bash
kubectl apply -f demo-replicaset.yaml
kubectl get rs
kubectl get pods -l app=pokemon
```

```bash
sed -i 's/: 2/: 4/g' demo-replicaset.yaml
kubectl apply -f demo-replicaset.yaml
kubectl get pods
```

```bash
kubectl scale rs/demoreplicaset-$USER --replicas=8
kubectl get rs
kubectl get pods
```

```bash
kubectl delete -f demo-replicaset.yaml
```

## Application lifecycle

```bash
cat << EOF > demo-deployment.yaml

apiVersion: apps/v1
kind: Deployment
metadata:
  name: demodeployment-$USER
spec:
  replicas: 2
  selector:
    matchLabels:
      app: pokemon
  template:
    metadata:
      labels:
        app: pokemon
    spec:
      containers:
      - image: ciberado/pokemon-nodejs:0.0.1
        name: web
EOF
```

```bash
kubectl apply -f demo-deployment.yaml
```

```bash
sed -i 's/0.0.1/0.0.2/g' demo-deployment.yaml
kubectl apply -f demo-deployment.yaml
```
```bash
kubectl rollout history deployment demodeployment-$USER
kubectl rollout undo deployment demodeployment-$USER --to-revision=1
```

