# Kops on AWS

## Configure AWS

* Create an AWS user
* Attach proper permissions policy
* Generate access key/secret key
* Install AWS cli
* Configure cli with downloaded access key/secret key with 

```bash
aws configure --profile kubernetes
```

* Create a hosted zone using `aws route53 create-hosted-zone --name <domain-name>`
* Activate kubernetes profile as default for the session

```bash
export AWS_SDK_LOAD_CONFIG=1
export AWS_DEFAULT_PROFILE=kubernetes
export AWS_PROFILE=kubernetes
export AWS_DEFAULT_REGION=eu-west-1
```


## Configure KOPS

* Install KOPS from https://github.com/kubernetes/kops/releases
* Create a configuration file and load it

```bash
cat << 'EOF' > doconfig.sh
read -p "Cluster name? " CLUSTER_NAME
echo "export CLUSTER_NAME=$CLUSTER_NAME" >> config

read -p "State store? " KOPS_STATE_STORE
echo "export KOPS_STATE_STORE=s3://$KOPS_STATE_STORE" >> config

read -p "Domain name? " DOMAIN
echo "export DOMAIN=$DOMAIN" >> config
EOF

bash doconfig.sh
```

* Load the variables into the environment

```bash
source config
```

* **As an alternative**, you can directly set the values of the variables:

```
export CLUSTER_NAME=<name-of-your-cluster>
export KOPS_STATE_STORE=s3://<name-of-the-bucket>
export DOMAIN=<name-of-your-domain>
export EDITOR=vim
```

* Check you have at least the following permissions assigned to your AWS user:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "*",
            "Resource": "*",
            "Condition": {
                "StringEquals": {
                    "aws:RequestedRegion": "eu-west-1"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:Describe*",
                "route53:*",
                "iam:List*",
                "iam:Get*",
                "iam:CreateInstanceProfile",
                "iam:CreateRole",
                "iam:AddRoleToInstanceProfile",
                "iam:PutRolePolicy",
                "iam:PassRole",
                "iam:RemoveRoleFromInstanceProfile",
                "iam:DeleteRolePolicy",
                "iam:DeleteRole",
                "iam:DeleteInstanceProfile"
            ],
            "Resource": "*"
        }
    ]
}
```

* Create R53 hosted zone (if needed)

```
aws route53 create-hosted-zone --name $DOMAIN --caller-reference dummystring1
```

* Updated your domain ownership details with R53 DNS server addresses

* Create bucket

```bash
aws s3 mb $KOPS_STATE_STORE --region eu-west-1
```

* Create a key pair

```bash
ssh-keygen -t rsa -b 2048 -f kops -N ""
```

* Create the cluster configuration

```
kops create cluster \
  --state $KOPS_STATE_STORE \
  --name $CLUSTER_NAME.$DOMAIN \
  --master-size t2.medium \
  --master-count 3 \
  --master-zones eu-west-1a,eu-west-1b,eu-west-1c \
  --node-count 3 \
  --node-size t2.medium \
  --zones eu-west-1a,eu-west-1b,eu-west-1c \
  --networking calico  \
  --cloud-labels "Owner=kops,Project=$CLUSTER_NAME" \
  --ssh-public-key kops.pub \
  --authorization RBAC
```

* Check the detailed cluster manifest

```bash
kops edit cluster --name $CLUSTER_NAME.$DOMAIN
```

* View the *instance groups* and read their configuration

```bash
kops get ig --name $CLUSTER_NAME.$DOMAIN
kops edit ig nodes --name $CLUSTER_NAME.$DOMAIN
```

* Apply the configuration to create the cluster

```bash
kops update cluster --name $CLUSTER_NAME.$DOMAIN --yes
```

* Wait until the deployment is complete with 

```
watch kops validate cluster
```

* Reconfigure kubectl if needed: 
```
kops export kubecfg --name $CLUSTER_NAME.$DOMAIN
```

* List nodes by typing 
```
kubectl get nodes
```

* For production cluster with Calico, feel free to edit the configuration and activate the [cross zone subnet setting](https://github.com/kubernetes/kops/blob/master/docs/networking.md#enable-cross-subnet-mode-in-calico-aws-only) to improve network performance

```bash
> kops edit cluster
---
networking : { }
+++
networking : { crossSubnet : true}
```

* Update the cluster typing `kops update cluster`

## Adding the dashboard


* Deploy RBAC permissions

```bash
cat << EOF > dashboard-rbac.yaml
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: kubernetes-dashboard
  labels:
    k8s-app: kubernetes-dashboard
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: kubernetes-dashboard
  namespace: kube-system
EOF

kubectl apply -f dashboard-rbac.yaml
```
* Deploy the pods of the dashboard (detailed instructions [here](https://github.com/kubernetes/kops/blob/master/docs/operations/addons.md))

```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/kops/master/addons/kubernetes-dashboard/v1.10.1.yaml
```

* Take note of the authentication secrets

```
kops get secrets kube --type secret -oplaintext 
kops get secrets admin --type secret -oplaintext
```

* Start the local proxy to the master node in a free port (for example, if you are *student1*, start the proxy with PORT=8001)

```
PORT=8001
kubectl proxy --port=$PORT
```

* Open the [dashboard ui](http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy) and use the previous secrets to authenticate yourself into it

## Upgrading the cluster version

* Check the version

```bash
kubectl version
```

* Upgrade the cluster, controlling how much time you give to stabilize the system after each node is updated

```bash
kops upgrade cluster --name $CLUSTER_NAME.$DOMAIN -yes
kops update cluster --name $CLUSTER_NAME.$DOMAIN --yes
kops rolling-update cluster --master-interval=10m --node-interval=10m -v 10 --yes
```

* If a node freezes the process you can try to force its pods with

```bash
kubectl drain --ignore-daemonsets --delete-local-data --force <node>
```

* Check the version again

```bash
kubectl version
```

* As an alternative, consider upgrading each master one at a time:

```bash
kops rolling-update cluster $CLUSTER_NAME.$DOMAIN --instance-group master-eu-west-1a --yes
```

## Setting up a more secure cluster

* Use private topology to avoid exposing the master nodes directly to the internet (the API can still be reached through an ELB, if needed)

```bash
kops create cluster \
  --state $KOPS_STATE_STORE \
  --name $CLUSTER_NAME.$DOMAIN \
  --master-size t2.medium \
  --master-count 3 \
  --master-zones eu-west-1a,eu-west-1b,eu-west-1c \
  --node-count 3 \
  --node-size t2.medium \
  --zones eu-west-1a,eu-west-1b,eu-west-1c \
  --networking calico  \
  --cloud-labels "Owner=kops,Project=$CLUSTER_NAME" \
  --ssh-public-key kops.pub \
  --authorization RBAC \
  --api-loadbalancer-type public \
  --encrypt-etcd-storage \
  --topology private \
  --yes
```

## Delete the cluster

* Simply execute the next statement

```bash
kops delete cluster --name $CLUSTER_NAME.$DOMAIN --yes
```