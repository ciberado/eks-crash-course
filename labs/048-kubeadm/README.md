# Kubeadm cluster

This lab will create a Kubernetes cluster on AWS EC2 infrastructure but the procedure to deploy k8s on baremetal or any other kind of VMs would be exactly the same.

If you are in a hurry, we provide scripts to quickly [launch a new cluster](create-cluster.sh) and [delete the created resources](delete-cluster.sh). Enjoy.

## Infrastructure

* Define, if needed, the AWS env variables

```bash
AWS_PROFILE=<your-credentials-profile-name>
AWS_DEFAULT_REGION=eu-west-1
```

* Define the name of the cluster and the temporal directory

```bash
CLUSTER_NAME=<your-cluster-name>
DIRECTORY=/tmp/kubeadm-$RANDOM

mkdir $DIRECTORY
```

* Create a network

```bash
VPC=$(aws ec2 create-vpc --cidr-block=10.10.0.0/16 --query "Vpc.VpcId" --output text)
aws ec2 create-tags --resources $VPC --tags "Key=Name,Value=k8s-$CLUSTER_NAME-vpc"

IGW=$(aws ec2 create-internet-gateway --query "InternetGateway.InternetGatewayId" --output text)
aws ec2 create-tags --resources $IGW --tags "Key=Name,Value=k8s-$CLUSTER_NAME-igw"
aws ec2 attach-internet-gateway --internet-gateway-id $IGW --vpc-id $VPC

SUBNET=$(aws ec2 create-subnet --vpc-id $VPC --cidr-block 10.10.1.0/24 --query Subnet.SubnetId --output text)
aws ec2 create-tags --resources $SUBNET --tags "Key=Name,Value=k8s-$CLUSTER_NAME-subnet"

MAIN_RT=$(aws ec2 describe-route-tables --query "RouteTables[?VpcId=='$VPC'].RouteTableId" --output text)

aws ec2 create-route --route-table-id $MAIN_RT --gateway-id $IGW --destination-cidr-block 0.0.0.0/0
```

* Define IAM roles and key-pairs. **OBVIOUSLY PERMISSIONS ARE FAR TOO BROAD FOR A PRODUCTION ACCOUNT**, you have been warned

```bash
SG=$(aws ec2 create-security-group --group-name k8s-$CLUSTER_NAME-sg --description "K8s machine" --vpc-id $VPC --query GroupId --output text)
aws ec2 authorize-security-group-ingress --group-id $SG --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $SG --protocol tcp --port 6443 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $SG --protocol tcp --port 0-65000 --source-group $SG

cat << EOF >  $DIRECTORY/ec2-role-trust-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "ec2.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

aws iam create-role --role-name k8s-$CLUSTER_NAME --assume-role-policy-document file://$DIRECTORY/ec2-role-trust-policy.json

cat << EOF > $DIRECTORY/admin-eu-west1-policy.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "*",
            "Resource": "*"
        }
    ]
}
EOF

aws iam put-role-policy --role-name k8s-$CLUSTER_NAME --policy-name k8s-$CLUSTER_NAME-policy --policy-document file://$DIRECTORY/admin-eu-west1-policy.json

aws iam create-instance-profile --instance-profile-name k8s-instanceprofile-$CLUSTER_NAME

aws iam add-role-to-instance-profile --instance-profile-name k8s-instanceprofile-$CLUSTER_NAME --role-name k8s-$CLUSTER_NAME

aws ec2 create-key-pair --key-name k8s-keypair-$CLUSTER_NAME --query 'KeyMaterial' --output text > $DIRECTORY/k8s-keypair-$CLUSTER_NAME.pem
chmod 0400 $DIRECTORY/k8s-keypair-$CLUSTER_NAME.pem
```

## Master creation

* Get the latest and shinest *ubuntu* AMI

```bash
AMI=$(aws ec2 describe-images --owners 099720109477 --filters 'Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-*-18.04-amd64-server-*' 'Name=state,Values=available'  --query 'Images[*].[ImageId,CreationDate,Name]' --output text | sort -k2 -r | head -n1 | cut -f1)
```

* Create the master `user-data`

