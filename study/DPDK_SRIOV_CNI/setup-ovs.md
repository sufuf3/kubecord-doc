# Setup Open vSwitch (OVS)

因為要處理 DPDK 和 OVS  
先來了解 DPDK, Hugepage, NUMA，才來做設定。  
免得後面再來處理問題。  
> http://docs.openvswitch.org/en/latest/intro/install/dpdk/#setup-ovs

### 1. 設定 Open vSwitch 的遠端 database server

```sh
$ ovsdb-server --remote=punix:/var/run/openvswitch/db.sock --remote=db:Open_vSwitch,Open_vSwitch,manager_options --pidfile --detach --log-file
```

### 2. 初始化 Open vSwitch 的 database 

> http://www.openvswitch.org/support/dist-docs/ovs-vswitchd.conf.db.5.txt  
  
```sh
$ ovs-vsctl --no-wait init
```

### 3. 接著，設定 vswitch 支援 DPDK

- DPDK 的參數傳遞給 ovs-vswitchd ，透過 Open_vSwitch table 的 other_config 欄位。
    - the dpdk-init option must be set to either `true` or `try`

```sh
$ ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-init=true
```
```
       other_config : dpdk-init: optional string, either true or false
              Set this value to true to enable runtime support for DPDK ports.
              The vswitch must have compile-time support for DPDK as well.
              The  default  value  is  false.  Changing  this  value  requires
              restarting the daemon
              If this value is false at startup, any dpdk ports which are con‐
              figured in the bridge will fail due to memory errors.
```

### 4. 配置 memory 和 CPU
#### Memory

從預先配置的 hugepage pool 中指定要給的 memory 量，on a per-socket basis。  
(前面配置 8G 的 Hugepage)  

```sh
ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-socket-mem="4096,4096"
```

#### CPU

- 設定 cpu affinity 的 PMD (Poll Mode Driver) threads 透過特定的 CPU mask
    - hex string
    - 最低位對應於第一個 CPU core。

- 查看 NUMA

```sh
$ /usr/src/dpdk-stable-17.11.3/usertools/cpu_layout.py
======================================================================
Core and Socket Information (as reported by '/sys/devices/system/cpu')
======================================================================

cores =  [0, 1, 2, 3, 4, 5, 6, 7]
sockets =  [0, 1]

       Socket 0        Socket 1
       --------        --------
Core 0 [0, 16]         [8, 24]
Core 1 [1, 17]         [9, 25]
Core 2 [2, 18]         [10, 26]
Core 3 [3, 19]         [11, 27]
Core 4 [4, 20]         [12, 28]
Core 5 [5, 21]         [13, 29]
Core 6 [6, 22]         [14, 30]
Core 7 [7, 23]         [15, 31]

$ numactl -H
available: 2 nodes (0-1)
node 0 cpus: 0 1 2 3 4 5 6 7 16 17 18 19 20 21 22 23
node 0 size: 32120 MB
node 0 free: 26572 MB
node 1 cpus: 8 9 10 11 12 13 14 15 24 25 26 27 28 29 30 31
node 1 size: 64508 MB
node 1 free: 58313 MB
node distances:
node   0   1
  0:  10  21
  1:  21  10
```

我們用 2, 3, 10, 11  
```sh
ovs-vsctl --no-wait set Open_vSwitch . other_config:pmd-cpu-mask=0x60E0
```

