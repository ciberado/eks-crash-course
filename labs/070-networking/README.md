## Services

* May manage **several replicas of the pods**
* They are the natural k8s **load balancers between replicas**
* Pods are managed by a service using **label selectors**
* Each service has its own **cluster IP**
* Using *kube-proxy* services can provide **pod load balancing**
* It is possible to **manually set** the cluster IP of a service

### Understanding service discovery

Service discovery allows to find resources in the k8s network, mainly using DNS. This exercise will show you the network scope of *pods* and *services*.

* Create the first deployment:

```yaml
cat << EOF > alpha.yaml
apiVersion: v1
kind: Service
metadata:
  name: alpha-service
spec:
  selector:
    app: alpha-app
  type: ClusterIP
  ports:
  - name: http
    protocol: TCP
    port: 80
    targetPort: 80
---
apiVersion: v1
kind: Pod
metadata:
  name: alpha-pod
  labels:
    app: alpha-app
spec:
  containers:
  - name: alpha-bash
    image: bash
    command: ['sh', '-c', 'echo alpha-bash container started && sleep 600']
  - name: alpha-nginx
    image: nginx
EOF
```

* And the second one:

```yaml
cat << EOF > beta.yaml
apiVersion: v1
kind: Service
metadata:
  name: beta-service
spec:
  selector:
    app: beta-app
  type: ClusterIP    
  ports:
  - name: http
    protocol: TCP
    port: 8080
    targetPort: 80
---    
apiVersion: v1
kind: Pod
metadata:
  name: beta-pod
  labels:
    app: beta-app
spec:
  containers:
  - name: beta-bash
    image: bash
    command: ['sh', '-c', 'echo beta-bash started && sleep 600']
EOF
```

* Deploy all the resources with

```bash
kubectl create ns demo-$USER
kubectl apply -f alpha.yaml,beta.yaml -n demo-$USER
```

* Take note of the ClusterIP assigned to the `beta-pod`

```bash
POD_ALPHA_IP=$(kubectl get pods -n demo-$USER -l app=alpha-app  -ojsonpath={.items[*].status.podIP})
echo $POD_ALPHA_IP
POD_ALPHA_DNS_NAME=${POD_ALPHA_IP//./-}
echo $POD_ALPHA_DNS_NAME

POD_BETA_IP=$(kubectl get pods -n demo-$USER -l app=beta-app  -ojsonpath={.items[*].status.podIP})
echo $POD_BETA_IP
POD_BETA_DNS_NAME=${POD_BETA_IP//./-}
echo $POD_BETA_DNS_NAME
```

* Connect to the bash container in the alpha port and experiment a bit with `nslookup` to understand the inter-container visibility

```bash
# Configuration of the alpha-pod dns resolution
kubectl exec -it alpha-pod --container alpha-bash -n demo-$USER \
        -- cat /etc/resolv.conf
# Resolving he second pod from the first one
kubectl exec -it alpha-pod --container alpha-bash -n demo-$USER \
        -- nslookup $POD_BETA_DNS_NAME.demo-$USER.pod.cluster.local
# Resolving the first *service* with the full name
kubectl exec -it alpha-pod --container alpha-bash -n demo-$USER \
        -- nslookup alpha-service.demo-$USER.svc.cluster.local
# Resolving the service with the short name (they are in the same namespace)
kubectl exec -it alpha-pod --container alpha-bash -n demo-$USER \
        -- nslookup alpha-service
# Resolving the second service with the short name
kubectl exec -it alpha-pod --container alpha-bash -n demo-$USER \
        -- nslookup beta-service
# if DNS is not installed, is still possible to find the services existing
# during the creation of the pod
kubectl exec -it alpha-pod --container alpha-bash -n demo-$USER \
        -- nslookup env | grep BETA
# Containers in a pod shares the same network card
kubectl exec -it alpha-pod --container alpha-bash -n demo-$USER \
        -- wget -O- -q localhost:80
# By default, there is no firewall between pods
kubectl exec -it beta-pod -n demo-$USER \
        -- wget -O- -q $POD_ALPHA_DNS_NAME.demo-$USER.pod.cluster.local:80
```

* Extra ball: use `kubectl port-forward alpha-pod 8000:80` to forward port 80 of the *alpha pod* (the nginx server running in the secondary container) to port 8000 of the laptop and open `http://localhost:8000`

* Remove everything

```
kubectl delete ns demo-$USER
```

## Types of services

* A service can be exposed in **three different ways**
* **ClusterIP** is intended for **internal use only**
* **NodePort** will publish a **meshed port** on every worker node
  - Not ideal from the security point of view because lack of granalarity controlling them
  - Will not expose port 80, 443, or actually anything bellow 30000 and your firewall will not be happy
* **LoadBalancer** will associate a native L4 proxy to the service
  - On AWS it will be associated to an ELB ($20 per month)
  - Annotations can be use to further configure the actual resource (for example, installing a certificate)


## External endpoints

* URLs placed outside the cluster can be accessed using services as service discovery abstraction
* The definition is quite straightforward as shown in [httpbin.yaml](httpbin.yaml)

```yaml
cat << EOF > external-yaml
kind: Service
apiVersion: v1
metadata:
 name: hb
spec:
 type: ExternalName
 externalName: httpbin.org
EOF
```

* Create the service

```bash
kubectl create ns demo-$USER
kubectl apply -f external-yaml -n demo-$USER
```

* Launch a pod and access *httpbin* through the service

```bash
kubectl run -it --image bash -n demo-$USER mybash

bash# wget http://hb/get -O- --header=Content-Type:application/json --header=Host:httpbin.org -q
bash# exit
```

* Delete the resources

```
kubectl delete ns demo-$USER
```

## Network policies

* For security reasons it is a bad idea to freely allow interpod communication
* Kubernetes provides an standard *network policies* API
* To actually apply the restrictions an implementation must be deployed
* [Calico](https://www.projectcalico.org/) is a very popular provider
* You will enforce network restriction in the [kubernetes on AWS lab](../k8sonaws/README.md)

## More reading

* [Fantastic article](https://chrislovecnm.com/kubernetes/cni/choosing-a-cni-provider/) about how to choose the most appropiated network provider.