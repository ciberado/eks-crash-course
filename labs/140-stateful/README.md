# Stateful applications

## Stateful applications

* The Pod storage is by default **ephemeral**
* It is possible to use **stateful** pods
* In many cases **it may not be the best solution**
* For slow evolving production systems on AWS **we recommend RDS**

## Volumes

* Backed by plugins called **Volume Drivers**
* The resource is called **PersistentVolume**
* It is a directory accessible to all the containers in a pod
* Survives the restart of a container
* Each container of the pod specifies the volume mount point
* To use a *PersistentVolume* we declare **PersistentVolumeClaims**
* PVC can be ReadWriteOnce, ReadOnlyMany and ReadyWriteMany **(RWO), (ROX), (RWM)**
* AWS EBS is an example of RWO
* Google disks is an example of ROX
* AWS EFS is an example of RWM
* An **StorageClass** is a mechanism to create *PersistentVolume*s dynamically
* PVCs consume PVs just like pods consume nodes

## Playing with local nodes

* Configure *ssh-agent* 

```
eval $(ssh-agent)
ssh-add kops.pem
```

* Take note of one random worker nodes internal IP

```
FIRST_NODE_IP=$(kubectl get nodes --selector=kubernetes.io/role!=master -o jsonpath={.items[0].status.addresses[?\(@.type==\"ExternalIP\"\)].address})
FIRST_NODE_NAME=$(kubectl get nodes --selector=kubernetes.io/role!=master -o jsonpath={.items[0].metadata.name})
```

* Open a session to that node and create a directory with a `helloworld.txt` file

```
ssh admin@$FIRST_NODE_IP
admin@...$ sudo mkdir /mnt/data
admin@...$ echo "Hello, I live in the node" | sudo tee /mnt/data/helloworld.txt
admin@...$ exit
```

* Check [local-node-volume.yaml](local-node-volume.yaml) to see how the directory is mapped to a *PersistentVolume* (note the size of the volume is set to 5GiB)
* Execute the creation of the object

```
kubectl create -f local-node-volume.yaml
```

* Take a look at the status of the *pv*

```
kubectl get pv 
```

* Read the content of [local-node-volume-claim.yaml](local-node-volume-claim.yaml): we are going to claim for a (at least) 3GiB volume
* Create the object

```
kubectl create -f local-node-volume-claim.yaml
```

* Check again the status of the *pv*

```
kubectl get pv 
kubectl get pvc 
```

* We need to be sure the pod is deployed on our selected node so mark it with a label

```
kubectl label nodes $FIRST_NODE_NAME nodedisk=true
```

* Launch the pod and look at its status

```
kubectl apply -f pod-with-local-storage.yaml
kubectl get pods -owide
```

* Get a shell to the main container in the pod and take a look at the mount point

```
kubectl exec -it pod-with-local-storage bash
bash# ls /test-local/
bash# cat /test-local/helloworld.txt
bash# exit
```

## Stateful Sets

* Designed to deploy distributed storage systems like read replicas
* Creates replicas of pods with each one attached to a different *pv*
* Each pod replica and each *pv* has an index
* The deployment of the pods is sequential
* The undeployment follow a LIFO strategy