```bash
cat << EOF > $DIRECTORY/master-user-data.sh
#!/bin/sh

set +x
apt-get update && apt-get install -y apt-transport-https curl 

# Add the Docker Repository
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - 
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu  $(lsb_release -cs)  stable" 

# Add the Kubernetes repository
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - 
cat << EOFX | tee /etc/apt/sources.list.d/kubernetes.list 
deb https://apt.kubernetes.io/ kubernetes-xenial main 
EOFX

# Install Docker, Kubeadm, Kubelet, and Kubectl 
apt-get update 
apt-get install -y docker-ce kubelet kubeadm kubectl 

# Enable net.bridge.bridge-nf-call-iptables
echo "net.bridge.bridge-nf-call-iptables=1" | tee -a /etc/sysctl.conf 
sysctl -p 

# Initialize the cluster and configure kubectl
kubeadm init --pod-network-cidr=10.244.0.0/16 > /kubeadm.tmp.log
mkdir -p /home/ubuntu/.kube
cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
chown -hR ubuntu /home/ubuntu/.kube

# Install the flannel networking plugin
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/bc79dd1505b0c8681ece4de4c0d86c5cd2643275/Documentation/kube-flannel.yml

# Copy configuration to user ubuntu home
su ubuntu -c 'mkdir -p $HOME/.kube && sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config && sudo chown $(id -u):$(id -g) $HOME/.kube/config'

# this file is used to wait until instance configuration is complete
mv /kubeadm.tmp.log /kubeadm.log
EOF
```

* Launch the master

```bash
MASTER_ID=$(aws ec2 run-instances --image-id $AMI --iam-instance-profile Name="k8s-instanceprofile-$CLUSTER_NAME" --key-name k8s-keypair-$CLUSTER_NAME --subnet-id $SUBNET --tag-specifications "ResourceType=instance,Tags=[{Key=Cluster,Value=k8s-$CLUSTER_NAME},{Key=Name,Value=k8s-master-$CLUSTER_NAME}]" --count 1 --instance-type t2.medium --security-group-ids $SG --private-ip-address 10.10.1.164 --associate-public-ip-address --user-data file://$DIRECTORY/master-user-data.sh --query Instances[0].InstanceId --output text)
aws ec2 wait instance-running --instance-ids $MASTER_ID

MASTER_IP=$(aws ec2 describe-instances --instance-ids $MASTER_ID --query Reservations[0].Instances[0].PublicIpAddress --output text)

sleep 30 # Give time to install kubeadm
```

## Workers creation

* Create the workers `user-data`

```bash
cat << EOF > $DIRECTORY/worker-user-data.sh
#!/bin/sh

apt-get update && apt-get install -y apt-transport-https curl 

# Add the Docker Repository
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - 
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu  $(lsb_release -cs)  stable" 

# Add the Kubernetes repository
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - 
cat << EOFX | tee /etc/apt/sources.list.d/kubernetes.list 
deb https://apt.kubernetes.io/ kubernetes-xenial main 
EOFX

# Install Docker, Kubeadm, Kubelet, and Kubectl 
apt-get update 
apt-get install -y docker-ce kubelet kubeadm kubectl 

# Enable net.bridge.bridge-nf-call-iptables
echo "net.bridge.bridge-nf-call-iptables=1" | tee -a /etc/sysctl.conf 
sysctl -p 

EOF
```

* Get the token needed to join this master

```bash
while [ ! -f $DIRECTORY/kubeadm.log ]
do
  scp -o "StrictHostKeyChecking no" -i $DIRECTORY/k8s-keypair-$CLUSTER_NAME.pem ubuntu@$MASTER_IP:/kubeadm.log $DIRECTORY 
  [ ! -f $DIRECTORY/kubeadm.log ] && sleep 10
done
```

* Remove linefeeds and backslashes from that command

```bash
JOIN=$(tail -2 $DIRECTORY/kubeadm.log)
CLEANED=${JOIN//[$'\t\r\n\\']}
echo $CLEANED >> $DIRECTORY/worker-user-data.sh
```

* Launch your workers (two, with this configuration)

```bash
WORKER_ID=$(aws ec2 run-instances --image-id $AMI --iam-instance-profile Name="k8s-instanceprofile-$CLUSTER_NAME" --key-name k8s-keypair-$CLUSTER_NAME --subnet-id $SUBNET --tag-specifications "ResourceType=instance,Tags=[{Key=Kind,Value=k8s-kubeadm},{Key=Cluster,Value=k8s-$CLUSTER_NAME},{Key=Name,Value=k8s-worker-$CLUSTER_NAME}]" --count 2 --instance-type t2.medium --security-group-ids $SG --associate-public-ip-address --query Instances[0].InstanceId --user-data file://$DIRECTORY/worker-user-data.sh --output text)
aws ec2 wait instance-running --instance-ids $WORKER_ID
```

* Check the status of the cluster

```bash
ssh -i $DIRECTORY/k8s-keypair-$CLUSTER_NAME.pem ubuntu@$MASTER_IP kubectl get nodes --watch
```

## Troubleshooting

* My nodes are in a very very *not ready* state! > Probably we tried to apply the network manifest before the master was prepared to accept it. Just run again the command:

```bash
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/bc79dd1505b0c8681ece4de4c0d86c5cd2643275/Documentation/kube-flannel.yml
```

## Cleanup

* Just run the clean up script

```bash
sh delete-cluster.sh $CLUSTER_NAME
```