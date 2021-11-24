# Logging


## General concepts

* Containers are expected to send log data to `stdout` and `stderr`
* Kubernetes configures the docker agent to send logs to json files
* Kubernetes **will not rotate** logs
* Logs should not be placed inside the cluster

## Cloudwatch integration with Fluentd

* Set the name of your cloudwatch group

```
CWGROUP=<name>

* Create a cloudwatch logs group

```
aws logs create-log-group --log-group-name $CWGROUP
```

* Take a look at the [aws-create-logger-role.json](aws-create-logger-role.json) file. Notice how it creates the role `k8s-logger` with a trust policy linking it to the worker role

* Replace the placeholder with the actual worker role ARN and create the IAM role

```bash
NODES_ROLE_ARN=$(aws iam get-role --role-name=nodes.$CLUSTER_NAME.$DOMAIN --output text --query 'Role.Arn')
NODES_ROLE_ARN_ESCAPED=$(echo $NODES_ROLE_ARN  | sed "s/\//\\\\\//")
cat aws-create-logger-role.json | sed "s/NODES_ROLE_ARN/$NODES_ROLE_ARN_ESCAPED/" > aws-create-logger-role-local.json
```
* Create the new rol

```
aws iam create-role --cli-input-json file://aws-create-logger-role-local.json
```

* Attach access permission to cw logs. **Notice the policy should not be used in production because it's by far too broad in scope**

```bash
aws iam attach-role-policy --policy-arn arn:aws:iam::aws:policy/CloudWatchLogsFullAccess --role-name k8s-logger
```

* Install *helm* server components

```
helm init
```

* Configure *helm* access to kubernetes resources

```bash
kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding \
    tiller-cluster-rule \
    --clusterrole=cluster-admin \
    --serviceaccount=kube-system:tiller
kubectl patch deploy \
   --namespace kube-system \
   tiller-deploy \
   -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}' 
```

* Add the *incubator* repository to helm

```
helm repo add incubator https://kubernetes-charts-incubator.storage.googleapis.com/
helm repo update
```

* Deploy *fluentd* (notice the use of an old image due to the fact at this time the last one has a problem writing to `/var/logs` not being *root*)

```
helm install incubator/fluentd-cloudwatch \
  --name fluentd2cw \
  --set awsRegion=eu-west-1 \
  --set rbac.create=true \
  --set logGroupName=$CWGROUP
  --set image.tag=v0.12.33-cloudwatch@sha256:0a6763c174ac9456ae3b71ae4485ff5f9ab7ecd5a1542e71248a72c54666f02c \
  --set awsRole=k8s-logger
```

* Check you have one *fluentd* pod per cluster node

```
kubectl --namespace=default get pods -l "app=fluentd-cloudwatch,release=fluentd2cw"
```

* Deploy something

```bash
kubectl deploy -f pokemon.yaml
```

* Look at cloudwatch logs (double check you have selected the correct region) or use the command line tool

```bash
aws logs describe-log-streams --log-group-name kubernetes --log-stream-name-prefix kubernetes.var.log.containers.pokemon
```

* Undeploy fluentd

```bash
helm delete fluentd2cw --purge
```