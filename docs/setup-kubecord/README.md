# 安裝 Kubecord 操作手冊

## Table of Contents

- [什麼是 kubecord](#什麼是-kubecord)
- [安裝說明](#安裝說明)
- [安裝流程](#安裝流程)
- [硬體與 OS 環境](#硬體與-os-環境)

## 什麼是 kubecord

- 是一個 k8s 叢集，可支援多個 network interfaces pod
- 包含 data plant 的加速技術在其中，包含 DPDK, SR-IOV
- 包含 SDN 技術，包含 OVS 與 ONOS

## 安裝說明
安裝 kubecord 在兩台實體主機。兩台實體主機的規格和 OS 都一模一樣。

## 安裝流程

- [硬體與 OS 環境確認](#硬體與-os-環境)
- [網路相關環境資訊蒐集](env.md)
- [grub 設定檔配置](grub.md)
- [安裝 DPDK](dpdk.md)
- [設定 SR-IOV 的 VF 數量](set-sr-iov.md)

## 硬體與 OS 環境

- **Memory**

```sh
$ free -h
              total        used        free      shared  buff/cache   available
Mem:           125G        9.0G        115G         17M        1.4G        115G
Swap:          8.0G          0B        8.0G
```

- **CPU**

```sh
$ lscpu
Architecture:          x86_64
CPU op-mode(s):        32-bit, 64-bit
Byte Order:            Little Endian
CPU(s):                40
On-line CPU(s) list:   0-39
Thread(s) per core:    2
Core(s) per socket:    10
Socket(s):             2
NUMA node(s):          2
Vendor ID:             GenuineIntel
CPU family:            6
Model:                 79
Model name:            Intel(R) Xeon(R) CPU E5-2630 v4 @ 2.20GHz
Stepping:              1
CPU MHz:               1197.633
CPU max MHz:           3100.0000
CPU min MHz:           1200.0000
BogoMIPS:              4393.31
Virtualization:        VT-x
L1d cache:             32K
L1i cache:             32K
L2 cache:              256K
L3 cache:              25600K
NUMA node0 CPU(s):     0-9,20-29
NUMA node1 CPU(s):     10-19,30-39
Flags:                 fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc arch_perfmon pebs bts rep_good nopl xtopology nonstop_tsc cpuid aperfmperf pni pclmulqdq dtes64 monitor ds_cpl vmx smx est tm2 ssse3 sdbg fma cx16 xtpr pdcm pcid dca sse4_1 sse4_2 x2apic movbe popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm abm 3dnowprefetch cpuid_fault epb cat_l3 cdp_l3 invpcid_single pti intel_ppin ssbd ibrs ibpb stibp tpr_shadow vnmi flexpriority ept vpid fsgsbase tsc_adjust bmi1 hle avx2 smep bmi2 erms invpcid rtm cqm rdt_a rdseed adx smap intel_pt xsaveopt cqm_llc cqm_occup_llc cqm_mbm_total cqm_mbm_local dtherm ida arat pln pts flush_l1d


```

- **Disk**

```sh
$ sudo fdisk -l
Disk /dev/sda: 557.9 GiB, 599013720064 bytes, 1169948672 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 262144 bytes / 524288 bytes
Disklabel type: gpt
Disk identifier: 487F194A-08A6-4391-B1D8-XXXXXXXXXX2

Device       Start        End    Sectors   Size Type
/dev/sda1     2048    1050623    1048576   512M EFI System
/dev/sda2  1050624 1169948638 1168898015 557.4G Linux filesystem

$ df -h
Filesystem      Size  Used Avail Use% Mounted on
udev             59G     0   59G   0% /dev
tmpfs            13G   18M   13G   1% /run
/dev/sda2       549G   11G  510G   3% /
tmpfs            63G     0   63G   0% /dev/shm
tmpfs           5.0M     0  5.0M   0% /run/lock
tmpfs            63G     0   63G   0% /sys/fs/cgroup
/dev/sda1       511M  3.4M  508M   1% /boot/efi
tmpfs            13G     0   13G   0% /run/user/1000
```

- **網卡**

```
$ lspci | grep -i Ethernet
01:00.0 Ethernet controller: Intel Corporation Ethernet Controller 10-Gigabit X540-AT2 (rev 01)
01:00.1 Ethernet controller: Intel Corporation Ethernet Controller 10-Gigabit X540-AT2 (rev 01)
04:00.0 Ethernet controller: Intel Corporation Ethernet Controller 10-Gigabit X540-AT2 (rev 01)
04:00.1 Ethernet controller: Intel Corporation Ethernet Controller 10-Gigabit X540-AT2 (rev 01)
83:00.0 Ethernet controller: Intel Corporation Ethernet Controller X710 for 10GbE SFP+ (rev 01)
83:00.1 Ethernet controller: Intel Corporation Ethernet Controller X710 for 10GbE SFP+ (rev 01)
83:00.2 Ethernet controller: Intel Corporation Ethernet Controller X710 for 10GbE SFP+ (rev 01)
83:00.3 Ethernet controller: Intel Corporation Ethernet Controller X710 for 10GbE SFP+ (rev 01)
```

- **OS**

```sh
$ cat /etc/lsb-release
DISTRIB_ID=Ubuntu
DISTRIB_RELEASE=16.04
DISTRIB_CODENAME=xenial
DISTRIB_DESCRIPTION="Ubuntu 16.04.5 LTS"

$ uname -sr
Linux 4.15.0-36-generic
```

