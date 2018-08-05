# Setup kubeCORD Env

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
- [ ] 讓 OVS 給 ONOS 管理

## Setup
1. 在 VM 中安裝 OVS 和 Kubernetes
```sh
vagrant up
```

2. 進到 VM 中安裝 ONOS
```sh
$ vagrant ssd
vagrant@kubecord-dev:~$ cd ~/helm-charts/ && helm install -n onos-fabric -f configs/onos-fabric.yaml onos
```
Access web via `http://localhost:31181/onos/ui/login.html`  
Default username and password are onos/rocks  

3. 用 kubernetes 建立 network-controller server
```sh
vagrant@kubecord-dev:~$ cd ~/network-controller && kubectl create -f deploy/server/
```

4. 建立 OVS 的 bridge (之後讓 pod 與它連接)
```sh
vagrant@kubecord-dev:~$ sudo ovs-vsctl add-br br100
vagrant@kubecord-dev:~$ sudo ovs-vsctl show
```

5. 建立 network-controller client with 多個 network interface
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

## 其他
如果要安裝桌面版
```
$ sudo apt-get install ubuntu-desktop
```

## 參考資源
- https://www.sdntesting.com/installing-and-using-distributed-onos/

