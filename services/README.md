# Chapter 5: Services

## Creating Service Through YAML Descriptor
_kubia-svc.yaml_
```
apiVersion: v1
kind: Service
metadata:
  name: kubia
spec:
  ports:
  - port: 80
    targetPort: 8080
  - port: 443:
    targetPort: 8443
  selector:
    app: kubia
```

Or you can refer to named ports
_kubia-svc-name-port.yaml_
```
spec:
  ports:
  - port: 80
    targetPort: http
```

_kubia-pod.yaml_
```
kind: Pod
spec:
  containers:
  - name: kubia
    ports:
    - name: http
      containerPort: 8080
```

### Remotely executing commands in running containers

Use `kubectl exec` commands to run commands in existing containers.  It will spawn another process in the container the will perform the command in the container and standard out the result back to your terminal

```
kubectl exec <container-id> -- curl -s http://10.111.249.153
```

### sessionAffinity

Use `sessionAffinity: ClintIP` to create a sticky connection such that a client request is always routed to the same ::Pod:: that first handled the request.

### Discovering Services

It can be discovered through `env` variables injected by Kubernetes in the Pod’s container. Note all the services in cluster will have their IPs injected through environment variables

`kubectl exec kubia-3inly env`

```
KUBIA_SERVICE_HOST=10.111.249.153
KUBIA_SERVICE_PORT=80
```

You can also call a service through Fully Qualified Domain Name `FQDN` by calling `kubia.default.svc.cluster.local` but Kubernetes does some tricks by updating the `/etc/resolv.conf` file by including
`default.svc.cluster.local svc.cluster.local cluster.local`. Thus you can just use `kubia`

```
kubectl exec kubia-3inly bash

root@kubia-3inly:/# curl http://kubia.default.svc.cluster.local
root@kubia-3inly:/# curl http://kubia.default
root@kubia-3inly:/# curl http://kubia
```


## Connecting to Service living outside the cluster

### Service Endpoints

::Endpoints:: is resource in a ::Service:: objects and it’s the object that helps ::Service:: determine which ip’s it needs to redirect to 

```
kubectl describe svc kubia

outputs:
Name: Kubia
Namespace: default
Selector: app=kubia
IP: 10.111.249.153
Endpoints: 10.108.1.4:8080, 10.108.2.5:8080, 10.108.2.6:8080

# To get endpoints
kubectl get endpoints kubia

output:
NAME      ENDPOINTS                                        AGE
kubia     10.28.1.26:8080,10.28.1.27:8080,10.28.1.28:8080  30m
```


If you want Pods to connect to External Service, this can be done by Creating a ::Service:: resource without a selector and by creating an ::Endpoint:: resource which the same service name and the IP/Domain of the External service. Then Pods can send requests to this ::Service:: by using `FQDN`

_external-service.yaml_
```
apiVersion: v1
king: Service
metadata:
  name: external-service
spec:
  ports:
  - port: 80
```

_externa-service-endpoints.yaml_
```
apiVersion: v1
kind: Endpoints
metadata:
  name: external-service
subsets:
  - addresses:
    - ip: 11.11.11.11
    - ip: 22.22.22.22
    ports:
    - port: 80
```

Requests to `external-service` will be load-balanced between service endpoints. To call an external service name use the `ExternalName` type as shown below

```
apiVersion: v1
kind: Service
metadata:
  name: external-service
spec:
  type: ExternalName
  externalName: somapi.somecompany.com
  ports:
  - port: 80
```


## Exposing Services To External Clients

There are 3 ways to expose service to external clients
- _NodePort_ a ::Service:: where a port is created on all worker nodes that contain the ::Pod:: the client wants to connect to, the client first connects to a the port on the worker node which redirects the traffic to the underlying ::Service:: which then re-directs the traffic to one of the ::Pods::
- _LoadBalancer_ ::Service:: builds on top of _NodePort_ and makes the service available through a load balancer provided by the Cloud Provider. The client connects through the _Load Balancer_  IP.
- _Ingress_ ::Service:: allows for multiplexing of multiple services over a single IP through host headers or url segmentation.

### NodePort Service

