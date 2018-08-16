# Multus CNI w/ SR-IOV & DPDK

## Table of Contents

* [前提摘要](#前提摘要)
* [測試的硬體與軟體規格](#測試的硬體與軟體規格)
  + [硬體](#硬體)
  + [軟體](#軟體)
* [安裝過程紀錄](#安裝過程紀錄)
  + [1. 設定 Hugepages 為 1G for DPDK & Activate Intel VT-d in the kernel](#1-設定-hugepages-為-1g-for-dpdk--activate-intel-vt-d-in-the-kernel)
    - [說明](#說明)
    - [操作](#操作)
  + [2. 安裝 DPDK](#2-安裝-dpdk)
  + [3. 設定 Linux Drivers 的 kernel module](#3-設定-linux-drivers-的-kernel-module)
  + [4. 綁定 Network Ports 到 Kernel Modules](#4-綁定-network-ports-到-kernel-modules)
  + [5. 安裝支援 DPDK 的 `OVS` 在 host 上](#5-安裝支援-dpdk-的-ovs-在-host-上)
  + [6. Setup Open vSwitch](#6-setup-open-vswitch)
  + [7. 建立 OVS 的 bridge](#7-建立-ovs-的-bridge)
  + [8. 安裝 Docker + Kubernetes + helm 等](#8-安裝-docker--kubernetes--helm-等)
  + [9. Multus CNI](#9-multus-cni)
  + [10. ONOS with k8s](#10-onos-with-k8s)
  + [11. 先測 podd 在 ovs bridge 底下的互通情形](#11-先測-podd-在-ovs-bridge-底下的互通情形)
  + [12. 讓 OVS 給 ONOS 管理的測試](#12-讓-ovs-給-onos-管理的測試)
* [其他](#其他)
* [參考](#參考)

## 前提摘要

實作一個 k8s 的 pod 支援多個 interface。且可以使用不同功能的 interface。  
包含：  
- k8s 原本的 CNI (eg. flannel)
- Multus CNI 創建與 DPDK-OVS 中間的 vth
- Multus CNI 創建 SR-IOV 的 CNI ，讓 pod 的 interface 直接使用實體網卡的 interface。

而因為使用 Multus CNI ，所以所有 pod 的網路建立都是交給 k8s 管理，增加方便性。  
在硬體方面，實體主機上至少要有兩個 interface ，一個是給普通的 k8s 集群用的，一個不是給 DPDK ，要不然就是給 SR-IOV 。當然也可以有三個以上 interface 在實體主機上。  
  
### 初步構想
![](https://i.imgur.com/8Zul73X.png)  
- enp8s0: 走 k8s 使用的 flannel CNI，當作是 k8s 的管理介面
- enp9s0: 使用 Multus CNI + DPDK
- ens11f0: 使用 Multus CNI + DPDK + SR-IOV
- ens11f1: 使用 Multus CNI + SR-IOV

## 測試的硬體與軟體規格
### 硬體

- CPU
    - Architecture:          x86_64
    - CPU(s):                32
    - Model name:            Intel(R) Xeon(R) CPU E5-2620 v4 @ 2.10GHz
    - NUMA node0 CPU(s):     0-7,16-23
    - NUMA node1 CPU(s):     8-15,24-31
- RAM: 94G
- Disk: 477G
- Network interface
```sh
2: enp8s0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether cc:37:ab:e1:21:64 brd ff:ff:ff:ff:ff:ff
    inet 140.113.x.x/25 brd 140.113.x.x scope global enp8s0
       valid_lft forever preferred_lft forever
    inet6 fe80::ce37:abff:fee1:2164/64 scope link
       valid_lft forever preferred_lft forever
3: enp9s0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc mq state DOWN group default qlen 1000
    link/ether cc:37:ab:e1:21:65 brd ff:ff:ff:ff:ff:ff
4: ens11f0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc mq state DOWN group default qlen 1000
    link/ether cc:37:ab:dd:f2:69 brd ff:ff:ff:ff:ff:ff
5: ens11f1: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc mq state DOWN group default qlen 1000
    link/ether cc:37:ab:dd:f2:6a brd ff:ff:ff:ff:ff:ff
```

- 看看各個 interface 的 driver module
```sh
$ ethtool -i enp8s0 | grep ^driver
driver: igb
$ ethtool -i enp9s0 | grep ^driver
driver: igb
$ ethtool -i ens11f0 | grep ^driver
driver: ixgbe
$ ethtool -i ens11f1 | grep ^driver
driver: ixgbe
```

- 網卡資訊
```sh
$ lspci | grep -i Ethernet
01:00.0 Ethernet controller: Intel Corporation 82599ES 10-Gigabit SFI/SFP+ Network Connection (rev 01)
01:00.1 Ethernet controller: Intel Corporation 82599ES 10-Gigabit SFI/SFP+ Network Connection (rev 01)
08:00.0 Ethernet controller: Intel Corporation I210 Gigabit Network Connection (rev 03)
09:00.0 Ethernet controller: Intel Corporation I210 Gigabit Network Connection (rev 03)
```
> 可以支援 SR-IOV 的 interface 是 ens11f0 & ens11f1

### 軟體
OS: Ubuntu 16.04

## 安裝過程紀錄
### 1. 設定 Hugepages 為 1G for DPDK & Activate Intel VT-d in the kernel
#### 說明

- Hugepages  
因為這台主機可以支援 1G 的 Hugepages。所以就用比較大的 Hugepages size。  
而 hugepage 的分配應該在開機後或是系統開機後越早做越好，因為要避免使用支離破碎的物理 Memory。(所以要使用完整的物理 Memory 空間)  
因為原本預設的 Hugepages size 2048 kb 大小，所以要設定 grub 來修正預設的 Hugepages size。  

- Activate Intel VT-d in the kernel

#### 操作
- **1. 先把原本的檔案做個備份**
```sh
$ sudo cp /etc/default/grub /etc/default/grub.old
```

- **2. 確認已經有 enable VT-d**
```sh
$ cat /proc/cpuinfo | grep vmx
```

- **3. 查看原本的 hugepage 配置**
```sh
$ cat /proc/meminfo | grep Huge
AnonHugePages:         0 kB
ShmemHugePages:        0 kB
HugePages_Total:       0
HugePages_Free:        0
HugePages_Rsvd:        0
HugePages_Surp:        0
Hugepagesize:       2048 kB
```

- **4. 編輯 /etc/default/grub**
```sh
GRUB_DEFAULT=0
GRUB_HIDDEN_TIMEOUT=0
GRUB_HIDDEN_TIMEOUT_QUIET=true
GRUB_TIMEOUT=0
GRUB_DISTRIBUTOR=`lsb_release -i -s 2> /dev/null || echo Debian`
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"
GRUB_CMDLINE_LINUX="transparent_hugepage=never default_hugepagesz=1G hugepagesz=1G hugepages=8 iommu=pt intel_iommu=on"
```
> Ref: http://dpdk.readthedocs.io/en/v16.04/linux_gsg/nic_perf_intel_platform.html  

- **5. Update grub**
```sh
$ sudo update-grub
Generating grub configuration file ...
Found linux image: /boot/vmlinuz-4.15.0-30-generic
Found initrd image: /boot/initrd.img-4.15.0-30-generic
done
```

- **6. 重啟主機**
```sh
$ reboot
```

- **7. 確認 /proc/cmdline**
```sh
$ cat /proc/cmdline
BOOT_IMAGE=/boot/vmlinuz-4.15.0-30-generic root=UUID=6dd5050f-5f5c-4b0f-8672-507b4161feaa ro transparent_hugepage=never default_hugepagesz=1G hugepagesz=1G hugepages=8 iommu=pt intel_iommu=on
```

- **8. 確認使用 8 個 1G size 的 Hugepage**
```sh
$ cat /proc/meminfo | grep Huge
AnonHugePages:         0 kB
ShmemHugePages:        0 kB
HugePages_Total:       8
HugePages_Free:        8
HugePages_Rsvd:        0
HugePages_Surp:        0
Hugepagesize:    1048576 kB
```
htop 也會看到使用 8G 的 memory。

- **9. 確認 IOMMU**
```sh
$ dmesg | grep -e IOMMU
[    0.000000] DMAR: IOMMU enabled
[    0.000000] DMAR-IR: IOAPIC id 3 under DRHD base  0xfbffc000 IOMMU 0
[    0.000000] DMAR-IR: IOAPIC id 1 under DRHD base  0xc7ffc000 IOMMU 1
[    0.000000] DMAR-IR: IOAPIC id 2 under DRHD base  0xc7ffc000 IOMMU 1

# 只有 ens11f1 和 ens11f0 支援 SR-IOV
$ cat /sys/class/net/ens11f1/device/sriov_totalvfs
63

$ cat /sys/class/net/ens11f0/device/sriov_totalvfs
63
```

- **10. Setting hugepage number**
```sh
$ echo 'vm.nr_hugepages=8' | sudo tee /etc/sysctl.d/hugepages.conf
```

- **11. Mount hugepages**
```sh
$ sudo mount -t hugetlbfs none /dev/hugepages
```

- **12. 設定 kernel 變數在執行的時候**
```sh
$ sudo sysctl -w vm.nr_hugepages=8
```

### 2. 安裝 DPDK
#### 說明

雖然目前 DPDK 已經升版到 18.08 ，但因為目前 http://docs.openvswitch.org/en/latest/intro/install/dpdk/ 上面是提供 DPDK v17.11.3 的方法，所以先照文件做。  
- **需要的工具以及 Libraries**
    - GNU `make`
    - coreutils: `cmp`, `sed`, `grep`, `arch`, etc.
    - gcc v4.9 以上
    - libc headers: gcc-multilib
    - libnuma-devel: 用於處理 NUMA (Non Uniform Memory Access).
    - Python, 版本 2.7+ 或 3.2+
- **系統軟體**
    - Kernel 版本 >= 3.2 (檢查方法： `uname -r`)
    - glibc >= 2.7 (檢查方法：`ldd --version`)
    - Kernel config: 應該啟用 DPDK 的選項
        - HUGETLBFS
        - PROC_PAGE_MONITOR support
        - HPET and HPET_MMAP (如果有用到 HPET 才要做)

#### 操作

- **0. 安裝 DPDK 的相依套件**
```sh
$ sudo apt-get -qq update
$ sudo apt-get -y -qq install clang doxygen hugepages build-essential libnuma-dev libpcap-dev inux-headers-`uname -r` dh-autoreconf libssl-dev libcap-ng-dev openssl python python-pip htop
$ sudo pip install six
```

- **1. 下載 DPDK 安裝包**
```sh
$ wget --quiet https://fast.dpdk.org/rel/dpdk-17.11.3.tar.xz
$ sudo tar xf dpdk-17.11.3.tar.xz -C /usr/src/
```

-  **2. 設定 DPDK 相關的環境變數**
```sh
echo 'export DPDK_DIR=/usr/src/dpdk-stable-17.11.3' | sudo tee -a /root/.bashrc
echo 'export LD_LIBRARY_PATH=$DPDK_DIR/x86_64-native-linuxapp-gcc/lib' | sudo tee -a /root/.bashrc
echo 'export DPDK_TARGET=x86_64-native-linuxapp-gcc' | sudo tee -a /root/.bashrc
echo 'export DPDK_BUILD=$DPDK_DIR/$DPDK_TARGET' | sudo tee -a /root/.bashrc
export DPDK_DIR=/usr/src/dpdk-stable-17.11.3
export DPDK_TARGET=x86_64-native-linuxapp-gcc
export DPDK_BUILD=$DPDK_DIR/$DPDK_TARGET
export LD_LIBRARY_PATH=$DPDK_DIR/x86_64-native-linuxapp-gcc/lib
```
> LD_LIBRARY_PATH: 如果 DPDK 是 shared library ，那這個環境變數是導出這個路徑給這個 lib 給 building OVS 用的

- **3. Build 與安裝 DPDK library**

```sh
$ cd $DPDK_DIR && sudo make install T=$DPDK_TARGET DESTDIR=install
```

- **4. 設定 DPDK 為 shared library**

```
$ sudo sed -i 's/CONFIG_RTE_BUILD_SHARED_LIB=n/CONFIG_RTE_BUILD_SHARED_LIB=y/g' ${DPDK_DIR}/config/common_base
```

### 3. 設定 Linux Drivers 的 kernel module
#### 說明

- 加 [UIO(Userspace IO)](https://github.com/torvalds/linux/tree/master/drivers/uio) 和 igb_uio 的 kernel module for driver。
- 另外修改 `ixgbe` driver ，讓它直接使用 VF。

- 參考
    - https://www.intel.com/content/dam/www/public/us/en/documents/technology-briefs/xl710-sr-iov-config-guide-gbe-linux-brief.pdf
    - https://doc.dpdk.org/guides-16.04/nics/intel_vf.html

#### 操作
##### UIO

- **加 driver 的 kernel modules，load uio kernel module**

[UIO(Userspace IO)](https://github.com/torvalds/linux/tree/master/drivers/uio) 是一個 kernel module ，來設定 device ，他會 map device memory 到 user-space ，並且 register interrupts。  
```sh
$ sudo modprobe uio
```

- **insert kmod/igb_uio  module 到 Linux Kernel**

因為DPDK 有支援 igb_uio ，而這個 module 可以在 kmod 這個子目錄下找到。  
(igb_uio 有支援 virtual function)  

```sh
$ sudo insmod ${DPDK_DIR}/x86_64-native-linuxapp-gcc/kmod/igb_uio.ko
```

PS. 與 UIO 相比，[VFIO](https://github.com/torvalds/linux/tree/master/drivers/vfio) driver 更加強大與安全(http://doc.dpdk.org/guides/linux_gsg/linux_drivers.html )。但這次不用。  

- **開機後還是可以 load UIO 的設定**
```sh
sudo ln -sf ${DPDK_DIR}/x86_64-native-linuxapp-gcc/kmod/igb_uio.ko /lib/modules/`uname -r`
sudo depmod -a
echo "uio" | sudo tee -a /etc/modules
echo "igb_uio" | sudo tee -a /etc/modules
```
##### ixgbe
> 參考：http://ask.xmodulo.com/download-install-ixgbe-driver-ubuntu-debian.html  

- 下載 [`ixgbe-5.3.7.tar.gz`](https://downloadcenter.intel.com/zh-tw/download/14687)

- 解壓縮與安裝
```sh
$ mkdir ~/ixgbe
$ tar xvfvz ixgbe-5.3.7.tar.gz -C ~/ixgbe
$ cd ~/ixgbe/ixgbe-5.3.7/src
$ sudo make
```

- 確認
```sh
$ modinfo ./ixgbe.ko
filename:       /home/cord/ixgbe/ixgbe-5.3.7/src/./ixgbe.ko
version:        5.3.7
license:        GPL
description:    Intel(R) 10GbE PCI Express Linux Network Driver
author:         Intel Corporation, <linux.nics@intel.com>
srcversion:     9E1B3824190E963083DADF5
alias:          pci:v00008086d000015E5sv*sd*bc*sc*i*
alias:          pci:v00008086d000015E4sv*sd*bc*sc*i*
alias:          pci:v00008086d000015CEsv*sd*bc*sc*i*
alias:          pci:v00008086d000015CCsv*sd*bc*sc*i*
alias:          pci:v00008086d000015CAsv*sd*bc*sc*i*
alias:          pci:v00008086d000015C8sv*sd*bc*sc*i*
alias:          pci:v00008086d000015C7sv*sd*bc*sc*i*
alias:          pci:v00008086d000015C6sv*sd*bc*sc*i*
alias:          pci:v00008086d000015C4sv*sd*bc*sc*i*
alias:          pci:v00008086d000015C3sv*sd*bc*sc*i*
alias:          pci:v00008086d000015C2sv*sd*bc*sc*i*
alias:          pci:v00008086d000015AEsv*sd*bc*sc*i*
alias:          pci:v00008086d000015ADsv*sd*bc*sc*i*
alias:          pci:v00008086d000015ACsv*sd*bc*sc*i*
alias:          pci:v00008086d000015ABsv*sd*bc*sc*i*
alias:          pci:v00008086d000015B0sv*sd*bc*sc*i*
alias:          pci:v00008086d000015AAsv*sd*bc*sc*i*
alias:          pci:v00008086d000015D1sv*sd*bc*sc*i*
alias:          pci:v00008086d00001563sv*sd*bc*sc*i*
alias:          pci:v00008086d00001560sv*sd*bc*sc*i*
alias:          pci:v00008086d00001558sv*sd*bc*sc*i*
alias:          pci:v00008086d0000154Asv*sd*bc*sc*i*
alias:          pci:v00008086d00001557sv*sd*bc*sc*i*
alias:          pci:v00008086d0000154Fsv*sd*bc*sc*i*
alias:          pci:v00008086d0000154Dsv*sd*bc*sc*i*
alias:          pci:v00008086d00001528sv*sd*bc*sc*i*
alias:          pci:v00008086d000010F8sv*sd*bc*sc*i*
alias:          pci:v00008086d0000151Csv*sd*bc*sc*i*
alias:          pci:v00008086d00001529sv*sd*bc*sc*i*
alias:          pci:v00008086d0000152Asv*sd*bc*sc*i*
alias:          pci:v00008086d000010F9sv*sd*bc*sc*i*
alias:          pci:v00008086d00001514sv*sd*bc*sc*i*
alias:          pci:v00008086d00001507sv*sd*bc*sc*i*
alias:          pci:v00008086d000010FBsv*sd*bc*sc*i*
alias:          pci:v00008086d00001517sv*sd*bc*sc*i*
alias:          pci:v00008086d000010FCsv*sd*bc*sc*i*
alias:          pci:v00008086d000010F7sv*sd*bc*sc*i*
alias:          pci:v00008086d00001508sv*sd*bc*sc*i*
alias:          pci:v00008086d000010DBsv*sd*bc*sc*i*
alias:          pci:v00008086d000010F4sv*sd*bc*sc*i*
alias:          pci:v00008086d000010E1sv*sd*bc*sc*i*
alias:          pci:v00008086d000010F1sv*sd*bc*sc*i*
alias:          pci:v00008086d000010ECsv*sd*bc*sc*i*
alias:          pci:v00008086d000010DDsv*sd*bc*sc*i*
alias:          pci:v00008086d0000150Bsv*sd*bc*sc*i*
alias:          pci:v00008086d000010C8sv*sd*bc*sc*i*
alias:          pci:v00008086d000010C7sv*sd*bc*sc*i*
alias:          pci:v00008086d000010C6sv*sd*bc*sc*i*
alias:          pci:v00008086d000010B6sv*sd*bc*sc*i*
depends:        ptp,dca
retpoline:      Y
name:           ixgbe
vermagic:       4.15.0-30-generic SMP mod_unload
parm:           EEE:Energy Efficient Ethernet (EEE) ,0=disabled, 1=enabled )default EEE disable (array of int)
parm:           InterruptType:Change Interrupt Mode (0=Legacy, 1=MSI, 2=MSI-X), default IntMode (deprecated) (array of int)
parm:           IntMode:Change Interrupt Mode (0=Legacy, 1=MSI, 2=MSI-X), default 2 (array of int)
parm:           MQ:Disable or enable Multiple Queues, default 1 (array of int)
parm:           DCA:Disable or enable Direct Cache Access, 0=disabled, 1=descriptor only, 2=descriptor and data (array of int)
parm:           RSS:Number of Receive-Side Scaling Descriptor Queues, default 0=number of cpus (array of int)
parm:           VMDQ:Number of Virtual Machine Device Queues: 0/1 = disable (1 queue) 2-16 enable (default=8) (array of int)
parm:           max_vfs:Number of Virtual Functions: 0 = disable (default), 1-63 = enable this many VFs (array of int)
parm:           VEPA:VEPA Bridge Mode: 0 = VEB (default), 1 = VEPA (array of int)
parm:           InterruptThrottleRate:Maximum interrupts per second, per vector, (0,1,956-488281), default 1 (array of int)
parm:           LLIPort:Low Latency Interrupt TCP Port (0-65535) (array of int)
parm:           LLIPush:Low Latency Interrupt on TCP Push flag (0,1) (array of int)
parm:           LLISize:Low Latency Interrupt on Packet Size (0-1500) (array of int)
parm:           LLIEType:Low Latency Interrupt Ethernet Protocol Type (array of int)
parm:           LLIVLANP:Low Latency Interrupt on VLAN priority threshold (array of int)
parm:           FdirPballoc:Flow Director packet buffer allocation level:
            1 = 8k hash filters or 2k perfect filters
            2 = 16k hash filters or 4k perfect filters
            3 = 32k hash filters or 8k perfect filters (array of int)
parm:           AtrSampleRate:Software ATR Tx packet sample rate (array of int)
parm:           FCoE:Disable or enable FCoE Offload, default 1 (array of int)
parm:           MDD:Malicious Driver Detection: (0,1), default 1 = on (array of int)
parm:           LRO:Large Receive Offload (0,1), default 0 = off (array of int)
parm:           allow_unsupported_sfp:Allow unsupported and untested SFP+ modules on 82599 based adapters, default 0 = Disable (array of int)
parm:           dmac_watchdog:DMA coalescing watchdog in microseconds (0,41-10000), default 0 = off (array of int)
parm:           vxlan_rx:VXLAN receive checksum offload (0,1), default 1 = Enable (array of int)
```

- Install Ixgbe Driver on your system & check
```sh
$ sudo make install
$ ls /lib/modules/`uname -r`/kernel/drivers/net/ethernet/intel
```

- **為兩個 ixgbe ports 創立兩個 vfs**

先 unload Linux ixgbe driver modules ，再設定 `max_vfs=2,2` 並 reload 它。  

```sh
sudo rmmod ixgbe
sudo modprobe ixgbe max_vfs=2,2
```

- **開機後還是可以 load ixgbe 的設定**
```sh
echo "options ixgbe max_vfs=2,2" | sudo tee -a /etc/modprobe.d/ixgbe.conf
```


- 驗證 VF 是否 ok
```sh
$ lspci | grep -i 'Virtual Function'
01:10.0 Ethernet controller: Intel Corporation 82599 Ethernet Controller Virtual Function (rev 01)
01:10.1 Ethernet controller: Intel Corporation 82599 Ethernet Controller Virtual Function (rev 01)
01:10.2 Ethernet controller: Intel Corporation 82599 Ethernet Controller Virtual Function (rev 01)
01:10.3 Ethernet controller: Intel Corporation 82599 Ethernet Controller Virtual Function (rev 01)
$ ip link show
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
2: enp8s0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP mode DEFAULT group default qlen 1000
    link/ether cc:37:ab:e1:21:64 brd ff:ff:ff:ff:ff:ff
3: enp9s0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc mq state DOWN mode DEFAULT group default qlen 1000
    link/ether cc:37:ab:e1:21:65 brd ff:ff:ff:ff:ff:ff
6: ens11f0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc mq state DOWN mode DEFAULT group default qlen 1000
    link/ether cc:37:ab:dd:f2:69 brd ff:ff:ff:ff:ff:ff
    vf 0 MAC 00:00:00:00:00:00, spoof checking on, link-state auto
    vf 1 MAC 00:00:00:00:00:00, spoof checking on, link-state auto
7: eth1: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/ether 62:33:90:12:89:bb brd ff:ff:ff:ff:ff:ff
8: eth2: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/ether 4a:7c:fa:22:49:0f brd ff:ff:ff:ff:ff:ff
9: ens11f1: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc mq state DOWN mode DEFAULT group default qlen 1000
    link/ether cc:37:ab:dd:f2:6a brd ff:ff:ff:ff:ff:ff
    vf 0 MAC 00:00:00:00:00:00, spoof checking on, link-state auto
    vf 1 MAC 00:00:00:00:00:00, spoof checking on, link-state auto
10: eth0: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/ether 0a:a3:f8:65:06:0b brd ff:ff:ff:ff:ff:ff
11: eth3: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN mode DEFAULT group default qlen 1000
    link/ether 16:f1:61:38:ee:c0 brd ff:ff:ff:ff:ff:ff
```

### 4. 綁定 Network Ports 到 Kernel Modules

`usertools/dpdk-devbind.py` (a utility script) 可以用來綁定 port 到  igb_uio module ，這樣就可以使用 DPDK 囉！想知道更多可以使用 `--help` 或 `--usage`  

- **1. 查看 network ports 的狀態**
```sh

$ ${DPDK_DIR}/usertools/dpdk-devbind.py --status
Network devices using DPDK-compatible driver
============================================
<none>

Network devices using kernel driver
===================================
0000:01:00.0 '82599ES 10-Gigabit SFI/SFP+ Network Connection 10fb' if=ens11f0 drv=ixgbe unused=igb_uio
0000:01:00.1 '82599ES 10-Gigabit SFI/SFP+ Network Connection 10fb' if=ens11f1 drv=ixgbe unused=igb_uio
0000:01:10.0 '82599 Ethernet Controller Virtual Function 10ed' if=eth0 drv=ixgbevf unused=igb_uio
0000:01:10.1 '82599 Ethernet Controller Virtual Function 10ed' if=eth1 drv=ixgbevf unused=igb_uio
0000:01:10.2 '82599 Ethernet Controller Virtual Function 10ed' if=eth3 drv=ixgbevf unused=igb_uio
0000:01:10.3 '82599 Ethernet Controller Virtual Function 10ed' if=eth2 drv=ixgbevf unused=igb_uio
0000:08:00.0 'I210 Gigabit Network Connection 1533' if=enp8s0 drv=igb unused=igb_uio *Active*
0000:09:00.0 'I210 Gigabit Network Connection 1533' if=enp9s0 drv=igb unused=igb_uio

Other Network devices
=====================
<none>

Crypto devices using DPDK-compatible driver
===========================================
<none>

Crypto devices using kernel driver
==================================
<none>

Other Crypto devices
====================
<none>

Eventdev devices using DPDK-compatible driver
=============================================
<none>

Eventdev devices using kernel driver
====================================
<none>

Other Eventdev devices
======================
<none>

Mempool devices using DPDK-compatible driver
============================================
<none>

Mempool devices using kernel driver
===================================
<none>

Other Mempool devices
=====================
<none>
```

- **2. 設定前先把 interface 改成 down**

(如果 interface 已經是 Down ，這步可以跳過)  
```
$ sudo ifconfig enp9s0 down
$ sudo ifconfig ens11f0 down
```

- **3. 綁定 device `enp9s0` & `ens11f0` 到 igb_uio**
```sh
$ sudo ${DPDK_DIR}/usertools/dpdk-devbind.py --bind=igb_uio enp9s0
$ sudo ${DPDK_DIR}/usertools/dpdk-devbind.py --bind=igb_uio ens11f0
```

- 使用 DPDK PMD PF driver時，插入 DPDK kernel mofule `igb_uio` 並按 `sysfs max_vfs` 設置 `VF` 數：

> SR-IOV 的
```sh
echo 2 > /sys/bus/pci/devices/0000\:01\:00.0/max_vfs
```

- **5. 再看一次 network interface**
```sh
$ ./usertools/dpdk-devbind.py --status
```

### 5. 安裝支援 DPDK 的 `OVS` 在 host 上

- **安裝必要的 pip 套件**
```sh
$ sudo pip install six
```

- **1. 下載 OVS 安裝包**
```sh
$ cd ~/
$ wget --quiet http://openvswitch.org/releases/openvswitch-2.9.2.tar.gz
$4 sudo tar -zxf openvswitch-2.9.2.tar.gz -C /usr/src/
```

- **設定 OVS_DIR 環境變數**
```sh
$ export OVS_DIR=/usr/src/openvswitch-2.9.2
```

- **編譯 OVS**
```sh
cd $OVS_DIR
./boot.sh
CFLAGS='-march=native' ./configure --prefix=/usr --localstatedir=/var --sysconfdir=/etc --with-dpdk=$DPDK_BUILD
make && sudo make install
sudo mkdir -p /etc/openvswitch
sudo mkdir -p /var/run/openvswitch
sudo mkdir -p /var/log/openvswitch
```

- **新增一個 ovsdb**
```sh
$ sudo ovsdb-tool create /etc/openvswitch/conf.db vswitchd/vswitch.ovsschema
```

- **關機後可以用 OVS**
```
$ echo 'export PATH=$PATH:/usr/local/share/openvswitch/scripts' | sudo tee -a /root/.bashrc
$ echo "openvswitch" | sudo tee -a /etc/modules
```
### 6. Setup Open vSwitch

> http://docs.openvswitch.org/en/latest/intro/install/dpdk/#setup-ovs

- **1. 設定 Open vSwitch 的遠端 database server**
```
$ ovsdb-server --remote=punix:/var/run/openvswitch/db.sock --remote=db:Open_vSwitch,Open_vSwitch,manager_options --pidfile --detach --log-file
```
- **2. 設定 ovs-vswitchd**
> http://www.openvswitch.org/support/dist-docs/ovs-vswitchd.conf.db.5.txt  

- init ovs-vswitchd
```sh
$ ovs-vsctl --no-wait init
```

- DPDK 的參數傳遞給 ovs-vswitchd ，透過 `Open_vSwitch` table 的 `other_config` 欄位。
    - the dpdk-init option must be set to either `true` or `try`
```sh
$ ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-init=true
```

- 從預先配置的 hugepage pool 中指定要給的 memory 量，on a per-socket basis。
```sh
$ ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-socket-mem="1024"
```

- 設定 cpu affinity 的 PMD  (Poll Mode Driver) threads 透過特定的 CPU mask
    - hex string
    - 最低位對應於第一個 CPU core。
```
$ ovs-vsctl --no-wait set Open_vSwitch . other_config:pmd-cpu-mask=0x2
```

- idle 的 flows 在 datapath 中 cached 的最大時間(in ms)
    - default is 10000
    - at least 500
```sh
$ ovs-vsctl --no-wait set Open_vSwitch . other_config:max-idle=30000
```

- **[Open vSwitch daemon](http://www.openvswitch.org/support/dist-docs/ovs-vswitchd.8.html) 設定**
```sh
$ ovs-vswitchd  unix:/var/run/openvswitch/db.sock --pidfile --detach --log-file
```

### 7. 建立 OVS 的 bridge
- create a userspace bridge named br0 and add two dpdk ports to it
    - datapath_type: 是 datapath provider 的名稱。
        - userspace datapath type: `netdev`
        - kernel datapath type: `system`
    - dpdk-devargs: 指定物理 driver 的 PCI address 或是 virtual driver 的 virtual PMD. 可以用 `cd $DPDK_DIR &&./usertools/dpdk-devbind.py --status` 查。(在 VM 這邊查到的名稱是 0000:00:09.0)

```sh
$ ovs-vsctl add-br br0 -- set bridge br0 datapath_type=netdev
$ ovs-vsctl add-port br0 dpdk0 -- set Interface dpdk0 type=dpdk options:dpdk-devargs=0000:00:09.0
```
  
== 設定完成 ==  
使用 `htop` 可以看到第二顆 CPU core 用到 100%  


### 8. 安裝 Docker + Kubernetes + helm 等

### 9. Multus CNI
#### 說明

- **使用到的 CNI**
    - Multus CNI: https://github.com/intel/multus-cni
    - SR-IOV: https://github.com/intel/sriov-cni
    - OVS-DPDK + CNI: https://github.com/intel/vhost-user-net-plugin

- **參考**
    - http://www.txtlxg.com/blog.csdn.net/cloudvtech/article/details/80221988

#### 操作

### 10. ONOS with k8s

### 11. 先測 podd 在 ovs bridge 底下的互通情形

### 12. 讓 OVS 給 ONOS 管理的測試

## 其他
依據 http://docs.openvswitch.org/en/latest/intro/install/dpdk/#setup-dpdk-devices-using-vfio + https://www.jianshu.com/p/9bf690956d7d + https://doc.dpdk.org/guides-16.04/nics/intel_vf.html 看來可以 DPDK-OVS 把封包直接跳過 linux kernel 給 user space 處理，然後在 OVS 和實體網卡中間的通道使用 SR-IOV 。

## 參考
- https://github.com/sufuf3/network-study-notes/tree/master/DPDK_OVS
- https://access.redhat.com/documentation/zh-cn/red_hat_enterprise_linux_openstack_platform/7/html/networking_guide/sec-sr-iov
- https://www.intel.com/content/dam/www/public/us/en/documents/technology-briefs/xl710-sr-iov-config-guide-gbe-linux-brief.pdf
- https://docs.openstack.org/liberty/networking-guide/adv-config-sriov.html
- https://blog.pichuang.com.tw/nfv-sr-iov/#more-61
- https://github.com/sufuf3/kubecord/tree/master/developers
- http://connect.linaro.org.s3.amazonaws.com/hkg18/presentations/hkg18-121.pdf
- https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/6/html/virtualization_host_configuration_and_guest_installation_guide/sect-virtualization_host_configuration_and_guest_installation_guide-sr_iov-how_sr_iov_libvirt_works
- https://doc.dpdk.org/guides-16.04/nics/intel_vf.html
