# Kubernetes crash course

## Docker introduction

```bash
git clone https://github.com/ciberado/pokemon-nodejs
cd pokemon-nodejs
npm install
```

```
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
nvm install --lts
```

```bash
npm install
npm run start
```

```bash
docker build -t pokemon-nodejs-$USER:0.0.1 .
docker images
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

## Elasticity and application lifecycle

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
sed -i 's/: 2/: 4/g' demo-deployment.yaml
kubectl apply -f demo-deployment.yaml
kubectl get pods
```

```bash
sed -i 's/0.0.1/0.0.2/g' demo-deployment.yaml
kubectl apply -f demo-deployment.yaml
```
```bash
kubectl rollout history deployment demodeployment-$USER
kubectl rollout undo deployment demodeployment-$USER --to-revision=1
```

