# Minikube

## Installing (Windows, virtualbox)

* Install choco **using admin privileges**

```
@"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -InputFormat None -ExecutionPolicy Bypass -Command "iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))" && SET "PATH=%PATH%;%ALLUSERSPROFILE%\chocolatey\bin"
```

* Install virtualbox **using an admin console**

```
choco install virtualbox
```

* Add *minikube*: 

```
choco install minikube
```

* Run k8s: 

```
minikube start -v 10 --vm-driver virtualbox
```

* Test minikube: 

```
kubectl get nodes
```

* Configure *kubectl*: 

```
kubectl config use-context minikube
```
* Test kubectl with 

```
kubectl version
```

## Installing (Windows 10 Pro)

Warning: this method is unreliable on many systems. Try to prioritize the virtualbox based one.

* The official documentation is [here](https://kubernetes.io/docs/setup/minikube/)
* You need Windows 10 Pro
* Install Hyper-v 
* Open *Hyper-V manager*
* Select *Virtual switch manager*
* Create a new *External switch* with external network and a nice name
* Install [Docker for Windows](https://store.docker.com/editions/community/docker-ce-desktop-windows) or 
* Open an admin session

* Install choco 

```
@"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -InputFormat None -ExecutionPolicy Bypass -Command "iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))" && SET "PATH=%PATH%;%ALLUSERSPROFILE%\chocolatey\bin"
```

* Add *minikube*: 

```
choco install minikube
```

* Run k8s: 

```
minikube start --vm-driver=hyperv --hyperv-virtual-switch="ExternalVirtualSwitch"
```

* Test minikube: 

```
kubectl get nodes
```

* Configure *kubectl*: 

```
kubectl config use-context minikube
```

* Test kubectl with 

```
kubectl version
```

## Manual download of *kubectl* and *docker* client

* Check the latest version of [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/#install-kubectl-binary-using-curl)
* Get the docker client binary for windows from this [public github repo](https://github.com/rgl/docker-ce-windows-binaries-vagrant/releases/download/v18.06.0-ce/docker-18.06.0-ce.zip)


## The Kubernetes dashboard

Minikube includes an addon with the official k8s dashboard enabled by default. We are going to see how you can use it in practice.

* Recreate the nginx deployment

```
kubectl apply -f https://k8s.io/examples/application/deployment.yaml
kubectl expose deployment/nginx-deployment --type="NodePort" --port 80
```

* Check if the addon is enabled with `minikube addons list`
* Start the dashboard using `minikube addons open dashboard`
* Play a bit around it
* Destroy the deployment

```
kubectl delete service -l app=nginx
kubectl delete deployment nginx-deployment
```


## Using Minikube docker agent

* Install docker client (in a controlled environment you can use [this handy unofficial build](https://github.com/rgl/docker-ce-windows-binaries-vagrant/releases))
* Git-bash does some magic on paths, mostly for good. But in the case of docker mounted directories it usually breaks the implementation. So disable the trick:

```bash
# Workaround for Docker for Windows in Git Bash.
docker()
{
        (export MSYS_NO_PATHCONV=1; "docker.exe" "$@")
}
```
* **Using a bash console** type `eval $(minikube docker-env)`
* Check Minikube's containers with `docker info`
* Run an interactive ephimeral bash session with `docker run -it --rm bash`
* List docker images downloaded by Minikube typing `docker images`

