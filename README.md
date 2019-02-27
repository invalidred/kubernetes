# Introduction To Kubernetes
## Summary
Moving from Monoliths to micro-services which allows components to be developed, deployed, updated and scaled independently. This allows to develop rapidly based on business needs.

However with more deployable components it is increasingly harder to configure, manage and keep the whole system running. We need automation which includes scheduling of those components into our servers, auto configuration, supervision and failure-handling. This is how Kubernetes can help.

Kubernetes allows devs to deploy apps without the help of operations (ops) team. It also helps ops by automatically scheduling and monitoring those apps in event of hardware failure. 

::Kubernetes abstracts the entire data-centre as a single enormous computational resource::. It allows you to deploy components without knowing the infrastructure. You give your component(s) and Kubernetes will select the best server for your app.

## Core Idea
The system is composed of a `master` node and any number of worker `nodes`. When you deploy your apps to `master` Kubernetes deploys them to any number of worker `nodes`. What node a component lands on doesn’t matter to dev or system admin.

![](&&&SFLOCALFILEPATH&&&Screen%20Shot%202019-01-16%20at%207.22.33%20PM.png)

Dev can specify the apps that need to be together and Kubernetes will deploy them on same worker `nodes` and other apps. Other apps will spread across the cluster, however they can talk to each other the same way regardless of where they are deployed.

## Basic Services Kubernetes Provides
Kubernetes provides a lot of services, enabling the developer to focus on code and not worry about integrating with infrasctrue
- scaling
- service discovery
- load-balancing
- self-healing
- leader election

## Kubernetes Architecture in Depth
- It consists of `master` node which contains `Kubernetes Control Plane` that manages Kubernetes system.
- It also consists of worker `nodes`

![](&&&SFLOCALFILEPATH&&&078AD92B-96BD-40C3-AE3C-40B3218FC28E.png)

### The Control Plane
It control the cluster and can be hosted on one machine or multiple machines for higher availability 

- `API Server` you can other control plane components communicate with
- `Scheduler` helps schedule your app by binding it to a worker `node`
- `Controller Manager` does cluster level functions such as component replication, tracking worker `nodes`, handing failure etc..
- `etcd`reliable distributed data store to store cluster config

### The (worker) Nodes
These are Nodes that run your containerized components. 
- You can use `Docker` or any Open Container Compliant technology such as `rkt`
- `Kublet`talks to `API server` and manages containers on it node
- `kube-proxy` load-balances network traffic amongst app components



