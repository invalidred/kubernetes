# Pods
## Explain command
To explain how to create ::yaml:: file use the `explain` command

`kubectl explain pods`
`kubectl explain pods.spec`

## Create Pod from .yaml
`kubectl create -f kubia-manual.yaml`

To get yaml of existing pod
`kubectl get po kubia-manual -o yaml`

## See Logs of a Pod
The easy way, use Kubernetes. Logs of containerized apps are written to standard output and standard error stream. They are rotated every day or upto 10MB limit
`kubectl logs kubia-manual`

For pods with multi containers use `-c` to specify which container
`kubectl logs kubia-manual -c kubia`

You can also ssh into the pod and use `Docker` to see logs
`docker logs <container id>`

## Sending requests to a Pod
### Forwarding a local network port to a port in the pod
The following forwards request from local port 8888 to pods port 8888
`kubectl port-forward kubia-manual 8888:8080`

[image:9EA3AC9A-0DC8-4FC7-B7EB-E69CFD12361C-814-0001A4F88457C9D8/Screen Shot 2019-01-23 at 7.48.20 PM.png]

## Organize Pods through ::Labels::
::Labels:: help organize not only pods, but all other Kubernetes resources.  You can attach multiple labels to a resource.

[image:A367F253-A6E9-4149-85A6-7B92DB6E0B22-814-0001CC9A277AB36B/Screen Shot 2019-01-24 at 7.41.38 PM.png]

Using `app` and `rel` label you convert the pile-o-mess to something clear
- `app` can be the name of the app, Microservice or component the pod belongs to
- `rel` shows whether the app running in the pod is stable, beta or canary.

[image:F68A603C-7526-4B7A-B236-BF76FA44001D-814-0001CCBA308B81E8/Screen Shot 2019-01-24 at 7.43.56 PM.png]

Specify labels  in metadata->labels section
::kubia-manual-with-labels.yaml::
```
apiVersion: v1
kind: Pod
metadata:
  name: kubia-manual-v2
  labels:
    creation_method: manual          
    env: prod                        
spec:
  containers:
  - image: abdulask/kubia
    name: kubia
    ports:
    - containerPort: 8080
      protocol: TCP
```

::--show-labels switch::
```
k create -f kubia-manual-with-labels.yaml
k get po --show-labels
```

To add label to existing pod
`k label po kubia-manual creation_method=manual`

To overwrite existing label
`k label po kubia-manual-v2 env=debug --overwrite`

To show labels in List view
`k get po -L env,creation_method`

### Label Selector

to select pod by key=value or key!=value
`k get po -l creation_method=manual`
`k get po -l creation_method!=manual`

to select pod by key or values in key
`k get po -l env`
`k get po -l 'env in (prod,devel)'`

To select where pod NOT have key
`k get po -l  '!env'`

To have multiple selectors
`k get po -l  'app=pc,rel=beta'`

### Using Label Selectors to categorize worker nodes
The idea is to label nodes with special capabilities such as `GPU` for nodes that have stronger GPU cards. Then you can schedule pods to specific nodes by using `nodeSelector` in `.yaml` pod descriptor which will point to the labels assigned to the worker nodes such as `GPU` in this case.

Labels a worker node with gpu=true
`k label node gke-kubia-default-pool-274fb46e-2t2p gpu=true`

Using label selectors to find nodes with a label
`k get nodes -l gpu=true`

`k get nodes -L gpu`

### Scheduling pod to specific node

Notice the `nodeSelector`

```
apiVersion: v1
kind: Pod
metadata:
  name: kubia-gpu
spec:
  nodeSelector:               1
    gpu: "true"               1
  containers:
  - image: luksa/kubia
    name: kubia
```

## Annotations
You can add annotations to pod and store large key/value info to the pod (256KB). They are similar to labels, where you can assign key/values pairs, however labels are used to identify pods based on some classification such as environment, or product it belongs to. You can use label selectors to find your pod, however there is no such thing as annotation selector. The point is to just meta storage for pod. Such as who is the owner of the pod, or some pod specific data. Kubernetes alpha and beta versions use `annotations` to store app specific data that is not part of the App descriptor file yet.

```
# annotate pod
kubectl annotate pod kubia-manual mycompany.com/someannotation="foo bar"

# to see annotation
kubectl describe pod kubia-manual
```

## Namespaces
Allow resources such as pods can be grouped based on namespace. They are different from labels in that when you assign a resource to a namespace and when you switch your context to that namespace commands only apply to resources within that namespace. For example if you have ::pod A:: assigned to `custom-ns` namespace, if you current context’s namespace is `customer-ns` then `k get po` will show ::pod A::. However if you current context namespace is `default` then `k get po` will not show ::pod A:: Namespace is a way to work on a collection of resources tied to that namespace which is based on the context your namespace is in.

```
# to get all namespaces
kubectl get ns

# to get all pods that belong to kube-system namespace
kubectl get po -n kubia-system
```

### Creating a namespace
You can create `namespace` using a .yaml descriptor file or using command line

```
apiVersion: v1
kind: Namespace
metadata: 
  name: custom-namespace
```

```
# create custom-namespace through command line
kubectl create namespace custom-namespace

# to create a pod with descriptor yaml and namespace -n
kubectl create -f kubia-manual.yaml -n custom-namespace
```

### Isolation provided by Namespace
Namespaces do not prevent pods in different namespaces from talking with each other. It can be isolated at networking level, but that’s dependent on which networking solution is deployed with Kubernetes

## Delete Pods
```
# to delete specific pod
kubectl delete pod kubia-manual

# to delete a pod based on label selector
kubectl delete po -l creation_method=manual

# to delete a namespace and all pods associated with it
kubectl delete ns custom-namespace

# deleting all pods in namespace, while keeping the ns
kubectl delete po --all

# deleting all resources in a namespace
kubectl delete all --all
```



