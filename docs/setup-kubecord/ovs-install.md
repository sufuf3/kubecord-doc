# 安裝支援 DPDK 的 OVS 在 host 上

## Table of Contents

- [安裝必要的 pip 套件](#安裝必要的-pip-套件)
- [下載 OVS 安裝包](#下載-ovs-安裝包)
- [設定 OVS_DIR 環境變數](#設定-ovs-dir-環境變數)
- [編譯 OVS](#編譯-ovs)
- [新增一個 ovsdb](#新增一個-ovsdb)
- [關機後可以用 OVS](#關機後可以用-ovs)

## 安裝必要的 pip 套件

```sh
$ sudo pip install six
```

## 下載 OVS 安裝包

```sh
$ cd ~/
$ wget --quiet http://openvswitch.org/releases/openvswitch-2.9.2.tar.gz
$ sudo tar -zxf openvswitch-2.9.2.tar.gz -C /usr/src/
```

## 設定 OVS_DIR 環境變數

```sh
$ export OVS_DIR=/usr/src/openvswitch-2.9.2
```

## 編譯 OVS

```sh
cd $OVS_DIR
./boot.sh
CFLAGS='-march=native' ./configure --prefix=/usr --localstatedir=/var --sysconfdir=/etc --with-dpdk=$DPDK_BUILD
make && sudo make install
sudo mkdir -p /etc/openvswitch
sudo mkdir -p /var/run/openvswitch
sudo mkdir -p /var/log/openvswitch
```

## 新增一個 ovsdb

```sh
$ sudo ovsdb-tool create /etc/openvswitch/conf.db vswitchd/vswitch.ovsschema
```

## 關機後可以用 OVS

```sh
$ echo 'export PATH=$PATH:/usr/local/share/openvswitch/scripts' | sudo tee -a /root/.bashrc
$ echo "openvswitch" | sudo tee -a /etc/modules
```
