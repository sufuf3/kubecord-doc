# Multus + SR-IOV + OVS-DPDK

## Table of Content

### Install calico CNI
Ref: https://docs.projectcalico.org/v3.2/getting-started/kubernetes/  

https://raw.githubusercontent.com/projectcalico/calico/master/v2.0/getting-started/kubernetes/installation/hosted/k8s-backend-addon-manager/calico-daemonset.yaml

1. Install an etcd instance with the following command.
```
kubectl apply -f \
https://docs.projectcalico.org/v3.2/getting-started/kubernetes/installation/hosted/etcd.yaml
```
2. Install the RBAC roles required for Calico
```
kubectl apply -f \
https://docs.projectcalico.org/v3.2/getting-started/kubernetes/installation/rbac.yaml
```
3. Install Calico
```
kubectl apply -f \
https://docs.projectcalico.org/v3.2/getting-started/kubernetes/installation/hosted/calico.yaml
```

4. Remove the taints on the master so that you can schedule pods on it.
```
kubectl taint nodes --all node-role.kubernetes.io/master-
```


### Install Multus CNI - CRDs (Custom Resource Definitions )
multus-daemonset.yml
```yaml
---
apiVersion: apiextensions.k8s.io/v1beta1
kind: CustomResourceDefinition
metadata:
  name: network-attachment-definitions.k8s.cni.cncf.io
spec:
  group: k8s.cni.cncf.io
  version: v1
  scope: Namespaced
  names:
    plural: network-attachment-definitions
    singular: network-attachment-definition
    kind: NetworkAttachmentDefinition
    shortNames:
    - net-attach-def
  validation:
    openAPIV3Schema:
      properties:
        spec:
          properties:
            config:
                 type: string
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: multus
rules:
- apiGroups:
  - '*'
  resources:
  - '*'
  verbs:
  - '*'
- nonResourceURLs:
  - '*'
  verbs:
  - '*'
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: multus
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: multus
subjects:
- kind: ServiceAccount
  name: multus
  namespace: kube-system
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: multus
  namespace: kube-system
---
# ------------------------------------------------------
# Currently unused!
# If you wish to customize, mount this in the 
# daemonset @ /usr/src/multus-cni/images/70-multus.conf
# ------------------------------------------------------
kind: ConfigMap
apiVersion: v1
metadata:
  name: multus-cni-config
  namespace: kube-system
  labels:
    tier: node
    app: multus
data:
  cni-conf.json: |
    {
      "name": "multus-cni-network",
      "type": "multus",
      "delegates": [
        {
          "type": "calico",
          "name": "calico.1",
          "delegate": {
            "isDefaultGateway": true
          }
        }
      ],
      "kubeconfig": "/etc/cni/net.d/multus.d/multus.kubeconfig"
    }
---
apiVersion: extensions/v1beta1
kind: DaemonSet
metadata:
  name: kube-multus-ds-amd64
  namespace: kube-system
  labels:
    tier: node
    app: multus
spec:
  template:
    metadata:
      labels:
        tier: node
        app: multus
    spec:
      hostNetwork: true
      nodeSelector:
        beta.kubernetes.io/arch: amd64
      tolerations:
      - key: node-role.kubernetes.io/master
        operator: Exists
        effect: NoSchedule
      serviceAccountName: multus
      containers:
      - name: kube-multus
        image: nfvpe/multus:latest
        resources:
          requests:
            cpu: "100m"
            memory: "50Mi"
          limits:
            cpu: "100m"
            memory: "50Mi"
        securityContext:
          privileged: true
        volumeMounts:
        - name: cni
          mountPath: /host/etc/cni/net.d
        - name: cnibin
          mountPath: /host/opt/cni/bin
      volumes:
        - name: cni
          hostPath:
            path: /etc/cni/net.d
        - name: cnibin
          hostPath:
            path: /opt/cni/bin
        - name: multus-cfg
          configMap:
            name: multus-cni-config
```

### Install golang
```sh
wget --quiet https://storage.googleapis.com/golang/go1.10.2.linux-amd64.tar.gz
sudo tar -zxf go1.10.2.linux-amd64.tar.gz -C /usr/local/
echo 'export GOROOT=/usr/local/go' >>  /home/$USER/.bashrc
echo 'export GOPATH=$HOME/go' >> /home/$USER/.bashrc
echo 'export PATH=/home/$USER/protoc/bin:$PATH:$GOROOT/bin:$GOPATH/bin' >> /home/$USER/.bashrc
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export PATH=/home/$USER/protoc/bin:$PATH:$GOROOT/bin:$GOPATH/bin
# setup golang dir
mkdir -p /home/$USER/go/src
rm -rf /home/$USER/go1.10.2.linux-amd64.tar.gz
```

### Create the SRIOV Network CRD
1. sriov-crd.yaml
```yaml
apiVersion: "k8s.cni.cncf.io/v1"
kind: NetworkAttachmentDefinition
metadata:
  name: sriov-net1
  annotations:
    k8s.v1.cni.cncf.io/resourceName: intel.com/sriov
spec:
  config: '{
    "type": "sriov",
    "name": "sriov-network",
    "if0": "ens11f1",
    "ipam": {
        "type": "host-local",
        "subnet": "10.56.217.0/24",
        "routes": [{
            "dst": "0.0.0.0/0"
        }],
        "gateway": "10.56.217.254"
    }
}'
```

### SRIOV Network device plugin
0. build sriov binary
```
git clone https://github.com/intel/sriov-cni.git
cd sriov-cni
git fetch
git checkout dev/k8s-deviceid-model
./build
sudo cp bin/sriov /opt/cni/bin
```

1. git clone repo
```
cd ~/ && git clone https://github.com/sufuf3/sriov-network-device-plugin.git
```

2. Build the SRIOV Network Device Plugin binary
```
cd sriov-network-device-plugin && ./build.sh
```

3. Build docker script to create SRIOV Network Device Plugin Docker image
```
cd ~/sriov-network-device-plugin/deployments/ && git checkout sufuf3/update && ./build_docker.sh
```

4. Create SRIOV Network Device Plugin Pod
```
kubectl create -f pod-sriovdp.yaml
kubectl logs sriov-device-plugin
```

5. Testing SRIOV workloads
```
kubectl create -f pod-tc2.yaml
```
