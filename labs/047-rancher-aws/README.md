# Rancher on AWS

## Required tools

* Download and install [terraform](https://www.terraform.io/downloads.html). Check it with

```bash
terraform version
```

* Download and install [git](https://git-scm.com/downloads)

```bash
git version
```

## AWS account configuration

* Login into your account

### Create the key pair

* Go to **ec2 service -> key pairs**
* Click on **Create Key Pair**
* Type `kubernetes` as **Key pair name**
* Download the `kubernetes.pem` file and store it for later

### Adding a new user

Beware: this is not (by far) a correct security configuration. It is intended only to provide a quick start with the platform and it provides too much power to the user. Remove user's permissions if you are not using it.

* Go to **IAM service -> users**
* Click on **Add user**, set your name (for example, `Alice`), check **Programmatic access** and press **Next: Permissions**
* Select the third section (**Attach existing policies directly**), check **AdministratorAccess** and then click on **Next: Tags**
* Click on **Next: Review**
* Take note of the `Access key ID` and the `Secret access key` (you can click on **Download .csv** if you want to)

### Creating the Service Load Balancer role

If this is a new account you should provide permission to AWS to interact with your resources.

* Go to **IAM service -> roles**
* Click on **Create role**
* Click on **ElasticLoadBalancing** and **Next: Permissions**
* Click on **Next: Tags**, **Next: Review** and **Create role**

### Creating the node pool role

Beware: again, this configuration is not wise from the security perspective. Remove role's permissions if you are not using it.

* Go to **IAM service -> roles**
* Click on **Create role**
* Under *Choose the service that will use this role* select **EC2** and click **Next: Permissions**
* Select **AdministratorAccess** and click **Next: Tags**
* Click **Next: Review**
* Type **rancher-role** as *role name* and click on **Create role**

## Deploy the terraform template

* Download the quickstart project and configure your cluster

```bash
git clone https://github.com/rancher/quickstart
cd quickstart/aws
```

* Rename the parameters file

```bash
mv terraform.tfvars.example terraform.tfvars
```

* Edit `terraform.tfvars` and ensure the proper values are correctly configured

```yaml
# Amazon AWS Access Key for your user (created above)
aws_access_key = "AKIA WHATEVER FOLLOWS"
# Amazon AWS Secret Key for your user
aws_secret_key = "YOUR SECRET KEY"
# Amazon AWS Key Pair Name (created several steps before)
ssh_key_name = "kubernetes"
# Region where resources should be created. eu-west-1 is Ireland
region = "eu-west-1"
# Resources will be prefixed with this to avoid clashing names. Use your name, for example
prefix = "<YOUR VERY UNIQUE CLUSTER NAME>"
# Admin password to access Rancher (DON'T LEAVE THIS UNCHANGED)
admin_password = "<PUT SOMETHING WEIRD HERE!!>"
# rancher/rancher image tag to use
rancher_version = "latest"
# We will manually create the nodes (0 masters)
count_agent_all_nodes = "0"
# Additional database nodes
count_agent_etcd_nodes = "0"
# Additional control plane nodes
count_agent_controlplane_nodes = "0"
# We will manually create the nodes (0 workers)
count_agent_worker_nodes = "0"
# Docker version of host running `rancher/rancher`
docker_version_server = "17.03"
# Docker version of host being added to a cluster (running `rancher/rancher-agent`)
docker_version_agent = "17.03"
# Choose between t3.medium or t2.medium
type = "t3.medium"
```

* Create the desired state configuration and run it

```bash
terraform init
terraform apply -auto-approve
```

* Take note of the URL returned by the last command

## Using Rancher

* Wait some minutes and open it in your browser
* If the browser complains about the self-signed certificate, click on **Advanced** and add an exception to the site
* Use the user `admin` and the password you typed in the configuration to access Rancher
* Feel free to delete the *quickstart* cluster, as we are going to define our own
* Press **Add Cluster**
* Choose **Amazon EC2* and type a name for your cluster in **Cluster Name**
* Expad **Node Pools** and click **Add Node Pool** to define two different pools
* Press the first **Add Node Template** button
* Under **Account Access** select *eu-west-1* as the choosen **Region** and then type your user `access key` and `secret key` on the corresponding textfields. After that, press **Next: Authenticate & configure nodes**
* Choose any **Availability Zone** and select the **default-vpc** and **subnet** (must be a public subnet). Click on **Next: Select a Security Group**
* Leave **Standard: Automatially create a rancher-nodes group** option checked and press **Next: Set Instance options**
* Under **Instance** options you just need to provide the previously created role: type `rancher-role` in the **IAM Instane Profile Name** textbox
* Fill the **Name** textfield with something like `eu-west-1-t2.medium`
* Press **Create**

## Pool configuration

* Type `master` on the first node pool, leave `1` as **Count**, choose **eu-west-1-t2.medium** as the template and mark both **etcd** and **Control Plane** checks.
** Type `worker` as the second node pool prefix, set the **Count** to `3` and select the same **eu-west-1-t2.medium** template. Mark the **Worker** check
** Expand the **Cluster Options** element
** Select **Amazon** as the **Cloud Provider** and **Calico** as the **Network Provider**. Ignore the warning message
** Press **Create**!
** wait until the *master* node is provisioned, it will take a few minutes

## Use the cluster

* Ensure you have selected your new cluster (not the *quickstart* one) on the top left option of the menubar
* Click on the **Cluster** option of the menubar and wait until all nodes are provisioned
* Click on **Launch kubectl** (on the top-right part of the screen) and check your cluster by getting the number of nodes, deploying the *Pokemon* application and exposing it with a service

```bash
kubectl get nodes
kubectl create ns demo
kubectl apply -f https://pastebin.com/raw/1g8TGhvK
kubectl apply -f https://pastebin.com/raw/9tnb8qtY
kubectl get services -n demo -owide
```

* Wait a few seconds to allow the Load Balancer register the nodes of the cluster and open its dns name to access the application

## Deleting everything

* Click on the **Cluster** option and delete it
* Open the console in your `quickstart\aws` folder and run

```bash
terraform destroy --auto-approve
```

* Go to **EC2 -> instances** and check they are all in terminated state
* Go to **EC2 -> LoadBalancers** and ensure there are no ELB left