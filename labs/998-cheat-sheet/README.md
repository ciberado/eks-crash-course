# Kubernetes docs

## Online documentation

* [Official doc](https://kubernetes.io/es/docs/home/)
* [Openshift Community doc](https://docs.okd.io/latest/rest_api/index.html)

## Good cheatsheets

* [Official cheat sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
* [Blue Matador cs](https://www.bluematador.com/learn/kubectl-cheatsheet)
* Printer friendly [Linux Academy cs](https://linuxacademy.com/site-content/uploads/2019/04/Kubernetes-Cheat-Sheet_07182019.pdf)

## Additional tips and tricks

* Get the address of a LoadBalancer service

```
ADDR=$(kubectl get svc pokemonservice -o jsonpath="{.status.loadBalancer.ingress[0].hostname}")
```

* Forward port 80 of a pod to port 8888 of localhost

```
kubectl port-forward pod pokemonpod --address 0.0.0.0 8888:80
```

* Get the name of a pod given a label

```
POD_NAME=$(kubectl get pods -l app=pokemon -o jsonpath='{.items[*].metadata.name}')
```

* Get the IP of a pod given a label

```
POD_ALPHA_IP=$(kubectl get pods -n demo-$USER -l app=pokemon   -ojsonpath={.items[*].status.podIP})
```

* Run a command inside a pod

```
kubectl exec --rm -it beta-pod -- wget -O- -q google.com
```

* Create a service

```
kubectl expose deployment/nginx-deployment --type "ClusterIP" --port 80
```

* Scale pods

```
kubectl scale --replicas 2 pokemon-deployment
```

* Patch the metadata of a resource

```
kubectl patch pod pokemon -p '{"metadata":{"annotations":{"name":"value"}}}'
```

* Export *eks* configuration

```
aws eks --region eu-west-1 update-kubeconfig --name pokemoncluster
```

* Find the name of the current context

```
CONTEXT_NAME=$(kubectl config current-context)
```

* Find the name of the current cluster

```
CLUSTER_NAME=$(kubectl config get-contexts $CONTEXT_NAME --no-headers |  awk '{print $3}')
```

* Set the active namespace

```
kubectl config set-context --current --namespaces projectpokemon
```

* Get pods by node

```
kubectl get pod \
  -o=custom-columns=NAME:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName \
  --sort-by=.spec.nodeName
```

* Node ocupation

```
kubectl get nodes --no-headers \
	| awk '{print $1}' \
	| xargs -I {} sh -c 'echo {}; kubectl describe node {} \
	| grep Allocated -A 5 \
	| grep -ve Event -ve Allocated -ve percent -ve -- ; echo'
```

* Get current AWS account

```
ACCOUNT=$(aws sts get-caller-identity --output text --query 'Account')
```

