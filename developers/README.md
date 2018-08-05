# Setup kubeCORD Env

## Table of Contents
* [說明](#說明)
* [軟體需求](#軟體需求)
* [進行想法](#進行想法)
* [Setup](#setup)
    + [1. 在 VM 中安裝 OVS 和 Kubernetes](#1-在-vm-中安裝-ovs-和-kubernetes)
    + [2. 進到 VM 中安裝 ONOS](#2-進到-vm-中安裝-onos)
    + [3. 用 kubernetes 建立 network-controller server](#3-用-kubernetes-建立-network-controller-server)
    + [4. 建立 OVS 的 bridge (之後讓 pod 與它連接)](#4-建立-ovs-的-bridge-之後讓-pod-與它連接)
    + [5. 建立 network-controller client with 多個 network interface](#5-建立-network-controller-client-with-多個-network-interface)
    + [6. 讓 OVS 給 ONOS 管理](#6-讓-ovs-給-onos-管理)
* [其他](#其他)
* [參考資源](#參考資源)


## 說明
在 host 上安裝 OVS，並在 Kubernetes 中加入 ONOS 以及建立一個擁有多個 network interface 的 pod 。讓 pod 與 OVS 連接，讓 ONOS 管理 host 上的 OVS。  

## 軟體需求
- Kubernetes: v1.11.0

## 進行想法
- [x] 建立 VM 環境，並在上面先安裝 OVS 和 Kubernetes
- [x] 建立 ONOS with k8s(使用 [helm](https://github.com/opencord/helm-charts/tree/6.0.0))
- [x] 建立 network-controller server
- [x] 建立 OVS 的 bridge (之後讓 pod 與它連接)
- [x] 建立 network-controller client with 多個 network interface
- [x] 讓 OVS 給 ONOS 管理

## Setup
### 1. 在 VM 中安裝 OVS 和 Kubernetes
```sh
vagrant up
```

### 2. 進到 VM 中安裝 ONOS
```sh
$ vagrant ssd
vagrant@kubecord-dev:~$ cd ~/helm-charts/ && helm install -n onos-fabric -f configs/onos-fabric.yaml onos
```

- Access web
via `http://localhost:31181/onos/ui/login.html`  
Default username and password are onos/rocks  
- Access CLI
```sh
$ kubectl get all
NAME                                       READY     STATUS    RESTARTS   AGE
pod/onos-fabric-77b488c88f-mnqgk           1/1       Running   1          1h

NAME                           TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)          AGE
service/kubernetes             ClusterIP   10.96.0.1        <none>        443/TCP          2h
service/onos-fabric-openflow   NodePort    10.101.24.175    <none>        6653:31653/TCP   1h
service/onos-fabric-ovsdb      NodePort    10.101.137.69    <none>        6640:31640/TCP   1h
service/onos-fabric-ssh        NodePort    10.111.168.103   <none>        8101:31101/TCP   1h
service/onos-fabric-ui         NodePort    10.102.41.6      <none>        8181:31181/TCP   1h

NAME                          DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/onos-fabric   1         1         1            1           1h

NAME                                     DESIRED   CURRENT   READY     AGE
replicaset.apps/onos-fabric-77b488c88f   1         1         1         1h
```
Access:  
```sh
vagrant@kubecord-dev:~$ ssh -p 8101 onos@10.111.168.103
```
or  
```sh
vagrant@kubecord-dev:~$ ssh -p 31101 onos@localhost
```
password is `rocks`


### 3. 用 kubernetes 建立 network-controller server
```sh
vagrant@kubecord-dev:~$ cd ~/network-controller && kubectl create -f deploy/server/
```

### 4. 建立 OVS 的 bridge (之後讓 pod 與它連接)
```sh
vagrant@kubecord-dev:~$ sudo ovs-vsctl add-br br100
vagrant@kubecord-dev:~$ sudo ovs-vsctl show
```

### 5. 建立 network-controller client with 多個 network interface
eth100 是自己創建的 network interface 並且連接 OVS。  
```sh
vagrant@kubecord-dev:~/network-controller$ cd ~/network-controller && kubectl create -f deploy/client/
vagrant@kubecord-dev:~/network-controller$ kubectl exec -it myapp-pod -- sh
/ # ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue qlen 1
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
3: eth0@if18: <BROADCAST,MULTICAST,UP,LOWER_UP,M-DOWN> mtu 1450 qdisc noqueue
    link/ether 0a:58:0a:f4:00:0b brd ff:ff:ff:ff:ff:ff
    inet 10.244.0.11/24 scope global eth0
       valid_lft forever preferred_lft forever
5: eth100@if19: <BROADCAST,MULTICAST,UP,LOWER_UP,M-DOWN> mtu 1500 qdisc noqueue
    link/ether 3a:fc:14:09:a9:b9 brd ff:ff:ff:ff:ff:ff
    inet 192.168.24.50/24 brd 192.168.24.255 scope global eth100
       valid_lft forever preferred_lft forever
/ # exit
vagrant@kubecord-dev:~/network-controller$ sudo ovs-vsctl show
5c92933c-f8f4-4fd1-aaf5-0246f5a0c576
    Bridge "br100"
        Port "veth25bce837"
            Interface "veth25bce837"
        Port "br100"
            Interface "br100"
                type: internal
    ovs_version: "2.5.4"
```
> 在這步驟，可以見兩個 pod ，然後測試互 ping 可不可以成功。在同個 192.168.24.50/24 網段，是可以互 ping 成功的。

### 6. 讓 OVS 給 ONOS 管理
```sh
vagrant@kubecord-dev:~$ sudo ovs-vsctl set-controller br100 tcp:127.0.0.1:31653
vagrant@kubecord-dev:~$ sudo ovs-vsctl show
5c92933c-f8f4-4fd1-aaf5-0246f5a0c576
    Manager "ptcp:31640"
    Bridge "br100"
        Controller "tcp:127.0.0.1:31653"
            is_connected: true
        Port "br100"
            Interface "br100"
                type: internal
        Port "vethf18dfdd3"
            Interface "vethf18dfdd3"
        Port "veth7aba5522"
            Interface "veth7aba5522"
    ovs_version: "2.5.4"
```
- Check
![](https://i.imgur.com/NdQs9QD.png)  
```sh
vagrant@kubecord-dev:~/network-controller$ ssh -p 31101 onos@localhost
Password authentication
Password:
Welcome to Open Network Operating System (ONOS)!
     ____  _  ______  ____
    / __ \/ |/ / __ \/ __/
   / /_/ /    / /_/ /\ \
   \____/_/|_/\____/___/

Documentation: wiki.onosproject.org
Tutorials:     tutorials.onosproject.org
Mailing lists: lists.onosproject.org

Come help out! Find out how at: contribute.onosproject.org

Hit '<tab>' for a list of available commands
and '[cmd] --help' for help on a specific command.
Hit '<ctrl-d>' or type 'system:shutdown' or 'logout' to shutdown ONOS.

onos> devices
id=of:0000120b2a6c2a45, available=true, local-status=connected 21m28s ago, role=MASTER, type=SWITCH, mfr=Nicira, Inc., hw=Open vSwitch, sw=2.5.4, serial=None, chassis=120b2a6c2a45, driver=ovs, channelId=10.244.0.1:33800, managementAddress=10.244.0.1, protocol=OF_13
```
### 7. Lab Time
[lab.md](lab.md)

## 其他
- 如果要安裝桌面版  
```
$ sudo apt-get install ubuntu-desktop
```
- 如果是 VM ，如果要 access 網頁，可以將 port fowrding 打開。

## 參考資源
- http://roan.logdown.com/posts/191801-set-openvswitch
- http://www.openvswitch.org/support/dist-docs/ovs-vsctl.8.txt
- https://wiki.onosproject.org/display/ONOS/CLI+and+Service+Tutorial
- https://wiki.onosproject.org/display/ONOS/OVSDB+interaction+and+ONOS+cli+example
- https://guide.opencord.org/charts/onos.html
