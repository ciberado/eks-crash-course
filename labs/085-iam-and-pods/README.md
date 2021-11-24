# Associating IAM policies to Pods

## Environment configuration

* Create a namespace

```bash
kubectl create ns demo-$USER
kubectl config set-context --namespace demo-$USER --current
```

* Get the name of the cluster

```bash
CLUSTER_NAME=$(eksctl get clusters -o json | jq ".[].name" -r)
```

* Stablish trust relationship between the cluster and IAM using web federation:

```bash
eksctl utils associate-iam-oidc-provider \
  --cluster $CLUSTER_NAME \
  --approve
```

* Get the `arn` of the desired policy

```bahs
S3_RO_POLICY=$(aws iam list-policies --query 'Policies[?PolicyName==`AmazonS3ReadOnlyAccess`].Arn' --output text)
```

* Create a cluster account associated to that policy

```bash
eksctl create iamserviceaccount \
    --name aws-s3-ro-demo-sa \
    --namespace demo-$USER \
    --cluster $CLUSTER_NAME \
    --attach-policy-arn $S3_RO_POLICY \
    --approve \
    --override-existing-serviceaccounts
```

* Check everything is in place

```bash
kubectl get sa aws-s3-ro-demo-sa
```

## Testing policies

* Check how a pod can access S3, as described in the policy:

```bash
kubectl run aws-command-with-role-$RANDOM \
  -it \
  --rm \
  --image=amazon/aws-cli:latest \
  --serviceaccount=aws-s3-ro-demo-sa \
  --restart=Never \
  --namespace demo-$USER \
  --command \
  -- aws s3 ls
```

* Also see how access to other resources (EC2, in this case) is forbidden:

```bash
kubectl run aws-command-with-role-$RANDOM \
  -it \
  --rm \
  --image=amazon/aws-cli:latest \
  --serviceaccount=aws-s3-ro-demo-sa \
  --restart=Never \
  --namespace demo-$USER \
  --command \
  -- aws ec2 describe-instances
```


## Clean up

* Delete the namespace

```bash
kubectl delete ns demo-$USER
```