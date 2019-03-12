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

## Using Secrets to Pass sensitive data to containers

Secrets are similar to configmap in that they are keyValue data store. They can be loaded as env vars or mounted as volumes.
Kubernetes ensures you data is safe by passing the secrets to workers nodes with pods that actually require them. The data is always encrypted and stored in memory and never written to disk. 
Use _configmap_ to store non-sensitive plain configuration data.
Use _secret_ to store sensitive data. If config file inclues both sensistive and non-sensitive data then use _secret_

### Default token Secret
Every Pod has a default _secret_ mounted in `/var/run/secrets/kubernetes.io/serviceaccount` path. It contains certs and token which can be used by a pod to communicated to the `Kubenetes API` server if needed.

```
# To see default secret
kubectl get secrets

# check the ca.cert, namespace & token
kubectl describe secrets

# To see pods volumeMount with default secret
kubectl exec <pod> ls /var/run/secrets/kubernetes.io/serviceaccount/
```

### Creating a Secret
```
# Lets make nginx get HTTPS traffic by creating key and cert
openssl genrsa -out https.key 2048 # outputs https.key
openssl req -new -x509 -key https.key -out https.cert -days 3650 -subj /CN=www.kubia-example.com # outputs https.cert
echo bar > foo

# create a secret
kubectl create secret generic fortune-https --from-file=https.key --from-file=https.cert --from-file=foo

# This is the output of fortune-https secret
kubectl get secret fortune-https -o yaml

apiVersion: v1
data:
  foo: YmFyCg==
  https.cert: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURJVENDQWdtZ0F3SUJBZ0lVQ0ZoRFNrc09hMGUvSms2UVlXMUxQUXNoN0JNd0RRWUpLb1pJaHZjTkFRRUwKQlFBd0lERWVNQndHQTFVRUF3d1ZkM2QzTG10MVltbGhMV1Y0WVcxd2JHVXVZMjl0TUI0WERURTVNRE14TURJdwpNVFF6TmxvWERUSTVNRE13TnpJd01UUXpObG93SURFZU1Cd0dBMVVFQXd3VmQzZDNMbXQxWW1saExXVjRZVzF3CmJHVXVZMjl0TUlJQklqQU5CZ2txaGtpRzl3MEJBUUVGQUFPQ0FROEFNSUlCQ2dLQ0FRRUF1ei95WUt3R2Vsa0MKR2lldXAwZ2xSTmtta01Kb0JxTmRSNzJQTnQzSmZtWW14dDJpTFFnSHNLcjE1aHdTbDBxQjVISS84aEFNQU85UgpvY25CMW9iTWl0SkJhb3JzU0FzYkxFMXVMbnVFdEl3SHF4MWwrSnNSN0huNFhBcWgwRHo2Ri9MK3RqendWbmpTCkZZWURzY0ttdU9aUFNXNjBNaEV4SzJiT3N2cGJMdW03dXVhT3FqczBKTXpNSk56M0xPM0NXWlNOZmMyRHlLL1oKbzAyMGJPNDBmWElMd3FZWWFOcFYwVWR5cG9OeGFaZGtPWU4zdGNjUWhtTS8vSGFEU05GTzNmOE1jQUh3eEdrdwo2NGQvOFNvRElkZGVocHA0cTloeVhmOXlJVElrS0FHcEZabmR0Z2Z4b1BhWGlVQVlaakhYenBzU09MdmRwVURUCkIwM2dFQXRSRndJREFRQUJvMU13VVRBZEJnTlZIUTRFRmdRVTJXMUxqNWU3cS9NMFpDN05lcVBqVTR4bCtPc3cKSHdZRFZSMGpCQmd3Rm9BVTJXMUxqNWU3cS9NMFpDN05lcVBqVTR4bCtPc3dEd1lEVlIwVEFRSC9CQVV3QXdFQgovekFOQmdrcWhraUc5dzBCQVFzRkFBT0NBUUVBUldRRUxOWjBrOUtCbkt0dmU3dHBoUm9mU1oxSUh0Vi9BNklzClJjbVo1UVJFekJQL1dxQTYyVElwYkFVZGRRNjlZSUM5ZWRBd1M4a25ETENNb1gxbDh5NDVFcUZCbTJkd3FFeDYKN0FkWisxNjZXUDhvWUpncTBjS1pMVmlaRjAvSmNiWnJnZmlvVk5ER0Q3am50am5CTzBmZWpkRERtMFFOQy9jNgpkSitLVEhvdE41bkNoSWpnc0xaTWhmU0JIVzhvTk4waG1aV2FlQW1La1lLc0hGWTVMZC9TcmI1MGpsODdRN1YxCnF5d2VyR0F5T0lPd0VGS250VTJXWmN3RitROHQ5NTJPKzU5WTNwWXpZcjlsYi9TaDhUMTNNVVI0VkNKODJleVcKWFRad0JOT0U5RGVQRTJKcG1OMEYzRUdTUXprbzNQMEk1TFpXUFU0bzIzTWhiK2U1MFE9PQotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg==
  https.key: LS0tLS1CRUdJTiBSU0EgUFJJVkFURSBLRVktLS0tLQpNSUlFb3dJQkFBS0NBUUVBdXoveVlLd0dlbGtDR2lldXAwZ2xSTmtta01Kb0JxTmRSNzJQTnQzSmZtWW14dDJpCkxRZ0hzS3IxNWh3U2wwcUI1SEkvOGhBTUFPOVJvY25CMW9iTWl0SkJhb3JzU0FzYkxFMXVMbnVFdEl3SHF4MWwKK0pzUjdIbjRYQXFoMER6NkYvTCt0anp3Vm5qU0ZZWURzY0ttdU9aUFNXNjBNaEV4SzJiT3N2cGJMdW03dXVhTwpxanMwSk16TUpOejNMTzNDV1pTTmZjMkR5Sy9abzAyMGJPNDBmWElMd3FZWWFOcFYwVWR5cG9OeGFaZGtPWU4zCnRjY1FobU0vL0hhRFNORk8zZjhNY0FId3hHa3c2NGQvOFNvRElkZGVocHA0cTloeVhmOXlJVElrS0FHcEZabmQKdGdmeG9QYVhpVUFZWmpIWHpwc1NPTHZkcFVEVEIwM2dFQXRSRndJREFRQUJBb0lCQURXYWE3OUMzNlBjb1I1dApwN0RabFZtdE5ENFNlUWNWY3htYmFVa1NtcURsaTBvNG5qbDM2QU9xSFRTZmFxOEd0RUo2ZGxYTVJETnNUeGthCmtiUGc2T01BcDV0aFk1eUlHV0pJVkRkWVFyZ1FzZzFKSUN6WDczeWJ1ZjVYU05VODczYzFwN2J4b1BlUUpNdm0Kamw0djA5eHdpZGdDcWZEL1BPMG94QmsyVkM0TVcyZGdaZ01VKzZnQXJZZVpTQnhhRzE3eU1xbnZsOVVjQ1kzbAozM1RoV0MzK3Rtc2VOcFlYOXh1elZLUlJ3NWlJWXdnSmdwODNockcvMUEzMGhIeThTY05SOU4zcTdoa2J4MmtVCjRDeDA3Sk5LTGdCdjMxR0d5QjZjelg4dlRVT3RkR0dXVzhvdzZ5VjNacHp2aEJ2b2MrOVFYRytEWWZKcUtWZysKVjhJV2dma0NnWUVBN0puYUNuOWZsQXZIYkVvanRJZHVwZVJZZVZuaXhXd3FlRDNoQWdBMnZQdlo2QmQ5YjcrLwpHZ3B4SEkwZkdSQmliRVF1Mzh3TWppOHRCREEra1JVL3VETngyblBNOFRKeG96QkE5VDNFdW9qSllabEFockdOCm9paGxuTytNS1YvYXBPY0lpZmp2bXgvdHJYQkZqNnhkS1F6M3FFTTNBTjNHcm9CUzYyRjFKME1DZ1lFQXlwbzgKV2Z1dm91d3FDN29ucERBeXhQTWg0bzBsYjNEZU05WFh0bUtic3FCMkpLZEM0NkdwZ3JXdDJKRWpTUXhKMXBiMwpNaDloUlJqQUExMFZTMmxBb3owcEtLZExmODcybXVNMkpuaW1zdWZjR01GVlR5Uis4WHdsK0FSWlB1MUpBWXc3CmxwN2NhcXFsUm5ITzExU3lsY25qeE1pNVR3eEdmNWMxZDRqb2Y1MENnWUVBdUJydm80T0JwLzJTYkIwMHMyRS8KSkM4TytUNk1TdnJrQVRTRlJiMU0ycmxPMGw2VTZNUFh2RGVyMUgrclZ5Rjh0S3BKbnpOMEFaK0w4OXBtbFJabgp3cm1sT2tzcGlmV3FuMFVKQnN2TnJTaUxLenJKRHdaU0k0QXpzVzVsTGp5OE1kemt0QmZVdW15WjBYK3ZZU0RLClRRc2VHdnhTYklZbDk5czZxcFhuUjJrQ2dZQmlRc1dzZXFYblpaVEsxVUV1bjNXd0VaOUlpbDR5bTFJWlg4aGMKRzUwWjJEc1VjYzYrS2dUVmNSbmNwQit4NlBUU3o2c2FNeC93N0IwTVJKUDBYQnJPVVBacVVpRUszcXk1MkNMRwpLOVBsaHhBM0xXVWJtajY3RGhRNElwdktLamt6Ti9rYWh2ZXVBQTlpaUFYaVo2Q3BoeDRoclp3NlcyREJ0dXRtCml3Ny8vUUtCZ0VObjBhYXA4U1hYMHF6MkpuMzFqMFF2a0h1ZUZCN1lORDZpUUxURUZ5dDM2OXF5R0JDbTh2d3QKSFRhN0I4YmVOcXF5WGd2cGFjQVZoT2xDd1VyZWZuNGlVT1E2UitBbHRid1pSR1dReGpRMTZHSGRoSEFuTGdFRApMNHIvd1JJZ2tmWE
kind: Secret
metadata:
  creationTimestamp: 2019-03-10T20:16:02Z
  name: fortune-https
  namespace: default
  resourceVersion: "8727931"
  selfLink: /api/v1/namespaces/default/secrets/fortune-https
  uid: 5397f2f1-4371-11e9-b107-42010aa2008d
type: Opaque

```

