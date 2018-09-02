sudo apt-get update
sudo apt-get install -y git build-essential nfs-common ntp jq httpie vim cmake tcpdump unzip tig socat

# YouCompleteMe requirement
sudo apt-get -qq install -y python-dev python3-dev python python-pip htop

# Install Docker
# kubernetes official max validated version: 17.03.2~ce-0~ubuntu-xenial
export DOCKER_VERSION="17.06.2~ce-0~ubuntu"
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get update
sudo apt-get install -y docker-ce=${DOCKER_VERSION}
# Manage Docker as a non-root user
sudo usermod -aG docker $USER

# Install Kubernetes
export KUBE_VERSION="1.11.0"
export NET_IF_NAME="enp8s0"
sudo apt-get install -y apt-transport-https curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee --append /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubectl kubelet=${KUBE_VERSION}-00 kubeadm=${KUBE_VERSION}-00

# Disable swap
sudo swapoff -a && sudo sysctl -w vm.swappiness=0
sudo sed '/swap.img/d' -i /etc/fstab
sudo kubeadm init --kubernetes-version v${KUBE_VERSION} --pod-network-cidr=10.244.0.0/16
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Should give flannel the real network interface name
#wget --quiet https://raw.githubusercontent.com/coreos/flannel/v0.9.1/Documentation/kube-flannel.yml -O /tmp/kube-flannel.yml
#sed -i -- 's/"--kube-subnet-mgr"/"--kube-subnet-mgr", "--iface='"$NET_IF_NAME"'"/g' /tmp/kube-flannel.yml
#kubectl apply -f /tmp/kube-flannel.yml
kubectl taint nodes --all node-role.kubernetes.io/master-

# Install helm
curl -L https://storage.googleapis.com/kubernetes-helm/helm-v2.9.1-linux-amd64.tar.gz > helm-v2.9.1-linux-amd64.tar.gz && tar -zxvf helm-v2.9.1-linux-amd64.tar.gz && chmod +x linux-amd64/helm && sudo mv linux-amd64/helm /usr/local/bin/helm
rm -rf /home/$USER/helm-v2.9.1-linux-amd64.tar.gz
sudo pip install yq

#cd ~/ && git clone https://github.com/opencord/helm-charts.git
#cd ~/helm-charts/ && git checkout 6.0.0
#cd ~/helm-charts/ && helm init
#cd ~/helm-charts/ && kubectl create serviceaccount --namespace kube-system tiller
#cd ~/helm-charts/ && kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
#cd ~/helm-charts/ && kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'

