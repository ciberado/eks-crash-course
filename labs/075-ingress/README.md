# Ingress

## Configure cluster

* Apply the resources

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/mandatory.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/aws/service-l4.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/aws/patch-configmap-l4.yaml
```

* Check when are they ready to be used

```bash
kubectl get pods --all-namespaces -l app.kubernetes.io/name=ingress-nginx --watch
```

## Test the ingress controller

* Create resource files if needed:

```bash
cat << 'EOF' > pokemon-1.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pokemon-1
spec:
  selector:
    matchLabels:
      app: pokemon-1
  replicas: 2
  strategy:
      type: RollingUpdate
      rollingUpdate:
        maxSurge: 1
        maxUnavailable: 0    
  template:
    metadata:
      labels:
        app: pokemon-1
        version: 0.0.1
    spec:
      containers:
      - name: pokemon-container
        image: ciberado/pokemon-nodejs:0.0.1
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: pokemon-service-1
spec:
  selector:
    app: pokemon-1
  ports:
  - name: http
    protocol: TCP
    port: 80
    targetPort: 80
EOF
```

```bash
cat << 'EOF' > pokemon-2.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pokemon-2
spec:
  selector:
    matchLabels:
      app: pokemon-2
  replicas: 2
  strategy:
      type: RollingUpdate
      rollingUpdate:
        maxSurge: 1
        maxUnavailable: 0    
  template:
    metadata:
      labels:
        app: pokemon-2
        version: 0.0.2
    spec:
      containers:
      - name: pokemon-container
        image: ciberado/pokemon-nodejs:0.0.2
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: pokemon-service-2
spec:
  selector:
    app: pokemon-2
  ports:
  - name: http
    protocol: TCP
    port: 80
    targetPort: 80
EOF
```

* Deploy two versions of the application and their services

```
kubectl apply -f pokemon-2.yaml
kubectl apply -f pokemon-2.yaml
```

* Create the `ingress` resource

```yaml
cat << 'EOF' > pokemon-ingress.yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: pokemon-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$1 # this is going to remove /v1 or /v2 from the path
spec:
  rules:
  - http:
      paths:
        - path: /v1/?(.*)
          backend:
            serviceName: pokemon-service-1
            servicePort: 80
        - path: /v2/?(.*)
          backend:
            serviceName: pokemon-service-2
            servicePort: 80
EOF
```

* Deploy it

```bash
kubectl apply -f pokemon-ingress.yaml
```

* Wait until you get the external address

```bash
kubectl get ingress pokemon-ingress -owide --watch
```

* Open that address and check the `/v1` and `/v2` paths (don't worry about the unsafe connection warning)

*TODO: Provide a way to specified the root path of the pokemon application so images appear as they should.*