Note how secrets store the value as Binary64 data.

### Using the Secret in a Pod

```fortune-pod-https.yaml
apiVersion: v1
kind: Pod
metadata:
  name: fortune-https
spec:
  containers:
  - image: luksa/fortune:env
  env:
  - name: INTERVAL
    valueFrom:
      configMapKeyRef:
        name: fortune-config
        key: sleep-interval
  volumeMounts:
  - name: html
    mountPath: /var/htdocs
- image: nginx:alpine
  name: web-server
  volumeMounts:
  - name: html
    mountPath: /usr/share/nginx/html
    readOnly: true
  - name: config
    mountPath: /etc/nginx/conf.d
    readOnly: true
  - name: certs
    mountPath: /etc/nginx/certs/
    readOnly: true
  ports:
  - containerPort: 80
  - containerPort: 443
volumes:
  - name: html
    emptyDir: {}
  - name: config
    configMap:
      name: fortune-config
      items:
      - key: my-nginx-config.conf
        path: https.conf
  - name: certs
    secret:
      secretName: fortune-https
```

```
# create pod with secret mounted
kubectl create -f fortune-pod-https.yaml

# test wether nginx is using the cert and key from secret
kubectl port-forward fortune-https 8443:443
curl https://localhost:8443 -k -v

```

### Exposing Secret through environment variable
Works similar to configMap. use `secretKeyRef`

```.yaml
env:
- name: FOO_SECRET
  valueFrom:
    secretKeyRef:
      name: fortune-https
      key: foo
```

### Understanding image pull secrets
You can also use _Secret_ to pull private _Docker_ images. You create a `docker-registry` _Secret_ and then use that in _Pods_ `spec.imagePullSecrets` defintion.

```
# create a docker-registry Secret
kubectl create secret docker-registry mydockerhubsecret \
--docker-username=<username> --docker-password=<password> \
--docker-email=<email>

#Speficy it in the Pd using `imagePullSecret
apiVersion: v1
kind: Pod
metadata:
  name: private-pod
spec:
  imagePullSecrets:
  - name: mydockerhubsecret
  containers:
  - image: username/private:tag
    name: main
```

You can also as _Secret_ to _ServiceAccounts_ if you dont want to include it in every Pod defintion.
