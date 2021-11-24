# Advanced deployment

## Rolling updates

* Create the deployment descriptor with the update strategy set

```bash
cat << EOF > pokemon.yaml 
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pokemon
spec:
  selector:
    matchLabels:
      app: pokemon
  replicas: 2
  strategy:
      type: RollingUpdate
      rollingUpdate:
        maxSurge: 1
        maxUnavailable: 0    
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

* Launch again the pokemon app 

```bash
kubectl apply -f pokemon.yaml
```

* Expose it to port 80

```bash
kubectl expose deployment pokemon --type="LoadBalancer" --port 80
```

* Confirm the service es correctly deployed

```bash
kubectl get services -o wide
```

* Scale it up to 10 replicas

```bash
kubectl scale deployment pokemon --replicas 10
```

* Check for the new size of the *replica set* and wait until you have 10 pods ready

```bash
kubectl get rs 
```

* Take a look at the deployment events to see how you raised the number of replicas

```bash
kubectl describe deployments pokemon
```

* Open the webpage in your browser

```bash
ADDR=$(kubectl get services pokemon -ojsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo Open http://$ADDR
```
* Notice the `strategy` section in `pokemon.yaml`:

```yaml
  strategy:
      type: RollingUpdate
      rollingUpdate:
        maxSurge: 1         <-- upgrade one replica each time in a new deployment
        maxUnavailable: 0   <-- keep the old replica while the new one is being deployed
```

* Update the image with a new version and check the process until it is completed

```bash
sed -i 's/0.0.1/0.0.2/g' pokemon.yaml
kubectl apply -f pokemon.yaml
kubectl rollout status deployment pokemon
```

* Annotate the action to document it properly

```bash
kubectl annotate deployment pokemon kubernetes.io/change-cause='New release, version 0.0.2 deployed'
```

* Check how a new *replicaset* has been created to accomodate the new pods

```bash
kubectl get rs
```

* Look the event list and how both *replicasets* exchanged capacity

```bash
kubectl describe deployments
```

* Reload the frontpage in your browser and see how it has changed the version number (install [jq](https://stedolan.github.io/jq/) if you want to copy and paste the command)

```bash
ADDR=$(kubectl get services pokemon -ojsonpath='{.status.loadBalancer.ingress[0].hostname}')
start http://$ADDR
```

* Take a look at the deployment history

```bash
kubectl rollout history deployment pokemon
```

* If there is a problem with the new version we need to proceed with a rollback starting by taking a look at the description of the previous version

```bash
kubectl rollout history deployment pokemon --revision=1
```

* Lets execute the rollback to revision 1

```
kubectl rollout undo deployment pokemon --to-revision=1
kubectl annotate deployment pokemon kubernetes.io/change-cause='Rollback to the previous revision'
kubectl rollout history deployment pokemon
```

* Remember: it is possible to control the number of stored revisions using [.spec.revisionHistoryLimit](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#revision-history-limit)

* Cleanup everything

```
kubectl delete deployments pokemon
kubectl delete services pokemon
```


## Challenge

* Create a simple project containing a single `index.html` file showing some message
* Create a `Dockerfile` to deploy the project with its own webserver
* Write the deployment descriptors to deploy the project as a pod and a service, using v1.0.0 as tag
* Tag it as `v1.0.0` and upload the project to Github
* Generate a second version changing the content of the file
* Update the deployment descriptors
* Tag this new version as `v1.1.0`, upload the new one to Github, too
* Use the *automatic build* feature of Docker hub to generate both images
* Deploy the `v1.0.0` version in your k8s cluster
* Check it runs correctly
* Execute a rolling update to version `v1.1.0`
* Test it has correctly deployed
* Run a rollback to the previous one
