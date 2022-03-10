# Kubernetes crash course

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
delete ns demo-$USER
```

## Elasticity and application lifecycle

```bash
cat << EOF > demo-lifecycle.yaml

apiVersion: v1
kind: Namespace
metadata:
  name: demo-$USER

---

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

---

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

```bash
kubectl apply -f demo-lifecycle.yaml
```

```bash
sed -i 's/: 2/: 4/g' demo-lifecycle.yaml
kubectl apply -f demo-lifecycle.yaml
kubectl get pods
```

```bash
sed -i 's/0.0.1/0.0.2/g' demo-lifecycle.yaml
kubectl apply -f demo-lifecycle.yaml
```
```bash
kubectl rollout history deployment demodeployment-$USER
kubectl rollout undo deployment demodeployment-$USER --to-revision=1
```

