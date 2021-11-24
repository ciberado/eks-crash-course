# Ingress with Kong Api Gateway

* Install kong controller

```bash
kubectl apply -f https://bit.ly/k4k8s
```

* Deploy two different services (pointing, in this case, to external domains)

```bash
cat << EOF > hb-service.yaml
kind: Service
apiVersion: v1
metadata:
 name: hb
spec:
 type: ExternalName
 externalName: httpbin.org
EOF

cat << EOF > ip-service.yaml
kind: Service
apiVersion: v1
metadata:
 name: ip
spec:
 type: ExternalName
 externalName: icanhazip.com
EOF

kubectl apply -f hb-service.yaml
kubectl apply -f ip-service.yaml
```

* Generate the ingress resource descriptor (beware of the **mandatory annotation**)

```yaml
cat << EOF > main-ingress.yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: main-ingress
  annotations:
    kubernetes.io/ingress.class: kong
spec:
  rules:
  - http:
      paths:
        - path: /headers
          backend:
            serviceName: hb
            servicePort: 80
        - path: /ip
          backend:
            serviceName: ip
            servicePort: 80
EOF
```
* Create the ingress resource

```bash
kubectl apply -f main-ingress.yaml
```

* Access the *Kong* external load balancer using the *Ingress*:

```bash
kong=$(kubectl get services -n kong -ojsonpath='{.items[*].status.loadBalancer.ingress[0].hostname}')
echo Please open http://$kong/headers and http://$kong/ip to check both websites.
```

* Open `$kong` in your browser to check everything is fine

* Define a *ratelimit* resource

```yaml
cat << EOF > ratelimit.yaml
apiVersion: configuration.konghq.com/v1
kind: KongPlugin
metadata:
  name: ratelimit
config: 
  second: 5
  hour: 10
  policy: local
plugin: rate-limiting
EOF
```

* Deploy the rate limit plugin and patch the *ingress* resource configuration to activate it

```bash
kubectl apply -f ratelimit.yaml
```

* Instruct the **desired service** to use the new plugin with an annotation:

```bash

cat << EOF > hb-service.yaml
kind: Service
apiVersion: v1
metadata:
  name: hb
  annotations:
    konghq.com/plugins: ratelimit
spec:
 type: ExternalName
 externalName: httpbin.org
EOF
```

* Apply the changes using

```bash
kubectl apply -f hb-service.yaml
```

* Access the service endpoint again: soon you receive a `rate limit exceeded` error

```bash
echo Please open http://$kong/headers
```

* Delete everything 

```bash
kubectl delete ns kong
```

## Further reading

* Check the list of [kong plugins](https://docs.konghq.com/hub/)
