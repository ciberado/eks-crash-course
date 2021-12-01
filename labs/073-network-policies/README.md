# Networks policies

* Network policies are implemented by some CNI providers such as [Calico](https://docs.projectcalico.org/v2.0/getting-started/kubernetes/)

## Kops specifics

* Kops supports calico on its bootstrapping by adding `--networking calico` to the `kops create cluster` options

## EKS specifics

* EKS doesn't come by default with Calico
* Install Calico following [AWS instructions](https://docs.aws.amazon.com/eks/latest/userguide/calico.html) 

## Network policies demo

* Launch a nginx process and publish it as a service

```
kubectl create ns demo-$USER
kubectl apply -f https://k8s.io/examples/application/deployment.yaml -n demo-$USER
kubectl expose deployment/nginx-deployment --type "ClusterIP" --port 80 -n demo-$USER
``` 

* Create the network policy

```yaml
cat << EOF > network-policies.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all-ingress
spec:
  podSelector: {}
  policyTypes:
  - Ingress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-ingress-nginx-from-access
spec:
  podSelector:
    matchLabels:
      app: nginx
  policyTypes:
    - Ingress
  ingress:
    - from:
      - podSelector:
          matchLabels:
            run: access
EOF
```

* Using the command line tool, set a network policy with 

```
kubectl apply -f network-policies.yaml -n demo-$USER
```

*  Lets launch a pod with an arbitrary name and try to connect to the nginx server: it will fail miserably.

```bash
kubectl run bashie --rm -ti --image bash
bash# #Will NOT work because of the name of the pod doesn't match network policy selector
bash# wget -O - -q http://nginx-deployment --timeout 3
bash# exit
```

* Do the same from a pod labeled with `run=access` and get that wonderful frontpage

``` bash
kubectl run access --rm -ti --image bash
bash# wget -O - -q http://nginx-deployment    #Will work
bash# exit
```

* Remove the network policy: 

```bash
kubectl delete networkpolicy  allow-ingress-nginx-from-access
```

* Check again the connectivity

``` yaml
kubectl run  bashie --rm -ti --image bash
bash# #Will work: there is no network policy 
bash# wget -O - -q http://nginx-deployment 
bash# exit
```

## Denying by default all traffic

* This policy will forbid traffic between pods by default:

```yaml
apiVersion: networking.k8s.io.v1
kind: NetworkPolicy
metadata:
  name: deny-by-default
spec:
  podSelector: {}
  policyTypes:
  - Ingress
```

## Isolating namespaces

* Network policies can isolate network traffic outside a namespace

* Define a namespace and tag it

```bash
kubectl create namespace production
kubectl label namespace/production purpose=production
```

* Create the network policy

```yaml
cat << EOF > network-policy-ns.yaml
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: allow-prod
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: web
  ingress:
    - from:
      - namespaceSelector:
          matchLabels:
            purpose: production
EOF
```

* Take a look at the [Network policy](network-policy-ns.yaml) and deploy it

```bash
kubectl apply -f network-policy-ns.yaml
```

* Create a `nginx` pod in the `production` namespaces and expose it as a service

```bash
kubectl run web --image=nginx  --labels=app=web --expose --port 80 -n production
```

* Run a `bash` pod **outside** the `production` namespace and try to reach the `nginx` container (it will fail)

```bash
kubectl run test-$RANDOM --namespace=default --rm -i -t --image=alpine -- sh
bash> wget -qO- --timeout=2 http://web.production
```

* Repeat the process, but this time running the pod **inside** the `production` namespace

```bash
kubectl run test-$RANDOM --namespace=production --rm -i -t --image=alpine -- sh
bash> wget -qO- --timeout=2 http://web.production
```

## After demo

* Don't forget to delete that cluster with `kops delete cluster $CLUSTER_NAME.$DOMAIN --yes`
* Be sure you check [kube2iam](https://github.com/jtblin/kube2iam) in order to learn the proper way of providing AWS credentials to the pods

## Additional resources

* An [amazing collection of recipes](
https://github.com/ahmetb/kubernetes-network-policy-recipes
) created by [Ahmet Alp Balkan](https://github.com/ahmetb)
