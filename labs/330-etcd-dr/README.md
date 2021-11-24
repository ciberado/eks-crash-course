# Disaster recovery with ETCDCTL

## Preparation

* Please, start by running a `kubeadm` cluster following the instructions provided by [048-kubeadm lab](../048-kubeadm)

* Check the *env vars* have been correctly defined

```bash
[ -z "${CLUSTER_NAME}" ] && echo "Please, manually define CLUSTER_NAME"
[ -z "${DIRECTORY}" ] && echo "Please, manually define DIRECTORY"
```

## Check the cluster

* We recover the current master IP and create an alias to easily execute commands on it:

```bash
OLD_MASTER=$(aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" "Name=tag:Name,Values=k8s-master-$CLUSTER_NAME" --query Reservations[].Instances[].InstanceId --output text)
OLD_MASTER_IP=$(aws ec2 describe-instances --instance-ids $OLD_MASTER --query Reservations[0].Instances[0].PublicIpAddress --output text)

alias s="ssh -i $DIRECTORY/k8s-keypair-$CLUSTER_NAME.pem ubuntu@$OLD_MASTER_IP $*"
```

* For example, we can look at the infrastructure pods

```bash
s kubectl get pods -n kube-system
```

## Using `etcdctl`

* Get the name of the pod running `etcd`

```bash
POD=$(s kubectl get pods -n kube-system -l component=etcd -o=jsonpath='{.items[0].metadata.name}') 
echo $POD
```

* Lets describe it to understand how the database process was started, what are their endpoints and where are placed the certificates

```bash
s kubectl describe pod -n kube-system $POD | less
```

* Now jump **inside** the *etcd pod* to play a bit with the database (`-t` creates a *TTY* for the `ssh` connection)

```bash
s -t kubectl exec -it -n kube-system $POD -- /bin/sh
```

* Inside the pod container, create an alias for easily work with etcdctl

```bash
alias ctl="ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/healthcheck-client.crt --key=/etc/kubernetes/pki/etcd/healthcheck-client.key"
ctl version
```

* Put a new record and retrieve it

```bash
ctl put alpha one
ctl get alpha
```

* List the keys of familiar resources:

```bash
ctl get / --prefix --keys-only | grep serviceaccounts
ctl get / --prefix --keys-only | grep /registry/replicasets/
```

