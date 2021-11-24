# Health checks

## Key concepts

* **ReadynessProbe** is used by services to send traffic to the pod
* **LivenessProbe** is used by kubernetes to restart the pod in case of failure
* A pod that fails gracefully when it is not able to achieve its porpouse does not necessary need a *liveness probe*: it will be rescheduled if `restartPolicy` is set to `Always` or `OnFailure`
* `restartPolicy` is applied to all the containers in the pod

## Pod configuration

* Take a look at the configuration of [pokemon.yaml](pokemon.yaml)

```yaml
cat << 'EOF' > pokemon.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pokemon
spec:
  selector:
    matchLabels:
      app: pokemon
  replicas: 1
  template:
    metadata:
      labels:
        app: pokemon
        project: pokemon
        version: 0.0.1
    spec:
      containers:
      - name: pokemon-container
        image: ciberado/pokemon-nodejs:0.0.3
        ports:
        - name: server-port         # <-- use named ports for clarity 
          containerPort: 80
        readinessProbe:             # <-- send me traffic if it is ok
          httpGet:
            port: server-port
            path: "/health"
          initialDelaySeconds: 10   # <-- Grace period for bootstrapping
          periodSeconds: 20         # <-- Check three times per minute
          timeoutSeconds: 5         # <-- Fail if it takes more than this
          successThreshold: 1       # <-- First green means it's ok
          failureThreshold: 2       # <-- Two consecutive ko stops traffic to the pod
        livenessProbe:              # <-- Restart pod if not passed
          httpGet:
            port: server-port
            path: "/health"
          initialDelaySeconds: 30
          periodSeconds: 30
          failureThreshold: 3       # <-- Maybe this is too agressive for production
EOF
```

* Edit the `successThreshold`, `failureThreshold` and `periodSeconds` to more agressive values if you want to test this feature quicker

* Deploy the application

```bash
kubectl create ns demo-$USER
kubectl apply -f pokemon.yaml -n demo-$USER
```

* Check the deployment is complete

```
kubectl describe pods pokemon
```

* Forward the service port to access the application:

```bash
kubectl expose deployment pokemon --type "ClusterIP" --port 80 -n $NS
PORT=$(( ( RANDOM % 100 )  + 8000 ))
kubectl port-forward service/pokemon --address 0.0.0.0 -n demo-$USER $PORT:80 &
```

* Set the application to *unhealthy* state 

```bash
curl localhost:$PORT/health
curl -X DELETE http://localhost:$PORT/poison
curl localhost:$PORT/health
```

* Look for the *readiness* of the pods for some minutes to see it evolving

```bash
kubectl get pods -owide --watch
```

* Cleanup the deployment

```bash
kubectl delete deployments/pokemon
```