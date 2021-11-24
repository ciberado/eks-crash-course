# External configuration

## ConfigMaps

* Are key/value pairs
* Created as objects from templates or directly from property files
* Accessible from mounted files or env variables

* Create the following resource descriptor

```yaml
cat << EOF > project-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: project-config
data:
  debug.asserts: enabled
  data.path: /data
  data.encoding: UTF8
EOF
```

* Deploy the *ConfigMap*

```
kubectl  apply -f project-config.yaml
```

* Check the result with

```
kubectl describe configmaps project-config
```

* Even if it is a bit long, take time to create and read the following file describing a deployment with the previous configuration loaded using two different methods (environment variables and files), and how to inject Kubernetes *metadata* into the pod (using `.valueFrom.fieldRef`)

```yaml
cat << 'EOF' > config-demo.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: config-demo
spec:
  selector:
    matchLabels:
      app: config-demo
  replicas: 1
  template:
    metadata:
      labels:
        app: config-demo
    spec:
      containers:
      - name: config-demo-container
        image: bash
        env:
          - name: POD_NAME
            valueFrom:
              fieldRef:
                fieldPath: metadata.name
          - name: POD_NAMESPACE
            valueFrom:
              fieldRef:
                fieldPath: metadata.namespace
          - name: POD_IP
            valueFrom:
              fieldRef:
                fieldPath: status.podIP        
          - name: DEBUG_ASSERTS
            valueFrom:
              configMapKeyRef:
                name: project-config
                key: debug.asserts
        command: ['sh', '-c', 'echo "Config demo started (Debug: $DEBUG_ASSERTS)" && sleep 600']
        volumeMounts:
        - name: configuration
          mountPath: "/configuration"
      volumes:
      - name: configuration
        configMap:
          name: project-config
EOF
```

* Launch the deployment

```bash
kubectl apply -f config-demo.yaml
```

* Get the name of the deployed pod

```bash
POD=$(kubectl get pods --selector app=config-demo -ojson | jq .items[0].metadata.name -r)
```

* Look at the bootstrapping message

```
kubectl logs $POD
```

* Access the pod and check the configuration (**don't close the session after it**)

```
kubectl exec -it $POD bash
bash$ ls /configuration/
bash$ cat /configuration/data.encoding
bash$ echo $DEBUG_ASSERTS
```

* Using **another console** update the configuration

```bash
cat project-config.yaml | sed 's/debug.asserts: enabled/debug.asserts: disabled/' | kubectl apply -f -
```

* From the original bash session check how the config value has been updated. **Notice, however, how the env var is still holding the old value**

```bash
bash# cat /configuration/debug.asserts # After a few seconds the new value is reflected
bash# echo $DEBUG_ASSERTS               # env vars are never updated until pod restart
bash# exit
```

* Remove the created resources

```bash
kubectl delete deployments/config-demo
kubectl delete configmaps/project-config
```

## Secrets

* Secrets are the preferred way to expose sensible configuration to a pod
* The default configuration is not secure at all: use encrypted secrets
* If the infra is not 100% k8s it makes sense to use a centralized external repository
* Similar to a *ConfigMap* but with encrypted at rest data
* Can be implemented as files or environment variables
* Can be created imperative or declarative
* Create a secret (**notice base64 is NOT encrypting anything**)

```bash
$ echo mysterious | base64 -w0 
bXlzdGVyaW91cwo=
$ echo "1234568" | base64 -w0
MTIzNDU2NzgK
```

* Check [project-secrets.yaml](project-secrets.yaml) to see how to define them

```yaml
# project-secrets.yaml:

apiVersion: v1
kind: Secret
metadata:
  name: project-secrets
type: Opaque
data:
  password: "bXlzdGVyaW91cwo="
  apikey: "MTIzNDU2NzgK"
```

* Get the secrets from command line

```bash
kubectl get secret project-secrets -ojson | jq .data.password -r | base64 --decode
kubectl get secret project-secrets -ojson | jq .data.apikey -r | base64 --decode
```

* Read the [secrets-demo.yaml](secrets-demo.yaml) template and notice how secrets are injected into the containers using files and env vars

```yaml
# secrets-demo.yaml:

spec:
  containers:
  - name: secrets-demo-container
    image: bash
    env:
      - name: APIKEY
        valueFrom:
          secretKeyRef:
            name: project-secrets
            key: apikey
    command: ['sh', '-c', 'echo Secrets demo started && sleep 600']
    volumeMounts:
    - name: configuration
      mountPath: "/configuration"
  volumes:
  - name: configuration
    secret:
      secretName: project-secrets
      items:
      - key: password
        path: db/password
        mode: 511
```

* Deploy the resources

```bash
kubectl apply -f project-secrets.yaml
kubectl apply -f secrets-demo.yaml
```

* Access the container and read the secrets

```bash
POD=$(kubectl get pods --selector app=secrets-demo -ojson | jq .items[0].metadata.name -r)
kubectl exec -it $POD bash
bash$ cat configuration/db/password
bash$ echo $APIKEY
bash$ exit
```

* Delete everything

```bash
kubectl delete deployments/secrets-demo
kubectl delete secrets/project-secrets
```

