# 安裝 DPDK

## Table of Contents
- [前言](#前言)
- [安裝 DPDK 的相依套件](#安裝-dpdk-的相依套件)
- [下載 DPDK 安裝包](#下載-dpdk-安裝包)
- [設定 DPDK 相關的環境變數](#設定-dpdk-相關的環境變數)
- [Build 與安裝 DPDK library](#build-與安裝-dpdk-library)
- [設定 DPDK 為 shared library](#設定-dpdk-為-shared-library)
- [設定 Linux Drivers 的 kernel module](#設定-linux-drivers-的-kernel-module)
  * [加 driver 的 kernel modules，load vfio-pci kernel module](#加-driver-的-kernel-modules-load-vfio-pci-kernel-module)
  * [開機後還是可以 load vfio-pci 的設定](#開機後還是可以-load-vfio-pci-的設定)

## 前言

參考 http://docs.openvswitch.org/en/latest/intro/install/dpdk/

## 安裝 DPDK 的相依套件

```sh
$ sudo apt-get -qq update
$ sudo apt-get -y -qq install clang doxygen hugepages build-essential libnuma-dev libpcap-dev inux-headers-`uname -r` dh-autoreconf libssl-dev libcap-ng-dev openssl python python-pip htop
$ sudo pip install six
```

## 下載 DPDK 安裝包

```sh
wget http://fast.dpdk.org/rel/dpdk-17.11.4.tar.xz
sudo tar xf dpdk-17.11.4.tar.xz -C /usr/src/
```

## 設定 DPDK 相關的環境變數

```sh
echo 'export DPDK_DIR=/usr/src/dpdk-stable-17.11.4' | sudo tee -a /root/.bashrc
echo 'export LD_LIBRARY_PATH=$DPDK_DIR/x86_64-native-linuxapp-gcc/lib' | sudo tee -a /root/.bashrc
echo 'export DPDK_TARGET=x86_64-native-linuxapp-gcc' | sudo tee -a /root/.bashrc
echo 'export DPDK_BUILD=$DPDK_DIR/$DPDK_TARGET' | sudo tee -a /root/.bashrc
echo 'export DPDK_DIR=/usr/src/dpdk-stable-17.11.4' | tee -a ~/.bashrc
echo 'export LD_LIBRARY_PATH=$DPDK_DIR/x86_64-native-linuxapp-gcc/lib' | tee -a ~/.bashrc
echo 'export DPDK_TARGET=x86_64-native-linuxapp-gcc' | tee -a ~/.bashrc
echo 'export DPDK_BUILD=$DPDK_DIR/$DPDK_TARGET' | tee -a ~/.bashrc
export DPDK_DIR=/usr/src/dpdk-stable-17.11.4
export DPDK_TARGET=x86_64-native-linuxapp-gcc
export DPDK_BUILD=$DPDK_DIR/$DPDK_TARGET
export LD_LIBRARY_PATH=$DPDK_DIR/x86_64-native-linuxapp-gcc/lib
```

## Build 與安裝 DPDK library

```sh
cd $DPDK_DIR && sudo make install T=$DPDK_TARGET DESTDIR=install
```

## 設定 DPDK 為 shared library

```sh
$ sudo sed -i 's/CONFIG_RTE_BUILD_SHARED_LIB=n/CONFIG_RTE_BUILD_SHARED_LIB=y/g' ${DPDK_DIR}/config/common_base
```

## 設定 Linux Drivers 的 kernel module

使用 VFIO driver

- Ref:
    - http://docs.openvswitch.org/en/latest/intro/install/dpdk/#setup-dpdk-devices-using-vfio
    - https://doc.dpdk.org/guides/linux_gsg/linux_drivers.html#vfio

### 加 driver 的 kernel modules，load vfio-pci kernel module

```sh
sudo modprobe vfio-pci
sudo chmod a+x /dev/vfio
sudo sudo chmod 0666 /dev/vfio/*
```

### 開機後還是可以 load vfio-pci 的設定

```sh
sudo depmod -a
echo "vfio-pci" | sudo tee -a /etc/modules
```

