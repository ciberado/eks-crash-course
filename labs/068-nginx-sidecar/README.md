# Sidecar pattern

## Configuration files creation

* Create nginx configuration

```
cat << 'EOF' > nginx.conf
user  nginx;
worker_processes  1;

error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;


events {
    worker_connections  1024;
}

http {
  real_ip_header X-Forwarded-For;
  set_real_ip_from 0.0.0.0/0;

  limit_req_zone $binary_remote_addr zone=limitedzone:10m rate=5r/s;
  # limit_req_zone $http_x_forwarded_for zone=limitedzone:10m rate=1r/s;
  log_format headerLog '$remote_addr - $remote_user [$time_local] $http_x_forwarded_for'
      '"$request" $status $body_bytes_sent '
      '"$http_referer" "$http_user_agent"';

  server {
      location / {
          limit_req zone=limitedzone;
          access_log /var/log/nginx/back.log headerLog;

          proxy_pass http://127.0.0.1:3000;
      }
  }
}
EOF
```

* Create the deployment

```yaml
cat << EOF > pokemon-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pokemon
  labels:
    app: pokemon     
spec:
  selector:
    matchLabels:
      app: pokemon
  replicas: 1
  template:
    metadata:
      labels:
        app: pokemon     
    spec:
      containers:
        - name: web
          image: ciberado/pokemon-nodejs:0.0.1
          env:
          - name: PORT
            value: "3000"
        - name: nginx
          image: nginx:alpine
          volumeMounts:
            - name: nginx-config
              mountPath: /etc/nginx/nginx.conf
              subPath: nginx.conf
      volumes:
        - name: nginx-config
          configMap:
            name: confnginx
EOF
```

## Deploying the demo

* Create demo namespace

```bash
NS=demo-$RANDOM
kubectl create namespace $NS
```


* Create a config map and launch the deployment

```bash
kubectl create configmap confnginx --from-file=nginx.conf -n $NS
kubectl apply -f pokemon-deployment.yaml -n $NS
```

* Check everybody is happy

```bash
kubectl get all -n $NS
kubectl get pods -n $NS
POD=$(kubectl get pod -l app=pokemon -o jsonpath="{.items[0].metadata.name}" -n $NS)
kubectl logs $POD web -n $NS
kubectl logs $POD nginx -n $NS
```

* Publish the deployment

```bash
kubectl expose deployment pokemon --type "LoadBalancer" --port 80 -n $NS
ELB=$(kubectl get service -l app=pokemon -o jsonpath="{.items[0].status.loadBalancer.ingress[0].hostname}" -n $NS)
echo $ELB
```

* Submit some request to the endpoint and feel it fail

```bash
curl -s "http://$ELB/?[1-20]"
```

* Copy the remote logs

```bash
kubectl cp -c nginx $NS/$POD:/var/log/nginx/back.log . 
cat back.log
```

* Feel free to take a look inside the nginx container (`exit` to get back)

```bash
kubectl exec -n $NS -it $POD -c nginx sh
```

* Cleanup everything

```bash
kubectl delete ns $NS
```