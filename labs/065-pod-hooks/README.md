# Pod lifecycle hooks

## Key concepts

* `postStart` provides a way to signaling when the pod is in `running` state
* `preStop` allows to inject commands to execute a graceful shutdown of the application

## Manifest syntax

* Create the deployment descriptor, checking the `lifecycle` section.

```yaml
cat << EOF > pokemon.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pokemon
spec:
  selector:
    matchLabels:
      app: pokemon
  replicas: 1
  template:
    metadata:
      labels:
        app: pokemon
        project: pokemon
        version: 0.0.3
    spec:
      containers:
      - name: pokemon-container
        image: ciberado/pokemon-nodejs:0.0.3
        lifecycle:
          postStart:
            exec:
              command: ["/bin/sh", "-c", "echo Application is running on $HOSTNAME > /usr/share/message"]
          preStop:
            exec:
              command: ["/bin/sh", "-c", "echo Use me to send logs, for example.']
EOF
```

## Demo

* Deploy the manifest

```bash
kubectl create ns demo-$USER
kubectl apply -f pokemon.yaml -n demo-$USER
```

* Get the created file

```bash
POD_NAME=$(kubectl get pods -n demo-$USER -l app=pokemon -o jsonpath='{.items[*].metadata.name}')
kubectl cp -n demo-$USER  $POD_NAME:/usr/share/message /tmp/message
cat /tmp/message
```

* Delete resources

```bash
kubectl delete deployment pokemon
```