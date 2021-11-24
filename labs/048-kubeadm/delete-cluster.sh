#/bin/bash

CLUSTER_NAME=$1

echo Removing credentials

aws iam remove-role-from-instance-profile --instance-profile-name k8s-instanceprofile-$CLUSTER_NAME --role-name k8s-$CLUSTER_NAME
aws iam delete-role-policy --role-name k8s-$CLUSTER_NAME --policy-name k8s-$CLUSTER_NAME-policy
aws iam delete-role --role-name k8s-$CLUSTER_NAME
aws iam delete-instance-profile --instance-profile-name k8s-instanceprofile-$CLUSTER_NAME

aws ec2 delete-key-pair --key-name k8s-keypair-$CLUSTER_NAME

vpcID=$(aws ec2 describe-vpcs --query Vpcs[].[VpcId] --filters "Name=tag:Name,Values=k8s-$CLUSTER_NAME-vpc" --output text)
[ -z "$vpcID" ] && echo VPC not found. && exit

echo "Terminating instances."
instances=$(aws ec2 describe-instances --filters "Name=instance-state-name,Values=running " "Name=tag:Cluster,Values=k8s-$CLUSTER_NAME" --query Reservations[].Instances[].InstanceId --output text)

[ ! -z "$instances" ] && \
  echo Instances: $instances && \
  aws ec2 terminate-instances --instance-ids $instances && \
  aws ec2 wait instance-terminated --instance-ids $instances && \
  sleep 10

echo "Deleting dependencies for vpc (${vpcID})"

aws ec2 describe-subnets --query Subnets[].[SubnetId] --filters "Name=vpc-id,Values=$vpcID" --output text |
    while read subnetID; do
      echo "...deleting subnet (${subnetID}) ..."
      aws ec2 delete-subnet --subnet-id ${subnetID}     
    done

  aws ec2 describe-security-groups --filter "Name=vpc-id,Values=$vpcID" --query SecurityGroups[].[GroupId] --output text | 
    while read sgID; do
      echo "...deleting security group (${sgID}) ..."

      aws ec2 delete-security-group --group-id ${sgID}     
    done

  aws ec2 describe-internet-gateways --filter "Name=attachment.vpc-id,Values=$vpcID" --query InternetGateways[].[InternetGatewayId] --output text | 
    while read igwID; do
      echo "...deleting internet gateway (${igwID}) ..."

      aws ec2 detach-internet-gateway --internet-gateway-id=${igwID} --vpc-id=${vpcID}     
      aws ec2 delete-internet-gateway --internet-gateway-id=${igwID}     
    done

  aws ec2 describe-route-tables --filter "Name=vpc-id,Values=$vpcID" --query RouteTables[].[RouteTableId] --output text |
    while read routeID; do
      echo "...deleting route table (${routeID}) ..."

      aws ec2 delete-route-table --route-table-id ${routeID}      &>/dev/null
    done

  echo "Deleting vpc (${vpcID})"
  aws ec2 delete-vpc --vpc-id ${vpcID}         
