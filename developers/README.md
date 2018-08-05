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
- [ ] 讓 OVS 給 ONOS 管理
- [ ] 建立 network-controller client with 多個 network interface

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


## 其他
如果要安裝桌面版
```
$ sudo apt-get install ubuntu-desktop
```

## 參考資源
- https://www.sdntesting.com/installing-and-using-distributed-onos/

