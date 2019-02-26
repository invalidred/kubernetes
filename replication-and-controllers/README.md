# Replication and Other Controllers
## Liveness Probe
Kubelet process inside a worker node can read the `livenessProbe` configuration in `.yaml` pod descriptor file to check the health state of a pod and restart the pod accordingly. There  are 3 sub configuration
- using ::HTTP GET:: to call an endpoint in the pod and see if it responds with >=200 && < 400 statusCode
- using ::TCP:: connection and if there is a successful handshake then its all good.
- using ::exec:: proc probe to execute some code inside the pod

Example of liveness probe `kubia-liveness.yaml`
```
apiVersion: v1
kind: Pod
metadata:
  name: kubia-liveness
spec:
	containers:
	- image: luksa/kubia-unhealthy
	  name: kubia
	  livenessProbe:
			httpGet:
			path: /
			port: 8080
```

To obtain crash logs 
```
# gets crash log of current pod
kubectl get my-pod

## gets crash log of previous pod
kubectl get my-pod --previous
kubectl describe po my-pod
```

### What should be part of liveness probe check
Having a `/health` check that’s just a ping back from the server is pretty good step up than not having one. This means that the server is responsive and not stuck in an infinite loop or the CPU and Memory consumption has made the app unresponsive. However a better check would be make internal status checks of all the vital components running inside the app to ensure none of them have died or are unresponsive.

Now if a downstream API/DB is down, this shouldn’t fail your `/health` check as it’s no your application fault and restarting your app will not fix the downstream API/DB.

Keep your probe light, they should take very little time to respond and have small CPU/memory consumption. Don’t create a retry loop in your code as Kubernetes will take care of it.

## Replication Controllers
It’s responsible to ensure that the specific pod count is always maintained. If a node dies or if the pod is unhealthy, then the RC will ensure the desired number of pods are spawned in a different node or the same node.

There are 3 parts to the RC
1. ::label selector:: which determines which pods are in it’s scope
2. ::replica count:: which determines the desired instances it should keep
3. ::pod template:: which is used to create pods

Changing the label selector has no impact on existing pod, however new pod will be spawned based on the new ::label selector:: which will be limited to ::replica count:: . Changing ::pod template:: will only create pods with the new template when the existing pods die.

_kubia-rc.yaml_
```
apiVersion: v1
kind: ReplicationController
metadata:
	name: kubia
spec:
	replicas: 3
	selector:
		app: kubia
	template:
		metatdata:
			labels:
				app: kubia
			spec:
				containers:
				- name: kubia
				  image: abdulask/kubia
				  ports:
				  - containerPort: 8080
```

*NOTE* the spec->selector->app: kubia if not specified will be implied from spec->template>metadata->labels->app: kubia. This is not bad since we can write terse descriptor files

```
# To create RC
kubectl create -f kubia-rc.yaml

# Delete a Pod and watch RC recreate it
kubectl delete po kubia-53thy

# To get info about RC
kubectl get rc
kubectl describe rc kubia
```

### Some other useful commands

To change the `RC` descriptor file. It will open up the default text editor, and once you save your changes, Kubernetes immediately enforces it.
`kubectl edit rc kubia`

To scale up
`kubectl scale rc kubia --replicas=10`


### Deleting RC

When you delete your RC the associated pods are also deleted, however you can keep the pods around by specifying `--cascade=false`

`kubectl delete rc kubia --cascade=false`

## ReplicaSets
These are new version of *ReplicationController*. They work exactly the same where they ensure matched resources always have the desired count. They offer a more powerful ::selectors:: to match *Pods* more flexibly. You can select Pods based on
- ::In:: Labels value must be in an array of values
- ::NotIn:: Label values must _NOT_ be in array of values
- ::Exists:: Only check if label key exists on Pod descriptor and the value is ignored
- ::DoesNotExists:: The opposite of above

```
apiVersion: apps/v1beta2
kind: ReplicaSet
metadata:
  name: kubia
spec:
  replicas: 3
  selectors:
    matchLabels:   	 #both key and value must match
      app: kubia
    matchExpression:  #key should match any of the value
      -key: app
       operator: In
       values:
         -kubia
         -kubia-v2
  spec:
    containers:
      - name: kubia
        image: abdulask/kubia
   
```
 
```
# create rs
kubectl create -f kubia-replicaset.yaml

# delete rs
kubectl delete rs kubia
```


## DaemonSets
If you wanted to run on *Pod* on each and every *Worker Node* or on every *Woker Node* that matched a ::node-selector:: to perform system level tasks such as logging or system monitoring, this can be accomplished using *DaemonSets*

```
apiVersion: app/v1beta2
kind: DaemonSet
metadata:
  name: ssd-monitor
spec:
  selector:
    matchLabels:
      app: ssd-monitor
  template:
    metadata:
      labels:
        app: ssd-monitor
    spec:
      nodeSelector: # select nodes with disk=ssd label
        disk: ssd
      containers:
        - name: main
          image: luksa/ssd-monitor
```


```
k create -f ssd-monitor-daemonset.yaml

# get daemonSet
k get ds
 
# get all pods, however no ssd-monitor pod why?
k get po

# add label to a node for ssd-monitor to work
k label node <node-id> disk=ssd

# delete ds
k delete ds <ds-name>
```

## Jobs and CronJob Resources
*Job* Resource is responsible to run a container through completion and not re-spawn it again. *CronJob* runs a container at a later date and can periodically spawn the container based on _cron_ setting.

You can run pods sequentially run pods using ::spec.completions:: config and you can run pods in parallel using ::spec.parallelism:: config.

```
apiVersion: batch/v1
kind: Job
metadata:
  name: batch-job
spec:
  template:
    metadata:
      labels:
        app: batch-job
    spec:
      restartPolicy: OnFailure #Jobs can use the default restart poliy which is Always
      containers:
      - name: main
        image: luksa/batch-job
```


To run multi pods in parallel
```
apiVersion: batch/v1
kind: Job
metadata:
  name: multi-completion-batch-job
spec:
  completions: 5 # ensure 5 pods complete successfully
  parallelism: 2 # upto 2 pods can run in parallel
  template:
    <same template as above>
```

In the pod’s spec ::activeDeadlineSeconds:: property will limit the number of time the pod can run and will be terminated.

### CronJob
```
apiVersion: batch/v1beta1
kind: CronJob
metadata:
  name: batch-job-every-fifteen-minutes
spec:
  schedule: "0,15,30,45 * * *"
  jobTemplate:
    spec:
      template:
        metadata:
          labels:
            app: periodic-batch-job
        spec:
          restartPolicy: OnFailure
          containers:
          - name: main
            image: luksa/batch-job
```