* Take a look at the content (it is encoded as [protobuf](https://developers.google.com/protocol-buffers/) but you can still read most of it)

```bash
ctl get /registry/namespaces/default
```

* Exit the container (we will work from your laptop)

```bash
exit
```

## Creating backups

* From the comfort  of your laptop, backup the master's certificates:

```bash
s "sudo tar czf - -C /etc/kubernetes pki" > $DIRECTORY/pki.tar.gz
```

* Launch some pods so we have something backup (use `ctrl+c` to go back to the shell prompt)

```bash
s kubectl run loop --image=ciberado/infinite-loop --labels=app=loop --replicas=8
s kubectl get pods
s kubectl logs -l app=loop --follow --max-log-requests=20
```

* Most of the times, *docker* is used to run `etcdctl`. Create a backup of the current master. Remember: `s` is an alias to `ssh` into the master and we retrieved most of the `etcdctl` configuration from the `kubectl describe` command of the `etcd` pod. Yeah. I know.

```bash
s "sudo docker run \
    --network host --rm \
    -v /etc/kubernetes:/etc/kubernetes \
    -v /home/ubuntu:/backup \
    -v /var/lib/etcd:/var/lib/etcd \
    --env ETCDCTL_API=3 \
    k8s.gcr.io/etcd:3.2.24 \
    /bin/sh -c '\
      etcdctl \
        --endpoints=https://127.0.0.1:2379 \
        --cacert=/etc/kubernetes/pki/etcd/ca.crt \
        --cert=/etc/kubernetes/pki/etcd/healthcheck-client.crt \
        --key=/etc/kubernetes/pki/etcd/healthcheck-client.key  \
        snapshot save /backup/snapshot.db'"

scp -i $DIRECTORY/k8s-keypair-$CLUSTER_NAME.pem ubuntu@$OLD_MASTER_IP:snapshot.db $DIRECTORY/.
```

* Change the number of replicas of the *loop* deployment so we can see how we can still loose part of the cluster's state

```bash
s "kubectl scale deployment loop --replicas=5"
s "kubectl get pods"
```

* Terminate the master!

```bash
aws ec2 terminate-instances --instance-ids $OLD_MASTER
aws ec2 wait instance-terminated --instance-ids $OLD_MASTER
```

## Creating a new master

* Launch another vm with the same general configuration of the former master. **It is specially important to preserve the private IP** (the certificates are associated to it)

```bash
VPC=$(aws ec2 describe-vpcs \
      --query Vpcs[].[VpcId] \
      --filters "Name=tag:Name,Values=k8s-$CLUSTER_NAME-vpc" \
      --output text)

SG=$(aws ec2 describe-security-groups \
     --filters "Name=vpc-id,Values=$VPC" "Name=group-name,Values=k8s-$CLUSTER_NAME-sg" \
     --query SecurityGroups[].GroupId \
     --output text)

SUBNET=$(aws ec2 describe-subnets \
         --query Subnets[].[SubnetId] \
         --filters "Name=vpc-id,Values=$VPC" \
         --output text)

AMI=$(aws ec2 describe-images \
      --owners 099720109477 \
      --filters 'Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-*-18.04-amd64-server-*'\
                'Name=state,Values=available'  \
      --query 'Images[*].[ImageId,CreationDate,Name]' \
      --output text \
      | sort -k2 -r \
      | head -n1 \
      | cut -f1)

NEW_MASTER=$(aws ec2 run-instances \
            --image-id $AMI \
            --iam-instance-profile Name="k8s-instanceprofile-$CLUSTER_NAME" \
            --key-name k8s-keypair-$CLUSTER_NAME \
            --subnet-id $SUBNET \
            --tag-specifications "ResourceType=instance,Tags=[{Key=Cluster,Value=k8s-$CLUSTER_NAME},{Key=Name,Value=k8s-master-$CLUSTER_NAME}]" \
            --count 1 \
            --instance-type t2.medium \
            --security-group-ids $SG \
            --private-ip-address 10.10.1.164 \
            --associate-public-ip-address \
            --user-data file://$DIRECTORY/master-user-data.sh \
            --query Instances[0].InstanceId \
            --output text)

aws ec2 wait instance-running --instance-ids $NEW_MASTER

NEW_MASTER_IP=$(aws ec2 describe-instances \
            --instance-ids $NEW_MASTER \
            --query Reservations[0].Instances[0].PublicIpAddress \
            --output text)

alias s="ssh -i $DIRECTORY/k8s-keypair-$CLUSTER_NAME.pem ubuntu@$NEW_MASTER_IP $*"
```

* Wait around one minute to allow finish `user-data` execution and check your new master (**spoiler alert: it will not work**)

```bash
s "kubectl get nodes --watch"
```

## Recovering the state of the master

* First, we stop all Kubernetes-related processes

```bash
s "sudo kubeadm reset"
```

* Then, overwrite the newly generated certificates with the previously saved ones

```bash
cat $DIRECTORY/pki.tar.gz | s "sudo tar xvzf - -C /etc/kubernetes"
```

* Copy the `etcd` snapshot to the instance

```bash
scp -i $DIRECTORY/k8s-keypair-$CLUSTER_NAME.pem $DIRECTORY/snapshot.db ubuntu@$MASTER_IP:snapshot.db 
```

* Clean the previously hold `etcd` data and restore the database (restore works directly with files so no endpoint configuration has to be provided). Take a close look both at the `etcdctl` command **and the `mv` order**.

```bash
s "sudo rm -fr /var/lib/etcd/"
s "sudo docker run \
    --rm \
    -v /home/ubuntu:/backup \
    -v /var/lib/etcd:/var/lib/etcd \
    --env ETCDCTL_API=3 \
    k8s.gcr.io/etcd:3.2.24 \
    /bin/sh -c \
    'etcdctl snapshot restore /backup/snapshot.db; mv /default.etcd/member/ /var/lib/etcd/'"
```

* Remove the `.kube/config` file

```bash
s "sudo rm -fr .kube"
```

* Relaunch Kubernetes, asking `kubeadm` to ignore the existance of data in the `etcd` directory (it will respect the certificates folder content by default)

```bash
s "sudo kubeadm init --ignore-preflight-errors=DirAvailable--var-lib-etcd"
s "sudo kubeadm token create --print-join-command"
```

* You can compare the output of `kubeadm token create` with the save on your local `kubeadm.log` file: they should be the same because the same certificates have been used

* Copy the new `.kube/config` configuration

```bash
s "mkdir -p /home/ubuntu/.kube && \
   sudo cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config && \
   sudo chown -R ubuntu /home/ubuntu/.kube"
```

* Enjoy your cluster!

```bash
s kubectl get nodes
s kubectl get pods
s kubectl logs -l app=loop --follow --max-log-requests=20
```

* Notice how you have (again) eight replicas instead of five **but with the wrong start date** (because your pods have been deployed without updating their `etcd` record)

## Clean up

* Just remember to run the `delete-cluster.sh` script found [in the kubeadm lab](../048-kubeadm)