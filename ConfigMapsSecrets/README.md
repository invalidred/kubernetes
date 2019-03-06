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


