# Imperative commands

* Creating and update resources with imperative style **is only recommended for operating purpouses**

```bash
kubectl create ns demo-$USER
kubectl run web -n demo-$USER --image=ciberado/pokemon-nodejs:0.0.1 --labels=app=web 
kubectl expose deployment/web -n demo-$USER --type "LoadBalancer" --port 80 
kubectl scale deployments/web -n demo-$USER --replicas 20
```

* Remember you can delete everything by cleaning the namespace

```bash
kubectl delete ns demo-$USER
```

* Imperative commands are a very handy way to create a manifest document:

```bash
kubectl run \
  web \
  -n demo-$USER \
  --image=ciberado/pokemon:0.0.1 \
  --labels=app=web \
  --expose \
  --port 80 \
  --dry-run \
  -oyaml
```

* [kubectl man page](https://www.mankier.com/package/kubernetes-client) is a good place to learn more about the client tool 

* Also, the [okd](https://okd.io) project has some excellent [documentation about standard resources](https://docs.okd.io/latest/rest_api/api/v1.Pod.html)
