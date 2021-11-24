# K8s architecture

## Masters

## Nodes

### Kubeproxy

* Deployed on each node
* Not a pod
* Redirects traffic to the corresponding pod if it is not placed in the node

https://kubernetes.io/docs/concepts/architecture/cloud-controller/