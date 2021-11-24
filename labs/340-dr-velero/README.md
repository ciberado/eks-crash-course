# Disaster recovery with Heptio Velero

## Preparation

* Define the usual variables and create a `kops` cluster

```bash
export AWS_PROFILE=<aws profile>
export AWS_DEFAULT_REGION=eu-west-1
export CLUSTER_NAME=demo
export KOPS_STATE_STORE=s3://<state store bucket name>
export DOMAIN=<domain name>
export EDITOR=vim
DIRECTORY=$(pwd)

ssh-keygen -t rsa -b 2048 -f $DIRECTORY/kops -N ""

kops create cluster \
  --state $KOPS_STATE_STORE \
  --name $CLUSTER_NAME.$DOMAIN \
  --master-size t2.medium \
  --master-count 1 \
  --master-zones eu-west-1c \
  --node-count 3 \
  --node-size t2.medium \
  --zones eu-west-1a,eu-west-1b,eu-west-1c \
  --networking calico  \
  --cloud-labels "Owner=kops,Project=$CLUSTER_NAME" \
  --ssh-public-key $DIRECTORY/kops.pub \
  --authorization RBAC \
  --yes

kops validate cluster
```

## Configuring credentials

Velero can use S3 to store the backup state and automatically create snapshots of the desired *volumes*, so it will need  access to S3 and EBS. In a production environment it should be accomplished by using `kube2iam` as explained on [the kube2iam lab](../300-aws-kube2iam) but for a demostration we will use static credentials.


* First, define the specific env variables

```bash
SUFFIX=$RANDOM  
BUCKET=velero-lab-$SUFFIX
REGION=eu-west-1
```

* Create an empty bucket to store your backups

```bash
aws s3api create-bucket \
    --bucket $BUCKET \
    --region $REGION \
    --create-bucket-configuration LocationConstraint=$REGION
```

* Define the *iam* policy

```json
cat > $DIRECTORY/velero-policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeVolumes",
                "ec2:DescribeSnapshots",
                "ec2:CreateTags",
                "ec2:CreateVolume",
                "ec2:CreateSnapshot",
                "ec2:DeleteSnapshot"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:DeleteObject",
                "s3:PutObject",
                "s3:AbortMultipartUpload",
                "s3:ListMultipartUploadParts"
            ],
            "Resource": [
                "arn:aws:s3:::${BUCKET}/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::${BUCKET}"
            ]
        }
    ]
}
EOF
```

* Create a new user and policy. Attach the policy to the user

```bash
aws iam create-user --user-name velero-lab-$SUFFIX

aws iam put-user-policy \
  --user-name velero-lab-$SUFFIX \
  --policy-name velero-lab-$SUFFIX \
  --policy-document file://$DIRECTORY/velero-policy.json 
```

* Create credentials for that user and save them into a file

```bash
CRED=$(aws iam create-access-key --user-name velero-lab-$SUFFIX --output text) 

A_KEY=$(echo $CRED | cut -d' ' -f 2)
S_KEY=$(echo $CRED | cut -d' ' -f 4)  

cat > $DIRECTORY/credentials-velero <<EOF
[default]
aws_access_key_id=$A_KEY
aws_secret_access_key=$S_KEY
EOF
```

## Installing Velero

* Download [Velero](https://github.com/heptio/velero/releases/), extract the files and add them to the path

```bash
wget https://github.com/heptio/velero/releases/download/v1.1.0-beta.2/velero-v1.1.0-beta.2-linux-amd64.tar.gz
tar xvf velero-v1.1.0-beta.2-linux-amd64.tar.gz 
PATH=$PATH:velero-v1.1.0-beta.2-linux-amd64/
```

* Run the `install` command and check its results

```bash
velero install \
    --provider aws \
    --bucket $BUCKET \
    --secret-file $DIRECTORY/credentials-velero \
    --backup-location-config region=$REGION \
    --snapshot-location-config region=$REGION \
	--wait
	
kubectl logs deployment/velero -n velero
```

## Create a backup

* Deploy some workloads into the cluster

```bash
kubectl create ns demo
kubectl run web -n demo --image=ciberado/pokemon-nodejs:0.0.1 --labels=app=web  --replicas 20
kubectl expose deployment web -n demo --type "LoadBalancer" --port 80 --labels=app=web

kubectl get pods -n demo
```

* Create a new backup of the previously created resources

```bash
velero backup create web-backup --selector app=web
velero backup describe web-backup
velero backup logs web-backup
```

* Do bad things to your cluster

```bash
kubectl delete namespace demo
kubectl get pods -n demo
```

## Restore the state of the cluster

* Just run the `restore` command and describe its results

```bash
velero restore create --from-backup web-backup
velero restore get
```

* Check if we are happy

```bash
kubectl get pods,svc -n demo
```

## Restoring over existant resources

* Change the number of replicas

```bash
kubectl scale deployment web --replicas=2 -n demo 
```

* Delete the service

```bash
kubectl delete service web -n demo
```

* Check the status of the cluster (two replicas, zero services)

```bash
kubectl get pods,svc -n demo
```

* Restore again the service

```bash
velero restore create --from-backup web-backup
velero restore get
```

* Use the suggested command to see how Velero is intelligent enough to restore the service but not mess with the existant pods:

```bash
velero restore describe web-backup-<your backup date>
```

## Cleanup

* Delete it all

```bash
aws iam delete-user-policy --user-name velero-lab-$SUFFIX --policy-name velero-lab-$SUFFIX
aws iam delete-access-key --user-name velero-lab-$SUFFIX --access-key-id $A_KEY 
aws iam delete-user --user-name velero-lab-$SUFFIX

kops delete cluster --yes --name $CLUSTER_NAME.$DOMAIN
```