# RBAC authorization

## Main concepts

* Role based access control **provides protection** to API invocation
* **Rule**: is a statement controlling access to a resource
* **Role**: is a collection of rules attacheable to namespaces
* **ClusterRole**: is the same, but cluster-wide
* **Subject**: who or what tries to access the cluster API
* **User**: humans interacting with the cluster
* **Service Account**: applications in pods accessing the cluster API
* **Groups**: an aggregation of users

## EKS specifics

* AWS *Elastic Kubernetes Service* is integrated by default with the *IAM service*
* Within *EKS* users and roles (for cross account federated access) are described in a *ConfigMap*
* Check [Managing Users](https://docs.aws.amazon.com/eks/latest/userguide/add-user-role.html) in the documentation to read more about it


## Creating a new user

* Define a working namespace with 

```bash
kubectl create namespace demo-$USER
```

* As *user*, generate a *key pair* for user *Alice*

```bash
openssl genrsa -out alice.key 2048
```

* Create a *certificate signed request* for that key

```bash
openssl req -new -key alice.key -out alice.csr -subj "/CN=alice/O=developers"
```

* If using Kops you can find the CA files on S3 (the name will be random):

```bash
key=$(aws s3 ls $KOPS_STATE_STORE/$CLUSTER_NAME.$DOMAIN/pki/private/ca/ |grep key$ |awk '{print $NF}')
aws s3 cp $KOPS_STATE_STORE/$CLUSTER_NAME.$DOMAIN/pki/private/ca/$key ca.key

crt=$(aws s3 ls $KOPS_STATE_STORE/$CLUSTER_NAME.$DOMAIN/pki/issued/ca/ |grep crt$ |awk '{print $NF}')
aws s3 cp $KOPS_STATE_STORE/$CLUSTER_NAME.$DOMAIN/pki/issued/ca/$crt ca.crt
```

* As *administrator*, create the certificate

```bash
openssl x509 -req -in alice.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out alice.crt -days 500
```

* Now we have the user private key (`alice.key`) and the user certificate (`alice.crt`)

## Authorizing the user

* Check [pod-manager-role.yaml](pod-manager-role.yaml) to see the description of the *role* (authorization)

* As *administrator*, create the `pod-manager-role.yaml` to define permission rules and apply it:

```bash
cat << EOF > pod-manager-role.yaml
kind: Role
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: pod-manager
rules:
- apiGroups: ["", "extensions", "apps"]
  resources: ["deployments", "replicasets", "pods"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
EOF

kubectl apply -f pod-manager-role.yaml
```

* Create the binding between the role and the user with the `pod-manager-binding-alice.yaml` file and apply it:

```bash
cat << EOF > pod-manager-binding-alice.yaml
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: pod-manager-binding
subjects:
- kind: User
  name: alice
  apiGroup: ""
roleRef:
  kind: Role
  name: pod-manager
  apiGroup: ""
EOF

kubectl apply -f pod-manager-binding-alice.yaml
```


## Configuring the user *kubectl*

* As *user*, set the new configuration

```
CONTEXT_NAME=$(kubectl config current-context)
echo Your current context is $CONTEXT_NAME.

CLUSTER_NAME=$(kubectl config get-contexts $CONTEXT_NAME --no-headers |  awk '{print $3}')
echo Your current cluster name is $CLUSTER_NAME.

kubectl config set-context alice --cluster $CLUSTER_NAME --namespace demo-$USER --user=alice
kubectl config set-credentials alice \
  --client-certificate=$(pwd)/alice.crt \
  --client-key=$(pwd)/alice.key
kubectl config use-context alice
```

* Test unauthorized access (it will fail)

```
kubectl get nodes
```

* Look for pods in the `default` namespace (it will also fail)

```
kubectl get pods --namespace default
```

* Check authorized access (it will succeed, although maybe you will find zero pods running)

```
kubectl get pods --namespace demo-$USER
```

* Revert to *admin* configuration

```bash
kubectl config get-contexts
kubectl config use-context $CONTEXT_NAME
```

* Cleanup

```bash
delete ns demo-$USER
```

## More information

As usual, the [Unofficial Kubernetes](https://unofficial-kubernetes.readthedocs.io/en/latest/admin/authorization/rbac/) is an excellent source of information regarding this topic.