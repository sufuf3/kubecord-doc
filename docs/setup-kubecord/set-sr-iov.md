# 設定 SR-IOV 的 VF 數量

## Table of Contents

- [設定 i40e 的網卡支援 30 個 VF](#設定-i40e-的網卡支援-30-個-vf)
- [檢查](#檢查)
- [備註](#備註)

## 設定 i40e 的網卡支援 30 個 VF

```sh
echo "options i40e max_vfs=30,30" | sudo tee -a /etc/modprobe.d/i40e.conf
sudo rmmod i40e
sudo modprobe i40e max_vfs=30,30
echo 30 | sudo tee -a /sys/class/net/ens6f0/device/sriov_numvfs
echo 30 | sudo tee -a /sys/class/net/ens6f1/device/sriov_numvfs
```

## 檢查

```sh
$ lspci | grep -i 'Virtual Function'
83:02.0 Ethernet controller: Intel Corporation XL710/X710 Virtual Function (rev 01)
83:02.1 Ethernet controller: Intel Corporation XL710/X710 Virtual Function (rev 01)
83:02.2 Ethernet controller: Intel Corporation XL710/X710 Virtual Function (rev 01)
83:02.3 Ethernet controller: Intel Corporation XL710/X710 Virtual Function (rev 01)
83:02.4 Ethernet controller: Intel Corporation XL710/X710 Virtual Function (rev 01)
83:02.5 Ethernet controller: Intel Corporation XL710/X710 Virtual Function (rev 01)
83:02.6 Ethernet controller: Intel Corporation XL710/X710 Virtual Function (rev 01)
83:02.7 Ethernet controller: Intel Corporation XL710/X710 Virtual Function (rev 01)
83:03.0 Ethernet controller: Intel Corporation XL710/X710 Virtual Function (rev 01)
83:03.1 Ethernet controller: Intel Corporation XL710/X710 Virtual Function (rev 01)
83:03.2 Ethernet controller: Intel Corporation XL710/X710 Virtual Function (rev 01)
83:03.3 Ethernet controller: Intel Corporation XL710/X710 Virtual Function (rev 01)
83:03.4 Ethernet controller: Intel Corporation XL710/X710 Virtual Function (rev 01)
83:03.5 Ethernet controller: Intel Corporation XL710/X710 Virtual Function (rev 01)
83:03.6 Ethernet controller: Intel Corporation XL710/X710 Virtual Function (rev 01)
83:03.7 Ethernet controller: Intel Corporation XL710/X710 Virtual Function (rev 01)
83:04.0 Ethernet controller: Intel Corporation XL710/X710 Virtual Function (rev 01)
83:04.1 Ethernet controller: Intel Corporation XL710/X710 Virtual Function (rev 01)
83:04.2 Ethernet controller: Intel Corporation XL710/X710 Virtual Function (rev 01)
83:04.3 Ethernet controller: Intel Corporation XL710/X710 Virtual Function (rev 01)
83:04.4 Ethernet controller: Intel Corporation XL710/X710 Virtual Function (rev 01)
83:04.5 Ethernet controller: Intel Corporation XL710/X710 Virtual Function (rev 01)
83:04.6 Ethernet controller: Intel Corporation XL710/X710 Virtual Function (rev 01)
83:04.7 Ethernet controller: Intel Corporation XL710/X710 Virtual Function (rev 01)
83:05.0 Ethernet controller: Intel Corporation XL710/X710 Virtual Function (rev 01)
83:05.1 Ethernet controller: Intel Corporation XL710/X710 Virtual Function (rev 01)
83:05.2 Ethernet controller: Intel Corporation XL710/X710 Virtual Function (rev 01)
83:05.3 Ethernet controller: Intel Corporation XL710/X710 Virtual Function (rev 01)
83:05.4 Ethernet controller: Intel Corporation XL710/X710 Virtual Function (rev 01)
83:05.5 Ethernet controller: Intel Corporation XL710/X710 Virtual Function (rev 01)
83:06.0 Ethernet controller: Intel Corporation XL710/X710 Virtual Function (rev 01)
83:06.1 Ethernet controller: Intel Corporation XL710/X710 Virtual Function (rev 01)
83:06.2 Ethernet controller: Intel Corporation XL710/X710 Virtual Function (rev 01)
83:06.3 Ethernet controller: Intel Corporation XL710/X710 Virtual Function (rev 01)
83:06.4 Ethernet controller: Intel Corporation XL710/X710 Virtual Function (rev 01)
83:06.5 Ethernet controller: Intel Corporation XL710/X710 Virtual Function (rev 01)
83:06.6 Ethernet controller: Intel Corporation XL710/X710 Virtual Function (rev 01)
83:06.7 Ethernet controller: Intel Corporation XL710/X710 Virtual Function (rev 01)
83:07.0 Ethernet controller: Intel Corporation XL710/X710 Virtual Function (rev 01)
83:07.1 Ethernet controller: Intel Corporation XL710/X710 Virtual Function (rev 01)
83:07.2 Ethernet controller: Intel Corporation XL710/X710 Virtual Function (rev 01)
83:07.3 Ethernet controller: Intel Corporation XL710/X710 Virtual Function (rev 01)
83:07.4 Ethernet controller: Intel Corporation XL710/X710 Virtual Function (rev 01)
83:07.5 Ethernet controller: Intel Corporation XL710/X710 Virtual Function (rev 01)
83:07.6 Ethernet controller: Intel Corporation XL710/X710 Virtual Function (rev 01)
83:07.7 Ethernet controller: Intel Corporation XL710/X710 Virtual Function (rev 01)
83:08.0 Ethernet controller: Intel Corporation XL710/X710 Virtual Function (rev 01)
83:08.1 Ethernet controller: Intel Corporation XL710/X710 Virtual Function (rev 01)
83:08.2 Ethernet controller: Intel Corporation XL710/X710 Virtual Function (rev 01)
83:08.3 Ethernet controller: Intel Corporation XL710/X710 Virtual Function (rev 01)
83:08.4 Ethernet controller: Intel Corporation XL710/X710 Virtual Function (rev 01)
83:08.5 Ethernet controller: Intel Corporation XL710/X710 Virtual Function (rev 01)
83:08.6 Ethernet controller: Intel Corporation XL710/X710 Virtual Function (rev 01)
83:08.7 Ethernet controller: Intel Corporation XL710/X710 Virtual Function (rev 01)
83:09.0 Ethernet controller: Intel Corporation XL710/X710 Virtual Function (rev 01)
83:09.1 Ethernet controller: Intel Corporation XL710/X710 Virtual Function (rev 01)
83:09.2 Ethernet controller: Intel Corporation XL710/X710 Virtual Function (rev 01)
83:09.3 Ethernet controller: Intel Corporation XL710/X710 Virtual Function (rev 01)
83:09.4 Ethernet controller: Intel Corporation XL710/X710 Virtual Function (rev 01)
83:09.5 Ethernet controller: Intel Corporation XL710/X710 Virtual Function (rev 01)

$ ip link show
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
5: eno1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP mode DEFAULT group default qlen 1000
    link/ether a8:1e:84:a1:da:0c brd ff:ff:ff:ff:ff:ff
7: eno2: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc mq state DOWN mode DEFAULT group default qlen 1000
    link/ether a8:1e:84:a1:da:0d brd ff:ff:ff:ff:ff:ff
8: enp4s0f0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc mq state DOWN mode DEFAULT group default qlen 1000
    link/ether a8:1e:84:a1:dc:71 brd ff:ff:ff:ff:ff:ff
9: enp4s0f1: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc mq state DOWN mode DEFAULT group default qlen 1000
    link/ether a8:1e:84:a1:dc:72 brd ff:ff:ff:ff:ff:ff
78: ens6f0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq portid 3cfdfebafa98 state UP mode DEFAULT group default qlen 1000
    link/ether 3c:fd:fe:ba:fa:98 brd ff:ff:ff:ff:ff:ff
    vf 0 MAC 00:00:00:00:00:00, spoof checking on, link-state auto
    vf 1 MAC 00:00:00:00:00:00, spoof checking on, link-state auto
    vf 2 MAC 00:00:00:00:00:00, spoof checking on, link-state auto
    vf 3 MAC 00:00:00:00:00:00, spoof checking on, link-state auto
    vf 4 MAC 00:00:00:00:00:00, spoof checking on, link-state auto
    vf 5 MAC 00:00:00:00:00:00, spoof checking on, link-state auto
    vf 6 MAC 00:00:00:00:00:00, spoof checking on, link-state auto
    vf 7 MAC 00:00:00:00:00:00, spoof checking on, link-state auto
    vf 8 MAC 00:00:00:00:00:00, spoof checking on, link-state auto
    vf 9 MAC 00:00:00:00:00:00, spoof checking on, link-state auto
    vf 10 MAC 00:00:00:00:00:00, spoof checking on, link-state auto
```

## 備註
如果 i40e 網卡在遇到 rmmod 與 modprobe 遇到問題，可以重安裝 driver (從 https://downloadcenter.intel.com/download/24411/Intel-Network-Adapter-Driver-for-PCIe-40-Gigabit-Ethernet-Network-Connections-Under-Linux- 下載)。

```sh
$ mkdir ~/i40e
$ tar xvfvz i40e-2.4.10.tar.gz -C ~/i40e
$ cd ~/i40e/i40e-2.4.10/src
$ sudo make
$ sudo make install
$ ls /lib/modules/`uname -r`/kernel/drivers/net/ethernet/intel
```

