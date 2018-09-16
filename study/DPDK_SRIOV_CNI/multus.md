# Multus + SR-IOV + OVS-DPDK

## Table of Content

### Install Multus CNI
```sh
curl -LO https://storage.googleapis.com/golang/go1.8.3.linux-amd64.tar.gz && \
tar -xzf go1.8.3.linux-amd64.tar.gz && \
sudo mv go /usr/local
echo "export GOROOT=/usr/local/go" >> ~/.bash_profile
echo "export GOPATH=\$HOME/Projects/Proj1" >> ~/.bash_profile
echo "export PATH=\$GOPATH/bin:\$GOROOT/bin:\$PATH" >> ~/.bash_profile
source ~/.bash_profile
git clone https://github.com/Intel-Corp/multus-cni.git
cd multus-cni
./build
sudo cp bin/multus /opt/cni/bin/
```

### RBAC
