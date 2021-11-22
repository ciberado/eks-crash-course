# Kubernetes crash course

## Configuration

```bash
export AWS_DEFAULT_REGION=eu-west-1

eksctl create cluster --name crashcourse
eksctl get clusters --region eu-west-1
aws eks --region eu-west-1 update-kubeconfig --name crashcourse
kubectl get node
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
kubectl config set-context --namespace demo-$USER --current
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
## Multicontainer pod and private service

```bash
kubectl delete -f demo-pod.yaml --namespace demo-$USER
kubectl delete -f demo-service.yaml --namespace demo-$USER
sed -i 's/LoadBalancer/ClusterIP/g' demo-service.yaml
kubectl apply -f demo-service.yaml --namespace demo-$USER
```

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

```bash
kubectl apply -f demo-pod.yaml --namespace demo-$USER
kubectl logs pokemon web
kubectl logs pokemon nginx
```

```
PORT=$(( ( RANDOM % 1000 )  + 8000 ))
echo $PORT
kubectl port-forward service/pokemonservice -n demo-$USER $PORT:80 --address='0.0.0.0' &
PID=$!
curl --head localhost:$PORT
curl --head localhost:$PORT/?[1-10]
```

```
kill -9 $PID
kubectl delete -f .
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

## helm

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
```

```bash
helm install wp-k8s-$USER bitnami/wordpress --set serviceType=LoadBalancer
```

```bash
export SERVICE_IP=$(kubectl get svc --namespace demo-$USER wp-k8s-$USER-wordpress \
  --template "{{ range (index .status.loadBalancer.ingress 0) }}{{.}}{{ end }}")
echo "WordPress URL: http://$SERVICE_IP/"
echo "WordPress Admin URL: http://$SERVICE_IP/admin"
echo Username: user
echo Password: $(kubectl get secret --namespace demo-$USER wp-k8s-$USER-wordpress \
  -o jsonpath="{.data.wordpress-password}" | base64 --decode)
```

```bash
helm delete wp-k8s-$USER
```
   
 
You can find additional content from the long version of the training [here](k8s-course.zip).
