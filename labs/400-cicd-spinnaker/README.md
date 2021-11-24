# Spinnaker

## Setup

* Create the cluster (we are going to use large instances because Spinnaker is memory-intensive). Refer to [Kops installation](../044-kops/README.md) for details

```bash
ssh-keygen -t rsa -b 2048 -f kops -N ""

export CLUSTER_NAME=<cluster_name>
export KOPS_STATE_STORE=s3://<bucket_name>
export DOMAIN=<domain_name>
export EDITOR=vim

kops create cluster \
  --state $KOPS_STATE_STORE \
  --name $CLUSTER_NAME.$DOMAIN \
  --master-size t2.large \
  --master-count 1 \
  --master-zones eu-west-1a \
  --node-count 4 \
  --node-size t2.large \
  --zones eu-west-1a,eu-west-1b,eu-west-1c \
  --networking calico  \
  --cloud-labels "Owner=kops,Project=$CLUSTER_NAME" \
  --ssh-public-key kops.pub \
  --authorization RBAC \
  --yes

kops validate cluster
```
* Setup helm. Refer to [Helm](../160-helm/README.md) for details

```
helm init
kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding \
    tiller-cluster-rule \
    --clusterrole=cluster-admin \
    --serviceaccount=kube-system:tiller
kubectl patch deploy \
   --namespace kube-system \
   tiller-deploy \
   -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}' 
helm repo update
```

* Adapt the [configuration file](labs/200-spinnaker/values.yaml) to your needs

```bash
S3_BUCKET=<your_s3_bucket_name_without_protocol>
ACCESS_KEY=<your_access_key>
SECRET_KEY=<your_secret_key>
sed "s/{s3-bucket}/$S3_BUCKET/g;s/{access-key}/$ACCESS_KEY/g;s/{secret-key}/$SECRET_KEY/g;" values.yaml > /tmp/values-local.yaml
```

* Deploy Spinnaker (it will take some time)

```bash
helm install -n spinnaker stable/spinnaker -f /tmp/values-local.yaml --debug --namespace spinnaker --timeout 1000
helm list
export DECK_POD=$(kubectl get pods --namespace spinnaker -l "cluster=spin-deck" -o jsonpath="{.items[0].metadata.name}")
kubectl port-forward --namespace spinnaker $DECK_POD 9000
```

* Access Halyard

```bash
kubectl exec --namespace spinnaker -it spinnaker-spinnaker-halyard-0 bash
```