- Ref: https://www.rapidtables.com/convert/number/hex-to-binary.html
- 範例參考：https://www.youtube.com/watch?v=zTF-1xRC_J4
![](https://i.imgur.com/XX79mUb.png)  


### 5. 在 datapath 中 cached 的最大時間(ms)
- idle 的 flows 在 datapath 中 cached 的最大時間(in ms)
  - default is 10000
  - at least 500

```sh
$ ovs-vsctl --no-wait set Open_vSwitch . other_config:max-idle=30000
```

### 6. Open vSwitch daemon 設定

- **[Open vSwitch daemon](http://www.openvswitch.org/support/dist-docs/ovs-vswitchd.8.html) 設定**

```sh
$ ovs-vswitchd  unix:/var/run/openvswitch/db.sock --pidfile --detach --log-file
2018-08-30T07:33:54Z|00001|vlog|INFO|opened log file /var/log/openvswitch/ovs-vswitchd.log
2018-08-30T07:33:54Z|00002|ovs_numa|INFO|Discovered 16 CPU cores on NUMA node 1
2018-08-30T07:33:54Z|00003|ovs_numa|INFO|Discovered 16 CPU cores on NUMA node 0
2018-08-30T07:33:54Z|00004|ovs_numa|INFO|Discovered 2 NUMA nodes and 32 CPU cores
2018-08-30T07:33:54Z|00005|reconnect|INFO|unix:/var/run/openvswitch/db.sock: connecting...
2018-08-30T07:33:54Z|00006|reconnect|INFO|unix:/var/run/openvswitch/db.sock: connected
2018-08-30T07:33:54Z|00007|dpdk|INFO|Using DPDK 17.11.3
2018-08-30T07:33:54Z|00008|dpdk|INFO|DPDK Enabled - initializing...
2018-08-30T07:33:54Z|00009|dpdk|INFO|No vhost-sock-dir provided - defaulting to /var/run/openvswitch
2018-08-30T07:33:54Z|00010|dpdk|INFO|IOMMU support for vhost-user-client disabled.
2018-08-30T07:33:54Z|00011|dpdk|INFO|EAL ARGS: ovs-vswitchd --socket-mem 4096,4096 -c 0x00000001
2018-08-30T07:33:54Z|00012|dpdk|INFO|EAL: Detected 32 lcore(s)
2018-08-30T07:33:54Z|00013|dpdk|INFO|EAL: Probing VFIO support...
2018-08-30T07:33:56Z|00014|dpdk|INFO|EAL: PCI device 0000:01:00.0 on NUMA socket 0
2018-08-30T07:33:56Z|00015|dpdk|INFO|EAL:   probe driver: 8086:10fb net_ixgbe
2018-08-30T07:33:57Z|00016|dpdk|INFO|EAL: PCI device 0000:01:00.1 on NUMA socket 0
2018-08-30T07:33:57Z|00017|dpdk|INFO|EAL:   probe driver: 8086:10fb net_ixgbe
2018-08-30T07:33:57Z|00018|dpdk|INFO|EAL: PCI device 0000:01:10.0 on NUMA socket 0
2018-08-30T07:33:57Z|00019|dpdk|INFO|EAL:   probe driver: 8086:10ed net_ixgbe_vf
2018-08-30T07:33:57Z|00020|dpdk|INFO|EAL: PCI device 0000:01:10.1 on NUMA socket 0
2018-08-30T07:33:57Z|00021|dpdk|INFO|EAL:   probe driver: 8086:10ed net_ixgbe_vf
2018-08-30T07:33:57Z|00022|dpdk|INFO|EAL: PCI device 0000:01:10.2 on NUMA socket 0
2018-08-30T07:33:57Z|00023|dpdk|INFO|EAL:   probe driver: 8086:10ed net_ixgbe_vf
2018-08-30T07:33:57Z|00024|dpdk|INFO|EAL: PCI device 0000:01:10.3 on NUMA socket 0
2018-08-30T07:33:57Z|00025|dpdk|INFO|EAL:   probe driver: 8086:10ed net_ixgbe_vf
2018-08-30T07:33:57Z|00026|dpdk|INFO|EAL: PCI device 0000:08:00.0 on NUMA socket 0
2018-08-30T07:33:57Z|00027|dpdk|INFO|EAL:   probe driver: 8086:1533 net_e1000_igb
2018-08-30T07:33:57Z|00028|dpdk|INFO|EAL: PCI device 0000:09:00.0 on NUMA socket 0
2018-08-30T07:33:57Z|00029|dpdk|INFO|EAL:   probe driver: 8086:1533 net_e1000_igb
Zone 0: name:<rte_eth_dev_data>, IO:0x73ffb63c0, len:0x34900, virt:0x7f21fffb63c0, socket_id:0, flags:0
Zone 1: name:<RG_HT_fdir_0000:01:00.0>, IO:0x73ff5de80, len:0x40180, virt:0x7f21fff5de80, socket_id:0, flags:0
Zone 2: name:<RG_HT_l2_tn_0000:01:00.0>, IO:0x73fc5d580, len:0x580, virt:0x7f21ffc5d580, socket_id:0, flags:0
2018-08-30T07:33:57Z|00030|dpdk|INFO|DPDK Enabled - initialized
2018-08-30T07:33:57Z|00031|timeval|WARN|Unreasonably long 3465ms poll interval (1137ms user, 2209ms system)
2018-08-30T07:33:57Z|00032|timeval|WARN|faults: 302 minor, 0 major
2018-08-30T07:33:57Z|00033|timeval|WARN|disk: 0 reads, 8 writes
2018-08-30T07:33:57Z|00034|timeval|WARN|context switches: 4 voluntary, 9 involuntary
2018-08-30T07:33:57Z|00035|coverage|INFO|Event coverage, avg rate over last: 5 seconds, last minute, last hour,  hash=fda1882c:
2018-08-30T07:33:57Z|00036|coverage|INFO|bridge_reconfigure         0.0/sec     0.000/sec        0.0000/sec   total: 1
2018-08-30T07:33:57Z|00037|coverage|INFO|cmap_expand                0.0/sec     0.000/sec        0.0000/sec   total: 8
2018-08-30T07:33:57Z|00038|coverage|INFO|miniflow_malloc            0.0/sec     0.000/sec        0.0000/sec   total: 8
2018-08-30T07:33:57Z|00039|coverage|INFO|hmap_pathological          0.0/sec     0.000/sec        0.0000/sec   total: 4
2018-08-30T07:33:57Z|00040|coverage|INFO|hmap_expand                0.0/sec     0.000/sec        0.0000/sec   total: 402
2018-08-30T07:33:57Z|00041|coverage|INFO|txn_unchanged              0.0/sec     0.000/sec        0.0000/sec   total: 2
2018-08-30T07:33:57Z|00042|coverage|INFO|txn_incomplete             0.0/sec     0.000/sec        0.0000/sec   total: 1
2018-08-30T07:33:57Z|00043|coverage|INFO|poll_create_node           0.0/sec     0.000/sec        0.0000/sec   total: 47
2018-08-30T07:33:57Z|00044|coverage|INFO|poll_zero_timeout          0.0/sec     0.000/sec        0.0000/sec   total: 1
2018-08-30T07:33:57Z|00045|coverage|INFO|seq_change                 0.0/sec     0.000/sec        0.0000/sec   total: 38
2018-08-30T07:33:57Z|00046|coverage|INFO|pstream_open               0.0/sec     0.000/sec        0.0000/sec   total: 1
2018-08-30T07:33:57Z|00047|coverage|INFO|stream_open                0.0/sec     0.000/sec        0.0000/sec   total: 1
2018-08-30T07:33:57Z|00048|coverage|INFO|util_xalloc                0.0/sec     0.000/sec        0.0000/sec   total: 7813
2018-08-30T07:33:57Z|00049|coverage|INFO|netdev_get_hwaddr          0.0/sec     0.000/sec        0.0000/sec   total: 1
2018-08-30T07:33:57Z|00050|coverage|INFO|netlink_received           0.0/sec     0.000/sec        0.0000/sec   total: 3
2018-08-30T07:33:57Z|00051|coverage|INFO|netlink_sent               0.0/sec     0.000/sec        0.0000/sec   total: 1
2018-08-30T07:33:57Z|00052|coverage|INFO|88 events never hit
2018-08-30T07:33:57Z|00053|poll_loop|INFO|wakeup due to [POLLIN] on fd 11 (<->/var/run/openvswitch/db.sock) at lib/stream-fd.c:157 (98% CPU usage)
```

### Check

```sh
$ cat /sys/devices/system/node/node*/meminfo | grep Huge
Node 0 AnonHugePages:         0 kB
Node 0 ShmemHugePages:        0 kB
Node 0 HugePages_Total:     4
Node 0 HugePages_Free:      0
Node 0 HugePages_Surp:      0
Node 1 AnonHugePages:         0 kB
Node 1 ShmemHugePages:        0 kB
Node 1 HugePages_Total:     4
Node 1 HugePages_Free:      0
Node 1 HugePages_Surp:      0

$ cat /proc/meminfo | grep Huge
AnonHugePages:         0 kB
ShmemHugePages:        0 kB
HugePages_Total:       8
HugePages_Free:        0
HugePages_Rsvd:        0
HugePages_Surp:        0
Hugepagesize:    1048576 kB
```


