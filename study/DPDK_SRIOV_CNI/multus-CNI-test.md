# Multus + Flannel + SRIOV

## Install k8s + flannel
1. Use kubespray to install k8s custer without CNI.
Ref: https://github.com/sufuf3/kubespray  

2. Install CNI

```sh
cd /opt/cni/bin
export CNI_URL="https://github.com/containernetworking/plugins/releases/download"
wget -qO- --show-progress "${CNI_URL}/v0.6.0/cni-plugins-amd64-v0.6.0.tgz" | sudo tar -zx
```

3. Install Flannel

```sh
sudo mkdir /run/flannel/
cat <<EOF | sudo tee -a /run/flannel/subnet.env
FLANNEL_NETWORK=10.244.0.0/16
FLANNEL_SUBNET=10.244.0.1/24
FLANNEL_MTU=1450
FLANNEL_IPMASQ=true
EOF
```

## Try multus

4. Apply files

Follow https://github.com/intel/multus-cni#quickstart-guide  

```sh
cat ./images/{multus-daemonset.yml,flannel-daemonset.yml} | kubectl apply -f -
```

5. Create a macvlan-conf CNI configuration loaded as a CRD object

```yaml
cat <<EOF | kubectl create -f -
apiVersion: "k8s.cni.cncf.io/v1"
kind: NetworkAttachmentDefinition
metadata:
  name: macvlan-conf
spec: 
  config: '{
      "cniVersion": "0.3.0",
      "type": "macvlan",
      "master": "eth0",
      "mode": "bridge",
      "ipam": {
        "type": "host-local",
        "subnet": "192.168.1.0/24",
        "rangeStart": "192.168.1.200",
        "rangeEnd": "192.168.1.216",
        "routes": [
          { "dst": "0.0.0.0/0" }
        ],
        "gateway": "192.168.1.1"
      }
    }'
EOF
```

6. create a samplepod pod

```yaml
cat <<EOF | kubectl create -f -
apiVersion: v1
kind: Pod
metadata:
  name: samplepod
  annotations:
    k8s.v1.cni.cncf.io/networks: macvlan-conf
spec:
  containers:
  - name: samplepod
    command: ["/bin/bash", "-c", "sleep 2000000000000"]
    image: dougbtv/centos-network
EOF
```

7. Inspect the pod and see the network interface of pod

```sh
$ kubectl exec -it samplepod -- ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
2: tunl0@NONE: <NOARP> mtu 1480 qdisc noop state DOWN qlen 1000
    link/ipip 0.0.0.0 brd 0.0.0.0
4: eth0@if1862: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 qdisc noqueue state UP
    link/ether 0a:58:0a:f4:00:05 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 10.244.0.5/24 scope global eth0
       valid_lft forever preferred_lft forever
5: net1@if113: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state LOWERLAYERDOWN
    link/ether 76:14:47:20:d6:30 brd ff:ff:ff:ff:ff:ff link-netnsid 1
    inet 192.168.1.201/24 scope global net1
       valid_lft forever preferred_lft forever
```

## Try multus + sriov

1. Install sriov

Need to install golang env.  

```sh
git clone https://github.com/intel/sriov-cni.git
cd sriov-cni && ./build
sudo cp bin/sriov /opt/cni/bin/
```

2. creating sriov network object

```yaml
apiVersion: "k8s.cni.cncf.io/v1"
kind: NetworkAttachmentDefinition
metadata:
  name: sriov-conf
spec:
  config: '{
    "type": "sriov",
    "if0": "ens11f1",
    "ipam": {
            "type": "host-local",
            "subnet": "192.168.2.0/24",
            "rangeStart": "192.168.2.1",
            "rangeEnd": "192.168.2.100",
            "routes": [
                    { "dst": "0.0.0.0/0" }
            ],
            "gateway": "192.168.2.254"
    }
  }'
```

```sh
kubectl create -f sriov-conf.yaml
```

3. View network objects using kubectl

```sh
$ kubectl get net-attach-def
NAME                 AGE
macvlan-conf         2d
sriov-conf           2d
```

4. apply pod-multi-network.yaml

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: multus-multi-net-poc
  annotations:
    k8s.v1.cni.cncf.io/networks: '[
            { "name": "sriov-conf" }
    ]'
spec:  # specification of the pod's contents
  containers:
  - name: multus-multi-net-poc
    image: "busybox"
    command: ["top"]
    stdin: true
    tty: true
```

```sh
kubectl create -f ./pod-multi-network.yaml
```

5. Get pod

```sh
kubectl get pods
NAME                   READY     STATUS    RESTARTS   AGE
multus-multi-net-poc   1/1       Running   0          30s
```

```sh
$ kubectl exec -it multus-multi-net-poc -- ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
2: tunl0@NONE: <NOARP> mtu 1480 qdisc noop qlen 1000
    link/ipip 0.0.0.0 brd 0.0.0.0
4: eth0@if45401: <BROADCAST,MULTICAST,UP,LOWER_UP,M-DOWN> mtu 1450 qdisc noqueue
    link/ether 0a:58:0a:f4:00:aa brd ff:ff:ff:ff:ff:ff
    inet 10.244.0.170/24 scope global eth0
       valid_lft forever preferred_lft forever
113: net1: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc mq qlen 1000
    link/ether 6a:c0:41:d9:7a:9f brd ff:ff:ff:ff:ff:ff
    inet 192.168.2.4/24 scope global net1
       valid_lft forever preferred_lft forever
```
