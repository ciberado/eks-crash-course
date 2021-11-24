# Pod lifecycle

*Note*: you can set your default namespace by typing `kubectl config set-context --current --namespace=<insert-namespace-name-here>`.

## Pod phases (status field)

* `Pending`: being scheduled or downloading image
* `Running`: at least one container is up
* `Suceeded`: `restartPolicy` was set to `never` or `onFailure`and all the containers have finished with a 0 code
* `Failed`: `restartPolicy` was set to `never` and at least one container existed with an error
* `Completed`: the pod was a *job* and it was successfully completed
* `CrashLoopBackOff`: repeated failure of at least one container is holding back pod recreation
* `Unknown`: something happened, smile

## Pod resiliency

* The pod `restartPolicy` is only applied at node level
* To survive node failure a controller (`job`, `resplicaset`, `deployment`...) should be used

## Playing with pod status

* Create a namespace to run the demo-$USER

```bash
kubectl create ns demo-$USER
```

* Run this poor pod and check how it goes from *ContainerCreating* to *Running* to *Error*

```bash
kubectl run run-once-and-fail \
  --image=busybox \
  --restart=Never \
  -n demo-$USER \
  -- sh -c "exit 1"

kubectl get pod run-once-and-fail \
  -n demo-$USER \
  -owide \
  --watch
```

* Press `ctrl+c` and check the resulting status of the pod (`Error`)

```bash
kubectl describe pod run-once-and-fail -n demo-$USER # (check for State section)
```

* Create a `job` instead of a simple `pod` and and check how it is being resurrected until it ends with an `exit 0`

```bash
kubectl run should-restart-on-failure-$RANDOM \
  --image=busybox \
  -n demo-$USER \
  --restart=OnFailure \
  -- sh -c "if [ "$(expr $RANDOM % 2 )" -eq "0" ] ; then exit 0; else exit 1; fi"

kubectl get pods -n demo-$USER -owide --watch
```

* Finally, create a `deployment` and see how it doesn't matter how many times the pod dies it will be scheduled again

```bash
kubectl run restart-always \
  --image=busybox \
  -n demo-$USER \
  --restart=Always \
  -- sh -c "exit 1"

kubectl get pod restart-always -n demo-$USER -owide --watch
```

* Remove the namespace

```bash
kubectl delete ns demo-$USER
```

## Playing with jobs

* Create a namespace for this lab

```bash
kubectl create ns demo-$USER
```

* A `job` uses a pod to try to complete a goal 
* A job will try to recover itself if something goes wrong

* Create a job (the key option is `restart`)

```bash
kubectl run pokemon \
  --image=ciberado/pokemon-nodejs:0.0.3 \
  --image-pull-policy=Always \
  -n demo-$USER \
  --restart=OnFailure
```

* Check the status of the job (it should be `1 Running 0 Succeded 0 Failed`)

```bash
kubectl describe job pokemon -n demo-$USER
```

* Tunnel to it's cluster IP to access the application 

```bash
PORT=$(( ( RANDOM % 100 )  + 8000 ))
kubectl port-forward  jobs/pokemon --address 0.0.0.0 -n demo-$USER $PORT:80
```

* Check its current status:

```bash
kubectl get pods -n demo-$USER
```

* From another terminal (or [tmux](http://www.sromero.org/wiki/linux/aplicaciones/tmux) session), connect to the application and emulate a crash on it:

```bash
curl localhost:$PORT/exit-ko
```

* Check how it is spawning a new pod to replace the finished one (look for the restarts column):

```
kubectl get pods -n demo-$USER --watch
```

* Finish the job gracefully:

```bash
curl localhost:$PORT/exit-ok
```

* Use `ctrl+break` to stop the port forwarding

* Check the Pod Statuses of the Job to see how it changed to `Succeded`

```bash
kubectl describe job pokemon -n demo-$USER
```

* Delete everything

```bash
kubectl delete ns demo-$USER
```