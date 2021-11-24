#/bin/bash

set -e
# set -x

[ -z "$1" ] && echo create-cluster NAME-OF-THE-CLUSTER && exit

CLUSTER_NAME=$1
DIRECTORY="/tmp/kubeadm-$RANDOM"

mkdir $DIRECTORY
echo Configuration files created in $DIRECTORY

echo Creating VPC related resources

VPC=$(aws ec2 create-vpc --cidr-block=10.10.0.0/16 --query "Vpc.VpcId" --output text)
aws ec2 create-tags --resources $VPC --tags "Key=Name,Value=k8s-$CLUSTER_NAME-vpc"

IGW=$(aws ec2 create-internet-gateway --query "InternetGateway.InternetGatewayId" --output text)
aws ec2 create-tags --resources $IGW --tags "Key=Name,Value=k8s-$CLUSTER_NAME-igw"
aws ec2 attach-internet-gateway --internet-gateway-id $IGW --vpc-id $VPC

SUBNET=$(aws ec2 create-subnet --vpc-id $VPC --cidr-block 10.10.1.0/24 --query Subnet.SubnetId --output text)
aws ec2 create-tags --resources $SUBNET --tags "Key=Name,Value=k8s-$CLUSTER_NAME-subnet"

MAIN_RT=$(aws ec2 describe-route-tables --query "RouteTables[?VpcId=='$VPC'].RouteTableId" --output text)

aws ec2 create-route --route-table-id $MAIN_RT --gateway-id $IGW --destination-cidr-block 0.0.0.0/0

echo Creating IAM role and EC2 keypair

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
            "Resource": "*",
            "Condition": {
                "StringEquals": {
                    "aws:RequestedRegion": "eu-west-1"
                }
            }
        }
    ]
}
EOF

aws iam put-role-policy --role-name k8s-$CLUSTER_NAME --policy-name k8s-$CLUSTER_NAME-policy --policy-document file://$DIRECTORY/admin-eu-west1-policy.json

aws iam create-instance-profile --instance-profile-name k8s-instanceprofile-$CLUSTER_NAME

aws iam add-role-to-instance-profile --instance-profile-name k8s-instanceprofile-$CLUSTER_NAME --role-name k8s-$CLUSTER_NAME

aws ec2 create-key-pair --key-name k8s-keypair-$CLUSTER_NAME --query 'KeyMaterial' --output text > $DIRECTORY/k8s-keypair-$CLUSTER_NAME.pem
chmod 0400 $DIRECTORY/k8s-keypair-$CLUSTER_NAME.pem

sleep 10 # give time for IAM propagation

echo Launching master node

AMI=$(aws ec2 describe-images --owners 099720109477 --filters 'Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-*-18.04-amd64-server-*' 'Name=state,Values=available'  --query 'Images[*].[ImageId,CreationDate,Name]' --output text | sort -k2 -r | head -n1 | cut -f1)


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

MASTER_ID=$(aws ec2 run-instances --image-id $AMI --iam-instance-profile Name="k8s-instanceprofile-$CLUSTER_NAME" --key-name k8s-keypair-$CLUSTER_NAME --subnet-id $SUBNET --tag-specifications "ResourceType=instance,Tags=[{Key=Cluster,Value=k8s-$CLUSTER_NAME},{Key=Name,Value=k8s-master-$CLUSTER_NAME}]" --count 1 --instance-type t2.medium --security-group-ids $SG --private-ip-address 10.10.1.164 --associate-public-ip-address --user-data file://$DIRECTORY/master-user-data.sh --query Instances[0].InstanceId --output text)
aws ec2 wait instance-running --instance-ids $MASTER_ID

MASTER_IP=$(aws ec2 describe-instances --instance-ids $MASTER_ID --query Reservations[0].Instances[0].PublicIpAddress --output text)

sleep 30 # Give time to install kubeadm

echo Retrieving cluster join configuration

set +e
while [ ! -f $DIRECTORY/kubeadm.log ]
do
  scp -o "StrictHostKeyChecking no" -i $DIRECTORY/k8s-keypair-$CLUSTER_NAME.pem ubuntu@$MASTER_IP:/kubeadm.log $DIRECTORY 
  [ ! -f $DIRECTORY/kubeadm.log ] && sleep 10
done
set -e

echo Launching workers nodes

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

JOIN=$(tail -2 $DIRECTORY/kubeadm.log)
CLEANED=${JOIN//[$'\t\r\n\\']}
echo $CLEANED >> $DIRECTORY/worker-user-data.sh

WORKER_ID=$(aws ec2 run-instances --image-id $AMI --iam-instance-profile Name="k8s-instanceprofile-$CLUSTER_NAME" --key-name k8s-keypair-$CLUSTER_NAME --subnet-id $SUBNET --tag-specifications "ResourceType=instance,Tags=[{Key=Kind,Value=k8s-kubeadm},{Key=Cluster,Value=k8s-$CLUSTER_NAME},{Key=Name,Value=k8s-worker-$CLUSTER_NAME}]" --count 2 --instance-type t2.medium --security-group-ids $SG --associate-public-ip-address --query Instances[0].InstanceId --user-data file://$DIRECTORY/worker-user-data.sh --output text)
aws ec2 wait instance-running --instance-ids $WORKER_ID

# WORKER_IP=$(aws ec2 describe-instances --instance-ids $WORKER_ID --query Reservations[0].Instances[0].PublicIpAddress --output text)

export CLUSTER_NAME
export DIRECTORY

echo Cluster launched. Check it with 
echo   ssh -i $DIRECTORY/k8s-keypair-$CLUSTER_NAME.pem ubuntu@$MASTER_IP kubectl get nodes --watch
