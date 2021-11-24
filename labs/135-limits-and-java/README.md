# K8s limits with legacy programs

* Not all programs are aware of the limits impossed by c-groups
* A program trying to allocate more memory than allowed will be terminated
* Check [java-docker-cgroups/entrypoint.sh](https://github.com/ciberado/java-docker-cgroups/blob/master/entrypoint.sh) to see how a relatively old version of the JVM can be started with or without c-groups options

```bash
#!/bin/sh
test "$1" = "-x" && {
	echo "Enable experimental vm options"
	export JAVA_OPTS="-XX:+UnlockExperimentalVMOptions -XX:+UseCGroupMemoryLimitForHeap -XX:MaxRAMFraction=1 -XX:+UseG1GC"
}
java $JAVA_OPTS Main
```

* Run a pod without those options to see how Kubernetes kills the process:

```bash
kubectl run j1 --image=ciberado/java-docker-cgroups --limits=cpu=200m,memory=100Mi -it --restart=Never
```

* Run the same image again but including the `-x` option to activate the c-groups awareness and compare both outputs (Killed vs `java.lang.OutOfMemoryError`)

```bash
kubectl run j2 --image=ciberado/java-docker-cgroups --limits=cpu=200m,memory=100Mi -it --restart=Never -- -x
```

## Cleanup

* Delete the created resources

```bash
kubectl delete pods j1 j2
```