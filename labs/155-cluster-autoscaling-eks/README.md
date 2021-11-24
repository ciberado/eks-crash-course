# Draft

https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/cloudprovider/aws/README.md
https://www.eksworkshop.com/beginner/080_scaling/deploy_ca/

```bash
aws autoscaling \
  describe-auto-scaling-groups \
  --query "AutoScalingGroups[].[AutoScalingGroupName, MinSize, MaxSize,DesiredCapacity]" \
  --output table
```

```bash
CLUSTER_NAME=$(eksctl get clusters -o json | jq ".[].name" -r)
echo Working with cluster $CLUSTER_NAME
eksctl utils associate-iam-oidc-provider \
    --cluster $CLUSTER_NAME \
    --approve
```

```bash
cat <<EOF > k8s-asg-policy.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "autoscaling:DescribeAutoScalingGroups",
                "autoscaling:DescribeAutoScalingInstances",
                "autoscaling:DescribeLaunchConfigurations",
                "autoscaling:DescribeTags",
                "autoscaling:SetDesiredCapacity",
                "autoscaling:TerminateInstanceInAutoScalingGroup",
                "ec2:DescribeLaunchTemplateVersions"
            ],
            "Resource": "*",
            "Effect": "Allow"
        }
    ]
}
EOF
```

```bash
aws iam create-policy   \
  --policy-name k8s-asg-policy \
  --policy-document file://k8s-asg-policy.json
```

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo Using account $ACCOUNT_ID
```

```bash  
eksctl create iamserviceaccount \
    --name cluster-autoscaler \
    --namespace kube-system \
    --cluster $CLUSTER_NAME \
    --attach-policy-arn "arn:aws:iam::${ACCOUNT_ID}:policy/k8s-asg-policy" \
    --approve \
    --override-existing-serviceaccounts  

kubectl describe serviceaccount cluster-autoscaler -n kube-system 
```

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml 
```

```bash
kubectl -n kube-system \
    annotate deployment.apps/cluster-autoscaler \
    cluster-autoscaler.kubernetes.io/safe-to-evict="false"	
```

```bash
export K8S_VERSION=$(kubectl version --short | grep 'Server Version:' | sed 's/[^0-9.]*\([0-9.]*\).*/\1/' | cut -d. -f1,2)
export AUTOSCALER_VERSION=$(curl -s "https://api.github.com/repos/kubernetes/autoscaler/releases" | grep '"tag_name":' | sed -s 's/.*-\([0-9][0-9\.]*\).*/\1/' | grep -m1 ${K8S_VERSION})

kubectl -n kube-system \
    set image deployment.apps/cluster-autoscaler \
    cluster-autoscaler=us.gcr.io/k8s-artifacts-prod/autoscaling/cluster-autoscaler:v${AUTOSCALER_VERSION}
```

```bash	
kubectl -n kube-system logs -f deployment/cluster-autoscaler
```

```bash
cat << EOF> pokemon.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pokemon
spec:
  replicas: 1
  selector:
    matchLabels:
      app: pokemon
  template:
    metadata:
      labels:
        service: pokemon
        app: pokemon
    spec:
      containers:
      - image: ciberado/pokemon-nodejs:0.0.1
        name: pokemon
        resources:
          limits:
            cpu: 500m
            memory: 512Mi
          requests:
            cpu: 500m
            memory: 512Mi
EOF
```

```bash
kubectl apply -f pokemon.yaml
kubectl get deployments.apps
```

```bash
kubectl scale deployment pokemon --replicas=10 
```

```bash
kubectl get pods -l app=pokemon -o wide --watch
kubectl deployment cluster-autoscaler -n kube-system logs -f 
```
