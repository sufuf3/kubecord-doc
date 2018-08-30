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
ovs-vsctl --no-wait set Open_vSwitch . other_config:pmd-cpu-mask=0xC0C
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
```




