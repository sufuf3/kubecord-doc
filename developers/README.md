# Setup kubeCORD Env

## 說明
在 host 上安裝 OVS，並在 Kubernetes 中加入 ONOS 以及建立一個擁有多個 network interface 的 pod 。讓 pod 與 OVS 連接，讓 ONOS 管理 host 上的 OVS。  

## 軟體需求
- Kubernetes: v1.11.0

## 進行想法
- [x] 建立 VM 環境，並在上面先安裝 OVS 和 Kubernetes
- [x] 建立 ONOS with k8s(使用 [helm](https://github.com/opencord/helm-charts/tree/6.0.0))
- [ ] 讓 OVS 給 ONOS 管理
- [ ] 建立 OVS 的 bridge ，讓 pod 與它連接
- [ ] 建立 network-controller server
- [ ] 建立 network-controller client with 多個 network interface

## 參考資源
- https://www.sdntesting.com/installing-and-using-distributed-onos/

