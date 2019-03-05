# Volumes: disk storage to containers

Volumes are part of a pod's specification and are not standalone kubernetes objects that can be created or deleted on their own. 

## Available volume types
- _emptyDir_ A simple empty dir in the *Pod* to store transient data
- _hostPath_ Used for mounting directories from the worker nodes filesystem into the pod
- _gitRepo_ A volume initialized by checkout out the contents of a Git repo
- _nfs_ An NFS share mounted into the pod
- _gcePersistentDisk_ _awsElesticBlockStore_ _azureDisk_ to mount cloud provider specific storage
- _configMap_ _secret_ _downwardAPI_ special types of volumes used to expose certain Kubernetes resources and cluster info to pod
- _persistentVolumeClaim_ a way to provision a pre- or dynamically provisioned storage

## Using Volumes to Share Data between Containers

This can be done using _emptyDir_ or _gitRepo_

### EmptyDir
It’s an easy way to share file between containers within the same Pod. It’s only lasts as long as the Pod lasts and is cleared when the Pod is deleted. You can specify it in the `spec.containers.volumeMounts`  and `spec.volumes` section

```
apiVersion: v1
kind: Pod
metadata:
  name: fortune
spec:
  containers:
  - image: abdulask/fortune
    name: html-generator
  - image: nginx:alphine
    name: web-server
    volumeMounts:
    - name: html
      mountPath: /usr/share/nginx/html
      readOnly: true
    ports:
    - containerPort: 80
      protocol: TCP
  volumes:
  - name: html
    emptyDir: {}
```

### Git volume

You can use _gitRepo_ volume type to load a git repo mounted as an emptyDir volume before a container's execution begins.

check the `gitrepo-volume-pod.yaml` for an example of how to set this up.

You can also keep files in sync whenever code is updated in a `git` repo. This can be accomplished using a `side-car` container. A side-car container augments or assists the main containers. For example the main container could be `nginx` web server that serves static html|cc|js files. The `side-car` container could be an image that monitors changes to a git repo and write the changes a volume that the main container (nginx) serves.

check the `gitrepo-volume-sync-pod.yaml` for an example of how to set this up.

## Accessing files on worker node's filesystem
For most _Pods_ should be oblivious of their host node and shoul not access any files on host nodes. However system level _Pods_ do care about the hosts file system to say access logs. This can be done through _hostPath_ volume

### HostPath volume
The volume is located in the worker node. Thus the data stored in it should last longer than _emptyDir_ or _gitRepo_ volumes types which are bound to a _Pods_ lifecycle. 
Remember _hostPath_ volumes only read/write system files on the node. Never use them to persist data across pods.

To see _hostPath_ volume in action you can get `fluentd-<podid>` pods

```
# list kube-system flentd pods
kubectl get pod s --namespace kube-system

# descibe the pod from above
kubectl describe po fluentd-kubia-4ebcdfds-9sdf9 --namespace kube-system

# you should see
Volumes:
  varlog:
    Type: HostPath
    Path: /var/log
  varlibdockercontainers:
    Type: HostPath
    Path: /var/lib/docker/containers
```

## Using Persistent Disk
If a pod needs to connect to external storage that's outside the Pod/WorkerNode then use Persistent Disk mode. Kubernetes supports a wide varities of store options. You can choose to connect directly to cloud storage from amazon, microsoft, google etc... Also you can connect using storage protocols such as nfs, rdb, flocker, flexVolume etc...

Lets create _gcpPersistentDisk_.

```
# find out which region your cluster belongs to
gcloud container clusters list

# create a google persistent disk in that region
gcloud compute disk create --size=1GiB --zone=northamerica-northeast1-a mongodb

# create the pod using the `mongodb-pod-gcepd.yaml` file
kubectl create -f mongodb-pod-gcepd.yaml

# enter mongo shell
kubectl exec -it mongodb mongo

# create a document
> use mystore
> db.foo.insert({ name: 'foo' })
> db.foo.find()

# kill the pod
kubectl delete pod mongodb

# Recreate a new pod and verify document still exists
kubectle create -f mongodb-pod-gcepd.yaml
kubectl exec -it mongdb mongo
> use mystore
> db.foo.find()
```

## Decoupling pods from underlying Storage Tech
The point of Kubernetes is to make it easy for Developer to not care of infrastructure specific. For example when creating a _gcpPersistentDisk_ in section above, you need to know cloud storage specific details. Kubenetes can decouple the Storage Tech such that as a Dev you don't need to know the storage tech nor care about it. All you care about is, I want 100GB of storage with _ReadWrite_ access from a single or multi _Pods_. This is possible through **PersistentVolumes** and **PersistentVolumeClaims**

### Intro to PersistentVolumes & PersistentVolumeClaims
Here is a rough idea of how it works

1. Sys Admin setups some type of network storage (NFS export or similar). 
2. Sys Admin then crates a _PersistentVolume_(PV) by posting a descriptor to Kubernetes API. 
3. Dev then creates a _PersistentVolumeClaim_(PVC). 
4. Kubernetes Finds a _PV_ of adequate size and access mode and bind the PVC to PV. 
5. Dev creates a pod with a voume referencing the PVC


```
# Create PersistentVolume. Look at `mongodb-pv-gcepd.yaml`
kubectl create -f mongodb-pv-gcepd.yaml

# Check if PV is created
kubectl get pv

# Create PersistentVolumeClaim. Look at `mongodb-pvc.yaml`
kubectl create -f mongodb-pvc.yaml

# Check if PVC is created
kubectl get pvc

# Use PersistentVolume in Pod. Look at `mongodb-pod-pvc.yaml`
kubectl create -f mongodb-pod-pvc.yaml

# verify setup is working
kubectl exec -it mongodb mongo
> use mystore
> db.foo.find()
``` 

## Dynamic provisioning of PersistentVolumes
Creating a _PersistentVolume_ requires a sys admin to provision some storage before it can be claimed using _PersistenVolumeClaim_. However Kubernetes can to the provisioning of volume automatically. The sys admin instead of creating a _PersistentVolume_ can deploy a PersistentVolume Provisioner and define one of more _StorageClass_ object to let users choose the type of _PersistenVolume_ they want. The use can then choose the _StorageClass_ in theier _PersistentVolumeClaim_ and the provisioner will take into account when provisioning the persistent storage.

```
# create StorageClass definition. Check `storageclass-fast-gcepd.yaml`
kubectl create -f storageclass-fast-gcepd.yaml

# request a StorageClass in _PVC_. Check `mongodb-pvc-dp.yaml`
kubectl create -f mongodb-pvc-dp.yaml

# check _PVC_ and dynamically provisioned _PV_
kubectl get pv

# check all disk on the cluster
gcloud compute disks list

# get a list of all StorageClass available
kubectl get sc

# view defintion of default Standard StorageClass on GKE
kubectl get sc standard -o yaml

# create a _PVC_ without specifying a storage class. Check `mongodb-pvc-dp-nostorageclass.yaml`
# Note the standard StorageClass will be used by default (unless default is set to another StorageClass)
kubectl create -f mongodb-pvc-dp-nostorageclass.yaml
```


