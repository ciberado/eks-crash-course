# Horizontal Pod Autoscaler

## Adjust the cluster configuration to fix KOPS

Launch the cluster - BUT, some changes this time...REMOVE the "--yes" from the end.  We don't want to create the cluster immediately, we need to adjust some configuration.  If you adjusted the parameters for your cluster originally, be sure to also make these changes.

```bash
kops create cluster \
  --state $KOPS_STATE_STORE \
  --name $CLUSTER_NAME.$DOMAIN \
  --master-size t2.micro \
  --master-count 3 \
  --master-zones eu-west-1a,eu-west-1b,eu-west-1c \
  --node-count 3 \
  --node-size t2.nano \
  --zones eu-west-1a,eu-west-1b,eu-west-1c \
  --networking calico  \
  --cloud-labels "Owner=kops,Project=$CLUSTER_NAME" \
  --ssh-public-key kops.pub \
  --authorization RBAC
```

This will create the configuration, but not deploy, so that we can adjust the configuration:

```
kops edit cluster --name $CLUSTER_NAME.$DOMAIN
```

Make the following changes:

```bash
spec:
  kubeControllerManager:
    horizontalPodAutoscalerUseRestClients: true
    
    ...
    ...
    
kubelet:
  anonymousAuth: false
  authenticationTokenWebhook: true
  authorizationMode: Webhook
```

Once you have added these two lines, deploy the cluster:

```
kops update cluster --name $CLUSTER_NAME.$DOMAIN --yes
```

The cluster will deploy with the updated configuration.  Once validated, we need to apply a small change to the cluster RBAC using the YAML in this folder:

```bash
kubectl apply -f webhook-rbac.yaml
```

Then we can deploy the metrics-server, which will allow the cluster to be aware of CPU and Memory consumption within the containers. 

```bash
helm install stable/metrics-server --name metrics-server --version 2.0.4 --namespace metrics
```

Check the status of the metrics server (should be `Available`):

```bash
kubectl get apiservice v1beta1.metrics.k8s.io -o yaml
```


## Deploy a new Pod to demonstrate scaling with HPA

This pod contains a very simple PHP app to cause some stress, for reference the Dockerfile is:

```
FROM php:5-apache
ADD index.php /var/www/html/index.php
RUN chmod a+rx index.php
```

And within it `index.php` contains a simple function to apply some load:

```php
<?php
  $x = 0.0001;
  for ($i = 0; $i <= 1000000; $i++) {
    $x += sqrt($x);
  }
  echo "OK!";
?>
```

So lets deploy our application, there is a deployment included in `php-apache.yaml`:

```
kubectl run php-apache --image=k8s.gcr.io/hpa-example --requests=cpu=200m --expose --port=80
```

Confirm your deployment and its current scale i.e. only 1 right now:

```bash
kubectl get deployment php-apache
```

Now we will attach a horizontal pod autoscaler to our deployment:

```bash
kubectl autoscale deployment php-apache --cpu-percent=50 --min=1 --max=10
```

And we can check its status - (note: the full command is `kubectl get horizontalpodautoscaler `, but hpa is easier :-) ):

```bash
kubectl get hpa
```

In *another* terminal window, let's apply some load :-)

```
kubectl run -i --tty --rm load-generator --image=busybox --restart=Never -- sh
```

Once you have a shell prompt run the following:

```
while true; do wget -q -O- http://php-apache.default.svc.cluster.local; done
```

After some minutes, returning to your original terminal and checking the status of the HPA you should see it reporting increased load and it may even have already added new instances:

```bash
kubectl get deployment php-apache
kubectl get pods
kubectl get hpa --watch
```

Output should be similar to:

```
NAME         REFERENCE               TARGETS    MINPODS   MAXPODS   REPLICAS   AGE
php-apache   Deployment/php-apache   118%/50%   1         10        4          25m
```

Now stop the load generator with `CTRL-C` and then `CTRL-D` in the other terminal and returning check the status and as the load drops you should see it reduce the scale:

You can also scale based on a range of other metrics, more details can be found here: https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/

