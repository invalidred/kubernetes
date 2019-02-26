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

## EmptyDir
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
