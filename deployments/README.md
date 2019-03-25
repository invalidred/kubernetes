# Deployments
_Deployments_ a higher level resources that uses _ReplicaSets_ and _Pods_ under the hood and it's controlled by the Kubernetes API Server. It helps with the following tasks
- Updates new deployments through _rolling update_ or _recreate_ strategies
- Roll back deployment to a previous version
- Block rollouts of bad versions
- Pausing a rollout process
- Controlling the rate of a rollout

```kubia-deployment-v1.yaml
apiVersion: apps/v1beta1
kind: Deployment
metadata:
  name: kubia
spec:
  replicas: 3
  template:
    metadata:
      name: kubia
      labels:
        app: kubia
    spec:
      containers:
      - image: luksa/kubia: v1
        name: nodejs
```

```
# create the deployment
kubectl create -f kubia-deployment-v1.yaml --record

# check deployment status
kubectl rollout status deployment kubia

# slowing down the rolling update for demo purposes
kubectl patch deployment kubia -p '{"spec": {"minReadySeconds": 10}}'

# trigger rolling update by setting image for deployment
kubectl set image deployment kubia nodejs=luksa/kubia:v2

```

## Rolling Back a Deployment

```
# Say you create v3 of your APP
kubectl set image deployment kubia nodejs=luksa/kubia:v3

# Check the status of your rollout
kubectl rollout status deployment kubia

# To undo a rollout
kubia rollout undo deployment kubia

# To display a rollout history
kubia rollout history deployment kubia

# Rolling back to a specify revision
kubia rollout undo deployment kubia --to-revision=1
```

## MaxSurge and MaxUnavailable

_MaxSurge_ the number of replicas that can be increased from base threshold to accomodate rolling updates. For exammple the default is 25%, so there can be atmost 25% more pods thandesired count. So if desired count = 3, with maxSurge of 25%, there can be one extra pod available when rolling updates.

_MaxUnavailable_ the number of pod instances that can be unavailable relative to the desired replica count during update. The default is 25%, so the replica count can never go below 75% of the desired count.

## Pausing Rollout

```
# rollout another version
kubectl set image deployment kubia nodejs=luksa/kubia:v4

# pause rollout
kubectl rollout pause deployment kubia

# resume rollout
kubectl rollout resume deployment kubia
```
