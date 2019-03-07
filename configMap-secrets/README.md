# ConfigMaps & Secrets
This section covers 
1. Passing parameters to containers through descriptor `.yaml` files.
2. Setting environment variables for each container
3. Mounting configuration into containers through ConfigMaps and/or Secrets

## Passing Command Line Args to Containers
You can pass command line args in Docker through `CMD` command like so

```fortune-args/Dockerfile
FROM ubuntu:latest
RUN apt-get update ; apt-get -y install fortune
ADD fortuneloop.sh /bin/fortuneloop.sh
ENTRYPOINT ["/bin/fortuneloop.sh"]
CMD ["10"]
```

The `CMD` from above will be passed as the first command line arg to `fortuneloop.sh` script as `$1` var

```fortuneloop.sh
#!/bin/bash
trap "exit" SIGINT
INTERVAL=$1
echo Configured to generate new forutune every $INTERVAL seconds
mkdir -p /var/htdocs
while :
do
  echo $(date) Writing fortune every $INTERVAL seconds
  /usr/games/fortunes > /var/htdocs/index.html
  sleep $INTERVAL
done
```

To override the `ENTRYPOINT` and `CMD` Dockerfile instruction through kubernetes you can use `command` and `args` respectively.

```fortune-pod-args.yaml
apiVersion: v1
kind: Pod
metadata:
  name: fortune2s
spec:
  containers:
  - image: abdulask/fortune:args
    args: ["2"]  # note 2 will override 10 set by `CMD` in Dockerfile
    name: html-generator
    volumeMounts:
    - name: html
      mountPath: /var/htdocs
...
```

|Docker|Kubernetes|Description|
|------|----------|-----------|
|ENTRYPOINT|command|The executable that's executed inside the container|
|CMD|args|The arguments passed to the executable|

## Setting environment varibale for a Container
You can set an environment variable by seting `spec.containers[n].env{name,value}` config
_fortune-pod-env.yaml_
```.yaml
kind: Pod
spec:
  containers:
  - image: luksa/fortune:env
    env:
    - name: INTERVAL
      value: "30"
    name: html-generator
```

Now you can access the environment variable in `.sh` file directly accessing `$INTERVAL` variable.
In _Node.js_ you can use `process.env.INTERVAL` variable.

You can also refer to other environment variables in a variable's value

```
env:
- name: FIRST_VAR
  value: "foo"
- name: SECOND_VAR
  value: "$(FIRST_VAR)"
```

NOTE: using environment variables or command line args have a limitation where you need to maintain multiple descriptor files with hardcoded environment config. This can be avoided throught _ConfigMaps_

## ConfigMaps: decouple config from pod descriptors
_ConfigMaps_ is a kubernetes Object to store configuration data that can be then fed to a container as environment variable or as a attached volume. Then based on the namespace (prod|staging etc..) the pod is running, an appropriate _ConfigMap_ will be loaded.

### Creating a ConfigMap

```
# creates a configMap with with a single literal using `from-literal`
kubectl create configmap fortune-config --from-literal=sleep-interval=25

```

You can also do the same ^^ using `.yaml` descriptor

```.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: fortune-config
data:
 sleep-interval: "25"
```

You can create config map from contents of a file
```
kubectl create configmap my-config --from-file=config-file.yaml

#To store the contents of the file under a seperate key
kubectl create configmap my-config --from-file=customkey=config-file.conf

# To import all files from a folder. Will create map entry for each file in folder
kubectl create configmap my-config --from-file=/path/to/dir

# Combining differnt options
kubectl create configmap my-config
  --from-file=foo.json
  --from-file=bar=foobar.conf
  --from-file=config-opts/
  --from-literal=some=thing
```

### Passing ConfigMap entry to Container as env var
You do so using `valueFrom` feild in descriptor file
```.yaml
apiVersion: v1
kind: Pod
metadata:
  name: fortune-env-from-configmap
spec:
  containers:
  - image: luksa/fortune:env
    env:
    - name INTERVAL
      valueFrom:
        configrMapKeyRef:
          name: fortune-config
          key: sleep-interval
```

You can also pass all entries from configMap as environemnt variables
```.yaml
spec:
  containers:
  - image: some-image
    envFrom:
    - prefix: CONFIG_
      configMapRef:
        name: my-config-map
```

### Passing ConfigMap entry as command-line argument
```
apiVersion: v1
kind: Pod
metadata:
  name: fortune-args-from-configmap
spec:
  contaienrs:
  - image: luksa/fortune:args
    env:
    - name: INTERVAL
      valueFrom:
        configMapKeyRef:
          name: fortune-config
          key: sleep-interval
    args: ["$(INTERVAL)"]
```

### Using ConfigMap volume to expose ConfigMap entries as files
```
# first create configMap with contents of a folder
kubectl create configmap fortune-config --from-file=configmap-files

# check the contents of the configmap
kubectl get configmap fortune-config -o yaml
```

Then mount the configmap as volume in Pod

```fortune-pod-configmap-volume.yaml
apiVersion: v1
kind: Pod
metadata:
  name: fortune-configmap-volume
spec:
  containers:
  - image: nginx:alphine
    name: web-server
    volumeMounts:
    ...
    - name: config
      mountPath: /etc/nginx/conf.d
      readOnly: true
    ...
  volumes:
  ...
  - name: config
    configMap:
      name: fortune-config
```

### Updating an app's config without having to restart the app
The biggest benefit of using volume mounted ConfigMap is that when the confimap is updated all the pods with volumes refering that configmap also get updated. This is not the case with environment variables nor command line arguments.

```
# to edit a configmap
kubectl edit configmap fortune-config

```
