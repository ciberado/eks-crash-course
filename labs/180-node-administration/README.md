# Worker node managment

## Key concepts

* A **disruption** on a node can be unexpected or controlled
* A controlled disruption allows to safely remove nodes from the cluster
* A **PodDisruptionBudget** sets the tolerance over the desired number of replicas of a pod while executing a node maintenance

## Setup of the lab

* We need a cluster with 3 worker nodes
* Each node should have around 4GB of memory (`t2.medium` on AWS, for example)
* If not the case, adapt the [pokemon.yaml](pokemon.yaml) manifest to request 60% of the available memory

## PodDisruptionBudged example

* Create the pdb for the pokemon project

```bash
kubectl create pdb pokemonpdb --selector app=pokemon --min-available 2
```
* FYI this would be the equivalent manifest

```yaml
apiVersion: policy/v1beta1
kind: PodDisruptionBudget
metadata:
  creationTimestamp: null
  name: pokemonpdb
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: pokemon
```

* Launch three replicas of the pokemon application

```bash
kubectl apply -f pokemon.yaml
```

* Check the deployed pods (if the cluster is empty they should be placed on different nodes)

```bash
kubectl get pods -owide
```

* Prepare the first node for draining (it will execute an implicit `cordon` operation on the node)

```bash
FIRST_NODE_NAME=$(kubectl get nodes --selector=kubernetes.io/role!=master -o jsonpath={.items[0].metadata.name})
echo Draining $FIRST_NODE_NAME
kubectl drain $FIRST_NODE_NAME --ignore-daemonsets
```

* Check the operation result

```bash
kubectl get nodes
kubectl get pods -owide
```

* Try it again with the second node and check how it success with the `daemon-sets` but is not able to evict the `pokemon` replica

```bash
SECOND_NODE_NAME=$(kubectl get nodes --selector=kubernetes.io/role!=master -o jsonpath={.items[1].metadata.name})
echo Draining $SECOND_NODE_NAME
kubectl drain $SECOND_NODE_NAME --ignore-daemonsets
```

* Put the nodes back online

```
kubectl uncordon $FIRST_NODE_NAME
kubectl uncordon $SECOND_NODE_NAME
```

* Clean it all

```bash
kubectl delete deployment pokemon
kubectl delete pdb pokemonpdb
```