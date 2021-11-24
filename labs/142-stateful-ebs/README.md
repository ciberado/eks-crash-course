# EBS volumes


## Key concepts

* awsEBS mounts/unmounts EBS disks to containers
* Only available for EC2 instances sharing AZ with the pod
* `gp2` *StorageClass* will automatically provision the *PVC* and *PV* resources

## Using EBS

* Check the existing `storageclasses` to see if your cluster can manage EBS volumes

```bash
kubectl get storageclasses
```

* Configure your kops cluster editing the configuration

```
kops edit cluster
```

* Add the following lines to the *spec* section (notice these permissions are too broad for a production cluster)

```
spec:
  additionalPolicies:
    master: |
      [{
        "Effect": "Allow",
        "Action": ["ec2:*"],
        "Resource": ["*"]
      }]
```
* Save the file, update the cluster data and apply a rolling update. This process can take several minutes.

```
kops update cluster --yes
kops rolling-update cluster --yes
```

* Volumes must be created first:

```
export CLUSTER_NAME=<name of the cluster>
export KOPS_STATE_STORE=s3://<name of the bucket>
export DOMAIN=<domain>
export EDITOR=vim

VOLUME_ID=$(aws ec2 create-volume --availability-zone=eu-west-1a --size=10 --volume-type=gp2 --tag-specifications "ResourceType=volume,Tags=[{Key=Kubernetes Cluster,Value=$CLUSTER_NAME},{Key=Project,Value=$CLUSTER_NAME},{Key=Content,Value=ValuableData$RANDOM}]" --query VolumeId  --output text)
```

* Read [pod-with-ebs.yaml](pod-with-ebs.yaml) to undestand how the existing volume will be mounted on the pod. **Notice it is forced to exists on the same AZ of the volume**
* Execute it, replacing the placeholder with the actual volume id

```
sed "s/{volume-id}/$VOLUME_ID/g" pod-with-ebs.yaml | kubectl create -f -
```

* Ensure the volume is attached to the pod

```
kubectl describe pods/pod-with-ebs
kubectl logs pod-with-ebs
```

* Get a shell into the pod and create two files: one on the regular container disk and another one on the mounted ebs directory

```
kubectl exec -it pod-with-ebs bash
bash# echo "I will disapear with a relaunch." > /ephemeral-file.txt
bash# echo "I will be persisted on the ebs volume." > /test-ebs/persistent-file.txt
bash# exit
```

* Delete the pod and recreate it 

```
kubectl delete pods/pod-with-ebs
sleep 60
sed "s/{volume-id}/$VOLUME_ID/g" pod-with-ebs.yaml | kubectl create -f -
```

* Attach a session to the pod and check the existance of only `/test-ebs/persistent-file.txt`

```bash
kubectl exec -it pod-with-ebs bash
bash# cat /ephemeral-file.txt           # Doesn't exists
bash# cat /test-ebs/persistent-file.txt # Found!
bash# exit
```

* Clean it all

```
kubectl delete pods/pod-with-ebs
sleep 60
aws ec2 delete-volume --volume-id $VOLUME_ID
```
