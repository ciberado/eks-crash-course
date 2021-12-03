# RBAC authorization on EKS

This lab is a simplification of the excellent one provided by AWS on its [eksworkshop.com](https://www.eksworkshop.com/beginner/091_iam-groups/test-cluster-access/) page.

## Installing tooling


* We will need [jq](https://stedolan.github.io/jq/):

```bash
sudo apt-get install jq -yq
```

## IAM Group

We are good folks, so we provide authorization through groups.

* Get your account ID

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo Your account is $ACCOUNT_ID
```

* Define the role the user will assume (we prefix it with `$USER` to avoid role name conflicts, but in a real environment that would not happen):

```
ROLE_TRUST_POLICY=$(echo -n '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"AWS":"arn:aws:iam::'; echo -n "$ACCOUNT_ID"; echo -n ':root"},"Action":"sts:AssumeRole","Condition":{}}]}')

echo $ROLE_TRUST_POLICY | jq

aws iam create-role \
  --role-name ${USER}k8sDevIAMRole \
  --description "Kubernetes developer role (for AWS IAM Authenticator for Kubernetes)." \
  --assume-role-policy-document "$ROLE_TRUST_POLICY" \
  --output text \
  --query 'Role.Arn'
```

* Create the group

```bash
aws iam create-group --group-name ${USER}k8sDevIAMGroup
```

* Attach a policy to it, allowing its members to assume the role `${USER}k8sDevIAMRole`

```bash
ROLE_PERM_POLICY=$(echo -n '{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowAssumeOrganizationAccountRole",
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Resource": "arn:aws:iam::'; echo -n "$ACCOUNT_ID"; echo -n ":role/${USER}k8sDevIAMRole"; echo -n '"
    },
    {
        "Effect": "Allow",
        "Action": [
            "eks:DescribeCluster",
            "eks:ListClusters"
        ],
        "Resource": "*"
    }    
  ]
}')
echo $ROLE_PERM_POLICY | jq

aws iam put-group-policy \
--group-name ${USER}k8sDevIAMGroup \
--policy-name ${USER}k8sDevPolicy \
--policy-document "$ROLE_PERM_POLICY"
```

* Check the group is in place

```bash
aws iam list-groups --output table
```

## IAM user creation

* Create the user

```bash
aws iam create-user --user-name ${USER}IAMUser
```

* Enroll the user in the dev group

```bash
aws iam add-user-to-group --group-name ${USER}k8sDevIAMGroup --user-name ${USER}IAMUser
```

* Check everything is fine

```bash
aws iam get-group --group-name ${USER}k8sDevIAMGroup
```

* Generate AK/SC credentials

```bash
aws iam create-access-key --user-name ${USER}IAMUser | tee /tmp/${USER}IAMUser.json
```

## EKS Configuration

* Create the ns

```bash
kubectl create ns dev-$USER
```

* Apply the `Role` and `RoleBinding` to the `dev-$USER` namespace (`$USER-dev-role` is used instead of simply `dev-user` even if it only applies to the current namespace to make explanation easier to understand)

```bash
cat << EOF | kubectl apply -f - -n dev-$USER
kind: Role
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: $USER-dev-role
rules:
  - apiGroups:
      - ""
      - "apps"
      - "batch"
      - "extensions"
    resources:
      - "configmaps"
      - "cronjobs"
      - "deployments"
      - "events"
      - "ingresses"
      - "jobs"
      - "pods"
      - "pods/attach"
      - "pods/exec"
      - "pods/log"
      - "pods/portforward"
      - "secrets"
      - "services"
    verbs:
      - "create"
      - "delete"
      - "describe"
      - "get"
      - "list"
      - "patch"
      - "update"
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: $USER-dev-role-binding
subjects:
- kind: User
  name: $USER-dev-user
roleRef:
  kind: Role
  name: $USER-dev-role
  apiGroup: rbac.authorization.k8s.io
EOF
```

* Asociate `$USER-dev-user` in *kubernetes* to the `k8sDev` role by updating the `aws-auth` map:

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

CLUSTER_NAME=$(kubectl config view --minify -o jsonpath='{.clusters[].name}' | cut -d. -f1)

eksctl create iamidentitymapping \
  --cluster $CLUSTER_NAME \
  --arn arn:aws:iam::${ACCOUNT_ID}:role/${USER}k8sDevIAMRole \
  --username $USER-dev-user
```

* Check the whole `ConfigMap`:

```bash
kubectl get configmap -n kube-system aws-auth -o yaml
```

* Retreive all roles defined in the cluster

```bashv
eksctl get iamidentitymapping --cluster $CLUSTER_NAME
```

## Configuring developer workstation

Note: remember in case of messing up the configuration you can restore it with `aws eks --region eu-west-1 update-kubeconfig --name $CLUSTER_NAME`.

* Ensure the region is set correctly

```bash
export AWS_DEFAULT_REGION=eu-west-1
```

* Configure the assume role credentials. MAYBE you should `rm ~/.aws/*` before

```bash
mkdir ~/.aws

cat << EOF > ~/.aws/credentials
[${USER}IAMUser]
aws_access_key_id=$(jq -r .AccessKey.AccessKeyId /tmp/${USER}IAMUser.json)
aws_secret_access_key=$(jq -r .AccessKey.SecretAccessKey /tmp/${USER}IAMUser.json)
EOF

cat << EOF > ~/.aws/config
[profile eksDevProfile]
role_arn=arn:aws:iam::${ACCOUNT_ID}:role/${USER}k8sDevIAMRole
source_profile=${USER}IAMUser
EOF
```

* Check it is correctly configured:

```bash
aws sts get-caller-identity --profile ${USER}IAMUser
aws sts get-caller-identity --profile eksDevProfile
```

* Finally, update your `.kube/config`

```bash
eksctl utils write-kubeconfig \
  --cluster $CLUSTER_NAME\
  --authenticator-role-arn arn:aws:iam::${ACCOUNT_ID}:role/${USER}k8sDevIAMRole \
  --profile ${USER}IAMUser
```

## Testing the user

* Check you have the correct context activated

```bash
kubectl config get-contexts
```

* Try (and fail) getting the nodes of the cluster or the pods in the default namespace

```bash
kubectl get nodes
kubectl get pods
```

* Get the pods (zero, but that's ok) in the `dev-$USER` namespace

```bash
kubectl get pods -n dev-$USER
```

## Clean it up

```bash
rm -fr .kube
eksctl utils write-kubeconfig --cluster $CLUSTER_NAME
kubectl delete namespace dev-$USER
eksctl delete iamidentitymapping \
  --cluster $CLUSTER_NAME \
  --arn arn:aws:iam::${ACCOUNT_ID}:role/${USER}k8sDevIAMRole
aws iam remove-user-from-group --group-name ${USER}k8sDevIAMGroup --user-name ${USER}IAMUser
aws iam delete-group-policy --group-name ${USER}k8sDevIAMGroup --policy-name ${USER}k8sDevPolicy 
aws iam delete-group --group-name ${USER}k8sDevIAMGroup
aws iam delete-access-key --user-name ${USER}IAMUser --access-key-id=$(jq -r .AccessKey.AccessKeyId /tmp/${USER}IAMUser.json)

aws iam delete-user --user-name ${USER}IAMUser
aws iam delete-role --role-name ${USER}k8sDevIAMRole

rm  ~/.aws/{config,credentials}

```
