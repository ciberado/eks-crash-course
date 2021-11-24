# AKS with Virtual node

## Creating an AKS cluster

* Use the portal or [the CLI documentation](https://docs.microsoft.com/en-us/azure/aks/virtual-nodes-cli) to deploy a new cluster with Virtual nodes support.

## Deploying pods on virtual node

* Create the descriptor

```yaml
cat << EOF > virtual-node-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pokemonvirtual
spec:
  replicas: 1
  selector:
    matchLabels:
      app: pokemonvirtual
  template:
    metadata:
      labels:
        app: pokemonvirtual
    spec:
      containers:
      - name: webapp
        image: ciberado/pokemon-nodejs:0.0.1
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 1
          limits:
            cpu: 1
      nodeSelector:
        kubernetes.io/role: agent
        beta.kubernetes.io/os: linux
        type: virtual-kubelet
      tolerations:
      - key: virtual-kubelet.io/provider
        operator: Exists
      - key: azure.com/aci
        effect: NoSchedule
EOF
```

* Launch the resource and check how it is deployed

```bash
kubectl create ns demo
kubectl apply -f virtual-node-deployment.yaml -n demo
kubectl get pods -n demo --watch
kubectl logs -n demo deployments/pokemonvirtual
```

* Expose it as a service

```bash
kubectl expose deployment pokemonvirtual -n demo --port=80 --target-port=80 --type=LoadBalancer
kubectl get services -n demo --watch
```

* Open the service with your browser to check everything is ok

* Increase the number of replicas

```bash
kubectl scale -n demo --replicas=50 deployment pokemonvirtual
kubectl get pods -n demo --watch
```

* Reload your browser and see how 49 more pods have been launched

* Clean up everything

```bash
kubectl delete ns demo
```