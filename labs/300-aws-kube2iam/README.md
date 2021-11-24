# Kube2iam

## Deploying kube2iam


* Ensure you have a k8s cluster deployed and the following variables defined

```bash
export CLUSTER_NAME=<YOUR CLUSTER NAME>
export KOPS_STATE_STORE=s3://<YOUR BUCKET NAME>
export DOMAIN=<YOUR DOMAIN>
export EDITOR=vim
```

* Deploy kube2iam

```bash
kubectl apply -f kube2iam-resources.yaml
```

* **Alternatively** you can use helm:

```bahs
helm install stable/kube2iam --name kube2iam --namespace=kube-system --set host.iptables=true --set rbac.create=true
```

* Get the ID number of your account

```bash
ACCOUNT=$(aws sts get-caller-identity --output text --query 'Account')
echo $ACCOUNT
```

* Find the ARN of the role associated to the worker nodes

```bash
NODES_ROLE_ARN=$(aws iam get-role --role-name=nodes.$CLUSTER_NAME.$DOMAIN --output text --query 'Role.Arn')
echo $NODES_ROLE_ARN
```

* Take a look at the [aws-create-backup-role.json](aws-create-backup-role.json) file. Notice how it creates the role `k8s-backup-replicator` with a trust policy linking it to the worker role

* Replace the placeholder with the actual worker role ARN and create the IAM role

```bash
NODES_ROLE_ARN_ESCAPED=$(echo $NODES_ROLE_ARN  | sed "s/\//\\\\\//")
cat aws-create-backup-role.json | sed "s/NODES_ROLE_ARN/$NODES_ROLE_ARN_ESCAPED/" > aws-create-backup-role-local.json
aws iam create-role --cli-input-json file://aws-create-backup-role-local.json
```

* Attach two policies to the role. **Notice those polices should not be used in production because they are by far too broad in scope**

```bash
aws iam attach-role-policy --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess --role-name k8s-backup-replicator
aws iam attach-role-policy --policy-arn arn:aws:iam::aws:policy/CloudWatchLogsFullAccess --role-name k8s-backup-replicator
```

* Look at [aws-cli.yaml](aws-cli.yaml), specially at the line using annotations to assign the role to the pods

```yaml
# aws-cli.yaml:

template:
  metadata:
    labels:
      app: aws-cli
    annotations:
      iam.amazonaws.com/role: k8s-backup-replicator # <-- iam role selector
```

* Execute it

```bash
kubectl apply -f aws-cli.yaml
```

* Get a shell session to the launched pod

```
POD=$(kubectl get pods -ojson --selector app=aws-cli | jq .items[0].metadata.name -r)
kubectl exec -it $POD sh
```

* Using the previously created session ask the metadata service for the role assumed by the pod

```bash
$ ROLE=$(wget -qO- http://169.254.169.254/latest/meta-data/iam/security-credentials/)
$ echo $ROLE
```

* Check how it is not possible to access EC2 instances (vm) because it is not granted by the role

```bash
$ aws ec2 describe-instances --region eu-west-1
```

* On the other hand it is perfectly possible to list the S3 buckets and even download files from the Simple Storage Service

```
$ aws s3 ls
$ exit
```

* Delete the resources

```bash
kubectl delete deployments/aws-cli
```









