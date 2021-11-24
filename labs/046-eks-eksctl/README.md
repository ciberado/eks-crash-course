# EKS with `eksctl`

This lab will provide you with the instructions to create a managed k8s cluster on AWS using the third party tool `eksctl`.

## Dependencies

* Install the dependencies

```bash
sudo python3 -m pip install awscli
sudo snap install kubectl --classic
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo apt-get install jq
sudo snap install yq
```

## Configure the environment

* Set autocompletion

```bash
echo 'source <(kubectl completion bash)' >>~/.bashrc
source ~/.bashrc
```

* Create a key pair

```bash
ssh-keygen -t rsa -b 2048 -f ${USER}-key -N ""
```
* Set the default region

```bash
export AWS_DEFAULT_REGION=eu-west-1
```

## Option 1: Imperative cluster creation

* Launch the cluster

```bash
eksctl create cluster \
  --name ${USER}-cluster-$RANDOM \
  --nodes 3 \
  --nodes-min 3 --nodes-max 5 --asg-access \
  --node-type t2.medium \
  --ssh-access --ssh-public-key ${USER}-key.pub \
  --region eu-west-1 \
  --tags owner=${USER},project=k8s
```

## Option 2: Declarative cluster creation

* Create the configuration file

```yaml
cat << EOF > cluster.yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: $USER-cluster-$RANDOM
  region: eu-west-1

nodeGroups:
  - name: ng-1
    minSize: 2
EOF
```

* Apply the configuration:

## Use the cluster

* Wait something like 20 minutes and then take a look at the launched `stacks`

```bash
aws cloudformation describe-stacks | jq -r .Stacks[].StackName | grep $USER
eksctl get clusters
```

* Find the name of the attached role

```bash
INSTANCE_PROFILE_NAME=$(aws iam list-instance-profiles | jq -r '.InstanceProfiles[].InstanceProfileName' | grep ${USER})
echo $(aws iam get-instance-profile --instance-profile-name $INSTANCE_PROFILE_NAME | jq -r '.InstanceProfile.Roles[] | .RoleName')
```

* Check the cluster and the nodes:

```bash
kubectl version
kubectl get nodes
```

* Note the lack of visibility over the masters

```bash
kubectl get pods -n kube-system -owide
```

* It is always possible to rebuild the configuration with:

```bash
export AWS_DEFAULT_REGION=eu-west-1
CLUSTER_NAME=$(eksctl get clusters -o json | jq ".[].metadata.name" -r) && echo Your cluster is $CLUSTER_NAME.
aws eks --region eu-west-1 update-kubeconfig --name $CLUSTER_NAME
kubectl config set-context --namespace demo-$USER --current
```

## Clean up

* Delete the cluster

```bash
eksctl delete cluster --name ${USER}-cluster
```
