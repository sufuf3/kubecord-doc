# grub 設定檔配置

## Table of Contents

- [前言](#前言)
- [編輯 `/etc/default/grub`](#編輯-etcdefaultgrub)
    + [**先把原本的設定檔存一份到 grub.old**](#先把原本的設定檔存一份到-grubold)
    + [**編輯 `/etc/default/grub`**](#編輯-etcdefaultgrub-1)
- [Update grub](#update-grub)
- [重開機](#重開機)
- [確認系統](#確認系統)
    + [確認 Hugepage](#確認-hugepage)
    + [確認 SR-IOV 功能](#確認-sr-iov-功能)
- [Mount Hugepage 等](#mount-hugepage-等)



## 前言

- 在上一步驟我們知道這兩台電腦有支援 1G 的 Hugepage，DPDK 會使用 Hugepage。
- 我們查到這幾張網卡都可以開啟 SR-IOV 功能

所以我們就在一裝好機器，趕緊來改 grub 這份開機設定檔，讓主機在沒有任何的 APP 在上面跑的狀態下，趕緊來使用完整的 1G 的 Hugepage。並且讓這兩台主機能夠奕開機就是使用 1G 的 Hugepage (給 DPDK 使用) 以及開啟 SR-IOV 功能。  

## 編輯 `/etc/default/grub`

#### **先把原本的設定檔存一份到 grub.old**

```sh
$ cp /etc/default/grub /etc/default/grub.old
```

#### **編輯 `/etc/default/grub`**

```sh
GRUB_DEFAULT=0
GRUB_HIDDEN_TIMEOUT=0
GRUB_HIDDEN_TIMEOUT_QUIET=true
GRUB_TIMEOUT=10
GRUB_DISTRIBUTOR=`lsb_release -i -s 2> /dev/null || echo Debian`
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"
GRUB_CMDLINE_LINUX="transparent_hugepage=never default_hugepagesz=1G hugepagesz=1G hugepages=8 iommu=pt intel_iommu=on"
```

- `transparent_hugepage=never default_hugepagesz=1G hugepagesz=1G hugepages=8` 這幾個設定是給 Hugepage 的(在我們的 lab 中是準備給 DPDK 用的)。
    - `transparent_hugepage=never`: 是禁用 Linux THP(Transparent Huge Page)
    - `default_hugepagesz=1G`: 告訴系統我 default 的 Hugepage 要使用 1G 的
    - `hugepagesz=1G`: hugepage size 要用 1G
    - `hugepages=8`: 要 8 個 hugepage

- `iommu=pt intel_iommu=on`: 這幾個設定是要開啟網卡支援 VF 功能。
    - `intel_iommu=on`: Enable SR-IOV in the kernel
    - `iommu=pt`: Add pass-through(pt) to get the best performance

## Update grub

編輯完開機設定檔，要重新 repoad ，repoad 方法是使用以下指令

```sh
$ sudo update-grub
Generating grub configuration file ...
Warning: Setting GRUB_TIMEOUT to a non-zero value when GRUB_HIDDEN_TIMEOUT is set is no longer supported.
Found linux image: /boot/vmlinuz-4.15.0-36-generic
Found initrd image: /boot/initrd.img-4.15.0-36-generic
Adding boot menu entry for EFI firmware configuration
done
```

## 重開機

重開機。讓開機程序走到開機的設定檔，讓網卡和 Hugepage 都是我們想要的。

```sh
reboot
```

## 確認系統

- 確認 /proc/cmdline
```sh
$ cat /proc/cmdline
BOOT_IMAGE=/boot/vmlinuz-4.15.0-36-generic root=UUID=1d5a3e1d-a83a-41db-a9d0-a5832b91fec5 ro transparent_hugepage=never default_hugepagesz=1G hugepagesz=1G hugepages=8 iommu=pt intel_iommu=on
```

#### 確認 Hugepage

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

htop 也會看到已經使用 8G 的 memory。

#### 確認 SR-IOV 功能

- 確認 IOMMU

```sh
$ dmesg | grep -e IOMMU
[    0.000000] DMAR: IOMMU enabled
[    0.000000] DMAR-IR: IOAPIC id 3 under DRHD base  0xfbffc000 IOMMU 0
[    0.000000] DMAR-IR: IOAPIC id 1 under DRHD base  0xc7ffc000 IOMMU 1
[    0.000000] DMAR-IR: IOAPIC id 2 under DRHD base  0xc7ffc000 IOMMU 1
```

- 支援 SR-IOV 的網卡資訊

```sh
$ head -n 1 /sys/class/net/en[a-z]*/device/sriov_totalvfs
==> /sys/class/net/eno1/device/sriov_totalvfs <==
63

==> /sys/class/net/eno2/device/sriov_totalvfs <==
63

==> /sys/class/net/enp4s0f0/device/sriov_totalvfs <==
63

==> /sys/class/net/enp4s0f1/device/sriov_totalvfs <==
63

==> /sys/class/net/ens6f0/device/sriov_totalvfs <==
32

==> /sys/class/net/ens6f1/device/sriov_totalvfs <==
32

==> /sys/class/net/ens6f2/device/sriov_totalvfs <==
32

==> /sys/class/net/ens6f3/device/sriov_totalvfs <==
32
```


## Mount Hugepage 等

- Setting hugepage number

```sh
echo 'vm.nr_hugepages=8' | sudo tee /etc/sysctl.d/hugepages.conf
```

- Mount hugepages

```sh
$ sudo mount -t hugetlbfs none /dev/hugepages
```

- 設定 kernel 變數在執行的時候

```sh
$ sudo sysctl -w vm.nr_hugepages=8
```
