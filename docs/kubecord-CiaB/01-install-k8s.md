# Install kubeadm
This is a step-by-step note of how to build kubecord-CiaB on one node.   

## Table of contents
- [Requirement](#requirement)
- [Pre-setup](#pre-setup)

## Requirement
- OS: Ubuntu 16.04

### pre-setup
1. Update & upgrade
```sh
$ sudo apt update && sudo apt upgrade -y
```
2. Install Docker
```sh
$ curl -sSL https://get.docker.com/ | sh
$ sudo usermod -aG docker <username>
$ logout
```
3. Login again
4. Edit `/lib/systemd/system/docker.service`
Add the follwoing line before the line `ExecStart=..`
```sh
ExecStartPost=/sbin/iptables -A FORWARD -s 0.0.0.0/0 -j ACCEPT
```
5. restart docker service
```sh
$ systemctl daemon-reload && systemctl restart docker
```
6. Setting routing
```sh
$ cat <<EOF > /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

$ sysctl -p /etc/sysctl.d/k8s.conf
```
## Install kubeadm, kubelet and kubectl
1. Install
```sh
$ apt-get install -y apt-transport-https curl
$ curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
```
```sh
$ vim /etc/apt/sources.list.d/kubernetes.list
```
```sh
deb http://apt.kubernetes.io/ kubernetes-xenial main
```
```sh
$ apt-get update
$ apt-get install -y kubelet kubeadm kubectl
```
2. Initial Kubernetes
```sh
$ sudo kubeadm init --pod-network-cidr=10.244.0.0/16
$ mkdir -p $HOME/.kube
$ sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
$ sudo chown $(id -u):$(id -g) $HOME/.kube/config
$ kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/v0.9.1/Documentation/kube-flannel.yml
$ kubectl taint nodes --all node-role.kubernetes.io/master-
```
(If you want to reset the kubernetes node, please run `sh script/k8s-kubeadm-reinstall.sh`)  
