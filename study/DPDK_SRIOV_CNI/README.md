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
  + [6. 建立 OVS 的 bridge](#6-建立-ovs-的-bridge)
  + [7. 安裝 Docker + Kubernetes + helm 等](#7-安裝-docker--kubernetes--helm-等)
  + [8. Multus CNI](#8-multus-cni)
  + [9. ONOS with k8s](#9-onos-with-k8s)
  + [10. 先測 podd 在 ovs bridge 底下的互通情形](#10-先測-podd-在-ovs-bridge-底下的互通情形)
  + [11. 讓 OVS 給 ONOS 管理的測試](#11-讓-ovs-給-onos-管理的測試)
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
- 先把原本的檔案做個備份
```sh
$ sudo cp /etc/default/grub /etc/default/grub.old
```

- 確認已經有 enable VT-d
```sh
$ cat /proc/cpuinfo | grep vmx
```

- 查看原本的 hugepage 配置
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

- 編輯 /etc/default/grub
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

- Update grub
```sh
$ sudo update-grub
Generating grub configuration file ...
Found linux image: /boot/vmlinuz-4.15.0-30-generic
Found initrd image: /boot/initrd.img-4.15.0-30-generic
done
```

- 重啟主機
```sh
$ reboot
```

- 確認 /proc/cmdline
```sh
$ cat /proc/cmdline
BOOT_IMAGE=/boot/vmlinuz-4.15.0-30-generic root=UUID=6dd5050f-5f5c-4b0f-8672-507b4161feaa ro transparent_hugepage=never default_hugepagesz=1G hugepagesz=1G hugepages=8 iommu=pt intel_iommu=on
```
- 確認使用 8 個 1G size 的 Hugepage
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

- 確認 IOMMU
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

- Setting hugepage number
```sh
$ echo 'vm.nr_hugepages=8' | sudo tee /etc/sysctl.d/hugepages.conf
```

- Mount hugepages
```sh
$ sudo mount -t hugetlbfs none /dev/hugepages
```

- 設定 kernel 變數在執行的時候
```sh
$ sudo sysctl -w vm.nr_hugepages=8
```

### 2. 安裝 DPDK

### 3. 設定 Linux Drivers 的 kernel module

### 4. 綁定 Network Ports 到 Kernel Modules

### 5. 安裝支援 DPDK 的 `OVS` 在 host 上

### 6. 建立 OVS 的 bridge

### 7. 安裝 Docker + Kubernetes + helm 等

### 8. Multus CNI

### 9. ONOS with k8s

### 10. 先測 podd 在 ovs bridge 底下的互通情形

### 11. 讓 OVS 給 ONOS 管理的測試

## 其他
依據 http://docs.openvswitch.org/en/latest/intro/install/dpdk/#setup-dpdk-devices-using-vfio 看來可以 DPDK-OVS 把封包直接跳過 linux kernel 給 user space 處理，然後在 OVS 和實體網卡中間的通道使用 SR-IOV 。

## 參考
- https://github.com/sufuf3/network-study-notes/tree/master/DPDK_OVS
- https://access.redhat.com/documentation/zh-cn/red_hat_enterprise_linux_openstack_platform/7/html/networking_guide/sec-sr-iov
- https://www.intel.com/content/dam/www/public/us/en/documents/technology-briefs/xl710-sr-iov-config-guide-gbe-linux-brief.pdf
- https://docs.openstack.org/liberty/networking-guide/adv-config-sriov.html
- https://blog.pichuang.com.tw/nfv-sr-iov/#more-61
- https://github.com/sufuf3/kubecord/tree/master/developers