_kubia-svc-nodeport.yaml_
```
apiVersion: v1
kind: Service
metadata:
  name: kubia-nodeport
spec:
  type: NodePort
  ports:
  - port: 80
    targertPort: 8080
    nodePort: 30123
  selector:
    app: kubia
```

To access the service you need to add a firewall rule to allow traffic to port 30123 in all nodes in the cluster

```
gcloud compute firewall-rules create kubia-svc-rule --allow-tcp:30123
```

[image:01FB3F24-DA44-485D-A314-DA4A092A262F-41657-000592CF9EC79300/Screen Shot 2019-02-13 at 8.44.58 PM.png]

And now the service should be accessible through 
- CLUSTER_IP_OF_SERVER:80
- <1st node’s IP>:30123
- <2nd node’s IP>:30123, etc…

Handy trick to get IPs of all your nodes using _JSONPath_
```
k get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="ExternalIP")].address}'

```

### LoadBalancer Service

It will use the cloud providers LoadBalancer and provide a public IP clients can connect to that will be re-direct to the Service that will redirect the request to a pod

```
apiVersion: v1
kind: Service
metadata:
  name: kubia-loadbalancer
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 8080
  selector:
    app: kubia
```

Then to get the public ip 

`kubectl get sac kubia-loadbalancer`


### Creating an Ingress Resource

```
apiVersion: v1
kind: Ingress
metadata:
  name: kubia
spec:
  rules:
  - host: kubia.example.com
    http:
      paths:
      - path: /kubia
        backend:
          serviceName: kubia
          servicePort: 80
      - path: /bar
        backend:
          serviceName: bar
          servicePort: 80
  - host: foo.example.com
    http:
      paths:
      - path: /
        backend:
          serviceName: foo
[Chapter 5: Services](bear://x-callback-url/open-note?id=F7F4C743-500B-405A-B59E-2D8CA13B8118-41657-0005340331292E10)          servicePort: 80
```

The _yaml_ descriptor file accepts hosts array and paths array to enable different services back different hosts and paths.

You can also terminate  `tls|https` traffic at for that read up section `5.4.4 Configuring Ingress to handle TLS traffic` section of the book.


## Readiness Probes
Since it may take some time for  Pods to boot up and accept traffic, this is where Readiness Probes can be defined in ReplicationController or ReplicationSet descriptor _yaml_ files. These are different from ::Liveness Probes:: in that they do not kill a pod when ::Readiness Probe:: fails, rather it keep the pod as is, just does not sends traffic to it. There are 3 types of readiness probes

- _exec_ probe executes a command and a non 0 status code means pod is not ready
- _HTTP GET_ probe sends a _GET_ request and the statusCode determines if probe is ready or not
- _TCP Socker_ probes tries to connect to specific port and if connection is established then the Pods is considered ready.

```
# edit existing rs kubia
kubectl edit rc kubia

# modifications needs to descriptor file
apiVersion: v1
kind: ReplicationSet
...
spec:
  ...
  template:
    ...
    spec:
      containers:
      - name: kubia
      image: abdulask/kubia
      readinessProbe:
        exec:
        - ls
        - /var/ready
```

## Using headless service for discovering individual pods

When you create a service you get a single static IP that when called will route the request to one of the backing pods. But the you wanted the IPs for all the backing Pods so they can take to each other, or something to talk to all of them at once. This is where a ::headless:: service comes in. When you specify *clusterIP: None* then doing a DNS lookup with yield multiple A records of each backing Pod IP. 

_kubia-svc-headless.yaml_
```
apiVersion: v1
kind: Service
metadata:
  name: kubia-headless
spec:
  clusterIP: None   # This makes a service headless
  ports:
  - port: 80
    targetPort: 8080
  selector:
    app: kubia
```


### Running a Pod without a YAML Manifest

This is a neat trick to create a pod on demand, in this case a pod that’s based of a docker Image that has the ability to do dns lookup. Then you can `kubectl exec <pod_id> nslookup kubia-headless` to get all backing pod IPs.

```
kubectl run dnsutils --image=tutum/dnsutils --generator=run-pod/v1 --command -- sleep infinity
```



