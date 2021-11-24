aws_region = "eu-west-1"
cluster_name = "my-minikube"
aws_instance_type = "t2.medium"
ssh_public_key = "~/.ssh/k8s.pub"
aws_subnet_id = "<your public subnet>"
hosted_zone = "<your domain>"
hosted_zone_private = false
tags = {
  Project = "Minikube"
  Owner = "<your name>"
}

addons = [
  "https://raw.githubusercontent.com/scholzj/terraform-aws-minikube/master/addons/storage-class.yaml",
  "https://raw.githubusercontent.com/scholzj/terraform-aws-minikube/master/addons/heapster.yaml",
  "https://raw.githubusercontent.com/scholzj/terraform-aws-minikube/master/addons/dashboard.yaml",
  "https://raw.githubusercontent.com/scholzj/terraform-aws-minikube/master/addons/external-dns.yaml",
  "https://raw.githubusercontent.com/scholzj/terraform-aws-minikube/master/addons/ingress.yaml"
]
