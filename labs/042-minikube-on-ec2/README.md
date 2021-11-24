# Minikube on EC2

* Download and configure [AWS CLI tools](https://docs.aws.amazon.com/cli/latest/userguide/installing.html)

* Subscribe to the CentOS 7 distribution in the [AWS marketplace](https://aws.amazon.com/marketplace/pp/B00O7WM7QW) (it's free)

* Create a key pair (if you don't already have one). Double check you name it correctly, for example:

```bash
ssh-keygen -f ~/.ssh/k8s -t rsa -b 4096
eval $(ssh-agent)
ssh-add ~/.ssh/k8s
```

* Download *Terraform* binary from [Hashicorp](https://www.terraform.io/downloads.html) and add it to the path.
* Clone the [AWS minikube](https://github.com/scholzj/aws-minikube) project

```bash
git clone https://github.com/scholzj/aws-minikube
cd aws-minikube
```

* Edit [minikube.tfvars](minikube.tfvars) and replace the placeholders with your own configuration. Double check the rest of the lines to ensure they have the correct values

* Deploy it (from `aws-minikube` folder)

```bash
terraform init
# double check you have a subscription to https://aws.amazon.com/marketplace/pp/B00O7WM7QW
terraform apply -f <path to minikube.tfvars>
```

* The deployment **will fail** if you are not subscribed to the *centos* image in the marketplace (it's free). In this case just follow the instructions shown by the command output and retry the previous step

* Wait for the deployment to be completed and then retrieve the `kubectl` configuration following the instructions on the screen (with the scp command) and rename the `kubeconfig` file to `~/.kube/ec2minikube`

* Merge the configuration with the default one

```bash
export KUBECONFIG=~/.kube/config:~/.kube/ec2minikube
```

* Check the context has been succesfully added and select it as the active one

```
kubectl config get-contexts
kubectl config use-context admin@kubernetes
```

* Describe the nodes of your new *minikube*

```
kubectl get nodes
```

* To remove the deployment run

```bash
terraform destroy --var-file <path to minikube.tfvars>
```