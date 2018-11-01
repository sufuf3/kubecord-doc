# 網路相關環境資訊蒐集

## Table of Contents

- [前言](#前言)
- [Network interface chack](#network-interface-chack)
- [Interface driver module](#interface-driver-module)
- [網卡資訊](#網卡資訊)
- [Hugepage Check](#hugepage-check)

## 前言
因為我們要做加速 data plant 的功能，所以針對網卡，我們要多搜集一點資訊。

- 加速 data plant
    - DPDK
    - SR-IOV

## Network interface chack

兩台除了 eno1 這個 interface 的 IP 設定不一樣外，其他的都一樣。

```sh
$ ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: ens6f0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq portid 3cfdfebafa98 state UP group default qlen 1000
    link/ether 3c:fd:fe:ba:fa:98 brd ff:ff:ff:ff:ff:ff
    inet6 fe80::3efd:feff:feba:fa98/64 scope link
       valid_lft forever preferred_lft forever
3: ens6f1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq portid 3cfdfebafa99 state UP group default qlen 1000
    link/ether 3c:fd:fe:ba:fa:99 brd ff:ff:ff:ff:ff:ff
    inet6 fe80::3efd:feff:feba:fa99/64 scope link
       valid_lft forever preferred_lft forever
4: eno1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether a8:1e:84:a1:da:0c brd ff:ff:ff:ff:ff:ff
    inet 192.168.60.5/25 brd 192.168.60.127 scope global eno1
       valid_lft forever preferred_lft forever
    inet6 fe80::aa1e:84ff:fea1:da0c/64 scope link
       valid_lft forever preferred_lft forever
5: ens6f2: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc mq portid 3cfdfebafa9a state DOWN group default qlen 1000
    link/ether 3c:fd:fe:ba:fa:9a brd ff:ff:ff:ff:ff:ff
6: ens6f3: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc mq portid 3cfdfebafa9b state DOWN group default qlen 1000
    link/ether 3c:fd:fe:ba:fa:9b brd ff:ff:ff:ff:ff:ff
7: eno2: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc mq state DOWN group default qlen 1000
    link/ether a8:1e:84:a1:da:0d brd ff:ff:ff:ff:ff:ff
8: enp4s0f0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc mq state DOWN group default qlen 1000
    link/ether a8:1e:84:a1:dc:71 brd ff:ff:ff:ff:ff:ff
9: enp4s0f1: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc mq state DOWN group default qlen 1000
    link/ether a8:1e:84:a1:dc:72 brd ff:ff:ff:ff:ff:ff
```

## Interface driver module

如果我們要用 DPDK 我們要先知道 driver module 是用什麼，這樣當我們要從 DPDK 用的 module 改回原本的，就可以直接使用原本的 driver module。

```sh
$ ethtool -i ens6f0 | grep ^driver
driver: i40e
$ ethtool -i ens6f1 | grep ^driver
driver: i40e
$ ethtool -i eno1 | grep ^driver
driver: ixgbe
$ ethtool -i eno2 | grep ^driver
driver: ixgbe
$ ethtool -i ens6f2 | grep ^driver
driver: i40e
$ ethtool -i ens6f3 | grep ^driver
driver: i40e
$ ethtool -i enp4s0f0 | grep ^driver
driver: ixgbe
$ ethtool -i enp4s0f1 | grep ^driver
driver: ixgbe
```

## 網卡資訊

看一下網卡是什麼廠牌，才可以 google 那張網卡有沒有支援 SR-IOV 的 VF 功能。

```sh
$ lspci | grep -i Ethernet
01:00.0 Ethernet controller: Intel Corporation Ethernet Controller 10-Gigabit X540-AT2 (rev 01)
01:00.1 Ethernet controller: Intel Corporation Ethernet Controller 10-Gigabit X540-AT2 (rev 01)
04:00.0 Ethernet controller: Intel Corporation Ethernet Controller 10-Gigabit X540-AT2 (rev 01)
04:00.1 Ethernet controller: Intel Corporation Ethernet Controller 10-Gigabit X540-AT2 (rev 01)
83:00.0 Ethernet controller: Intel Corporation Ethernet Controller X710 for 10GbE SFP+ (rev 01)
83:00.1 Ethernet controller: Intel Corporation Ethernet Controller X710 for 10GbE SFP+ (rev 01)
83:00.2 Ethernet controller: Intel Corporation Ethernet Controller X710 for 10GbE SFP+ (rev 01)
83:00.3 Ethernet controller: Intel Corporation Ethernet Controller X710 for 10GbE SFP+ (rev 01)

$ sudo lshw -class network -businfo
Bus info          Device     Class          Description
=======================================================
pci@0000:01:00.0  eno1       network        Ethernet Controller 10-Gigabit X540-AT2
pci@0000:01:00.1  eno2       network        Ethernet Controller 10-Gigabit X540-AT2
pci@0000:04:00.0  enp4s0f0   network        Ethernet Controller 10-Gigabit X540-AT2
pci@0000:04:00.1  enp4s0f1   network        Ethernet Controller 10-Gigabit X540-AT2
pci@0000:83:00.0  ens6f0     network        Ethernet Controller X710 for 10GbE SFP+
pci@0000:83:00.1  ens6f1     network        Ethernet Controller X710 for 10GbE SFP+
pci@0000:83:00.2  ens6f2     network        Ethernet Controller X710 for 10GbE SFP+
pci@0000:83:00.3  ens6f3     network        Ethernet Controller X710 for 10GbE SFP+
```

## Hugepage Check

因為 DPDK 是要用到 Hugepage 來佔滿 CPU 用的 Hugepage 做加速。所以我們要來看看可不可以用到比較大的 Hugepage。

```sh
$ ls /sys/devices/system/node/node[0-9]*/hugepages/
/sys/devices/system/node/node0/hugepages/:
hugepages-1048576kB  hugepages-2048kB

/sys/devices/system/node/node1/hugepages/:
hugepages-1048576kB  hugepages-2048kB
```
