# Kubernetes crash course

## Configuration

```bash
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
## Multicontainer pod

```bash
kubectl delete -f demo-pod.yaml --namespace demo-$USER
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

```bash
ADDR=$(kubectl get services pokemonservice -ojsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl --head http://$ADDR/?[1-10]
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
export SERVICE_IP=$(kubectl get svc --namespace demo-student7 wp-k8s-student7-wordpress \
  --template "{{ range (index .status.loadBalancer.ingress 0) }}{{.}}{{ end }}")
echo "WordPress URL: http://$SERVICE_IP/"
echo "WordPress Admin URL: http://$SERVICE_IP/admin"
echo Username: user
echo Password: $(kubectl get secret --namespace demo-student7 wp-k8s-student7-wordpress \
  -o jsonpath="{.data.wordpress-password}" | base64 --decode)
```

```bash
helm delete wp-k8s-$USER
```
   
 
