# Canary deployments

* Create a new deployment descriptor for version `0.0.1`

```yaml
cat << EOF > /tmp/pokemon.yaml 
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pokemon
spec:
  selector:
    matchLabels:
      app: pokemon
  replicas: 10
  template:
    metadata:
      labels:
        app: pokemon
        project: projectpokemon
        version: 0.0.1
    spec:
      containers:
      - name: pokemon-container
        image: ciberado/pokemon-nodejs:0.0.1
        ports:
        - containerPort: 80
EOF
```

* Create a second deployment with the canary version, updating the labels

```yaml
cat << EOF > /tmp/pokemon-canary.yaml 
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pokemon-canary
spec:
  selector:
    matchLabels:
      app: pokemon-canary
  replicas: 1
  template:
    metadata:
      labels:
        app: pokemon-canary
        project: projectpokemon
        version: 0.0.2
    spec:
      containers:
      - name: pokemon-container
        image: ciberado/pokemon-nodejs:0.0.2
        ports:
        - containerPort: 80
EOF
```

* Take a closer look to the properties: it is a new deployment (`pokemon-canary`) with a new version of the application (`0.0.2`) but with the same label `project: projectpokemon`. Also it is important to see how the number of replicas is different

```bash
diff -u /tmp/pokemon.yaml /tmp/pokemon-canary.yaml 
```

* Deploy both versions

```bash
kubectl apply -f /tmp/pokemon.yaml,/tmp/pokemon-canary.yaml 
```

* Expose **both** deployments with a service using the appropriate selector 

```bash
kubectl expose deployments pokemon \
  --type "LoadBalancer" \
  --port 80 \
  --name pokemonsrv \
  --selector="project=projectpokemon"
```

* Check the service is up and running

```bash
kubectl get services/pokemonsrv -owide
```

* You should have two pods with version 0.0.1 and one pod with version 0.0.2 on separate *replicasets*. Check it with

```bash
kubectl get pods --selector project=projectpokemon
kubectl get rs --selector project=projectpokemon
```

* Get the *url* of the service and load the front page several times to see how you can access pods from both deployments

```bash
ADDR=$(kubectl get services pokemon -ojsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo Open http://$ADDR
```

* Create a manual rolling update between both versions increasing the canary replica set

```bash
kubectl scale deployment pokemon-canary --replicas 2
```

* Once satisfied deploy the new version on all pods and remove the canary

```bash
sed -i 's/0.0.1/0.0.2/g' /tmp/pokemon.yaml
kubectl apply -f /tmp/pokemon.yaml
kubectl annotate deployment pokemon kubernetes.io/change-cause='version 0.0.2 deployed'
kubectl delete deployments pokemon-canary
```

* Cleanup everything

```
kubectl delete deployments pokemon
kubectl delete services pokemonsrv
```
