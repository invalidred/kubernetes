# First Steps Docker

## Sample  `Dockerfile`

```
FROM node:10
ADD app.js /app.js
ENTRYPOINT ["node", "app.js"]
```

## Helpful commands
```
# build an image from Dockerfile
docker build -t kubia .

# run kubia image in container named kubia-container in detached mode mapping external port 8080 to internal port 8080
docker run --name kubia-container -p 8080:8080 -d kubia

# To list all running containers
docker ps

# To inspect a running container
docker inspect kubia-container

# to connect to a container
docker exec -it kubia-container bash

# to exit bash
exit

### to stop a running container
docker stop kubia-container

# to start a contaier
docker start kubia-container

# to remove a container
docker rm kubia-container

# to see downloaded images
docker images | head

# push image you need to tag with dockerId
docker tag kubia abdulask/kubia
docker push abdulask/kubia
```


# First Steps Kubernetes

Install minikube [GitHub - kubernetes/minikube: Run Kubernetes locally](https://github.com/kubernetes/minikube)

### To start a cluster
`minikube start`

### To get cluster info
`kubectl cluster-info`

To deploy your app on cluster
`kubectl run kubia --image=abdulask/kubia --port=8080 --generator=run/v1`


## Pods
A group of one or more tightly related containers that will always run together on the same worker node and in the same Linux namespace(s) is called a `Pod`. Each pod is like a separate logical machine with its own IP, hostname, processes and so on, running a single application. The application can ba single process, running in a single container, or it can be a main application process and additional supporting processes, each running in its own container. All the containers in a pod will appear to be running on the same logical machine, whereas containers in other pods, even if they’re running on the same worker node, will appear to be running on a different one. 

[image:FA6BBC67-0501-44C5-ABD2-16064E9C201C-814-00010A0978E293E1/Screen Shot 2019-01-20 at 8.41.26 AM.png]


To describe  pod
`kubectl describe pod`
`kubectl describe pod kubia-stl9x`

To get pod
`kubectl get pods`

### Scheduling a Pod
The term scheduling means assigning the pod to a node. The pod is run immediately, not at a time in the future as the term might lead you to believe.

## ReplicationController
It makes sure there exactly one instance of your pod running. In our case we didn’t specify how many pods replicas we want so only one is created, however you can specify more than one. If your pod disappears for any reason the ReplicationController would replace the missing one

to increase replica count of your pod
`kubectl scale rc kubia --replicas=3`

## Service
Pods are ephemera, they may disappear at any time as the node it’s running on has failed, or someone deleted a pod or it was evicted from an otherwise healthy node. This cause RC to replace it with a new one. This new pod gets a different IP from the pod it’s replacing. 

When a service is created it gets a static IP which is never changes. Clients should connect to the Pod via a service. A service will ensure the Pod receive the connection, regardless of where the pod is running.

Service represents a static location for a group of one or more pods that all provide the same service. Requests coming to the IP and port of the service will be forwarded to the IP and port of one of the pods belonging to the service at that moment.


### Service Object to expose pod

To create the service, you’ll tell Kubernetes to expose the ReplicationController you created earlier:

`kubectl expose rc kubia --type=LoadBalancer --name kubia-http`

### Use abbreviation in cli 
rc - replicationcontroller
po - pods
svc - services

## Kubernetes Dashboard
To get username and password
`gcloud container clusters describe kubia --zone=northamerica-northeast1-a | grep -E "(username|password):"`

TODO need to get UI Dashboard working

Follow [Creating sample user · kubernetes/dashboard Wiki · GitHub](https://github.com/kubernetes/dashboard/wiki/Creating-sample-user)
[Web UI (Dashboard) - Kubernetes](https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/)




#kb/books/kubernetes_in_action/Chapter_2
