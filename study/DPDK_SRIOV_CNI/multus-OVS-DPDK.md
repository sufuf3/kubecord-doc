## Prepare

1. Install VPP

```sh
cd ~/ && curl -s https://packagecloud.io/install/repositories/fdio/release/script.deb.sh | sudo bash
sudo apt-get install vpp vpp-lib
```

2. Building VPP CNI Library with OVS

```sh
go get -u github.com/Billy99/user-space-net-plugin
cd ~/go/src/github.com/Billy99/user-space-net-plugin
make install
```


3. Build CNI

```sh
go get -u github.com/intel/userspace-cni-network-plugin
cd ~/go/src/github.com/intel/userspace-cni-network-plugin
make
sudo cp userspace/userspace /opt/cni/bin/
```


## Testing with DPDK Testpmd Application

Ref: https://github.com/intel/userspace-cni-network-plugin#testing-with-dpdk-testpmd-application  

1. Create ovs bridge br0

```sh
sudo ovs-vsctl add-br br0 -- set bridge br0 datapath_type=netdev
```

2. Create NetworkAttachmentDefinition of userspace-network object

```sh
cd ~/go/src/github.com/intel/userspace-cni-network-plugin
kubectl create -f examples/crd-userspace-net-ovs-no-ipam.yaml
```

3. Copy get-prefix.sh script to /var/lib/cni/vhostuser/

```sh
sudo cp tests/get-prefix.sh /var/lib/cni/vhostuser/
```

4. Create pod

```sh
kubectl create -f examples/pod-multi-vhost.yaml
```

5. Exec pod

- original

```sh
$ cat /proc/meminfo | grep Huge
AnonHugePages:         0 kB
ShmemHugePages:        0 kB
HugePages_Total:      12
HugePages_Free:        3
HugePages_Rsvd:        0
HugePages_Surp:        0
Hugepagesize:    1048576 kB

$ sudo ovs-vsctl show
f774ae66-983f-421b-879d-d9357321146f
    Bridge "br0"
        Port "br0"
            Interface "br0"
                type: internal
```

- pod

```sh
# Get container ID
export ID=$(/vhu/get-prefix.sh)

# Run testpmd with ports created by vhostplugin
# Note: change coremask to suit your system
testpmd \
    -d librte_pmd_virtio.so.17.11 \
    -m 1024 \
    -c 0xC \
    --file-prefix=testpmd_ \
    --vdev=net_virtio_user0,path=/vhu/${ID}/${ID:0:12}-net1 \
    --vdev=net_virtio_user1,path=/vhu/${ID}/${ID:0:12}-net2 \
    --no-pci \
    -- \
    --no-lsc-interrupt \
    --auto-start \
    --tx-first \
    --stats-period 1 \
    --disable-hw-vlan;
```

- After

```sh
$ cat /proc/meminfo | grep Huge
AnonHugePages:         0 kB
ShmemHugePages:        0 kB
HugePages_Total:      12
HugePages_Free:        2
HugePages_Rsvd:        1
HugePages_Surp:        0
Hugepagesize:    1048576 kB

$ sudo ovs-vsctl show
f774ae66-983f-421b-879d-d9357321146f
    Bridge "br0"
        Port "br0"
            Interface "br0"
                type: internal
        Port "c05fe7603b58-net2"
            Interface "c05fe7603b58-net2"
                type: dpdkvhostuser
        Port "a1576ef1090f-net1"
            Interface "a1576ef1090f-net1"
                type: dpdkvhostuser
        Port "c05fe7603b58-net1"
            Interface "c05fe7603b58-net1"
                type: dpdkvhostuser
        Port "a1576ef1090f-net2"
            Interface "a1576ef1090f-net2"
                type: dpdkvhostuser

$ sudo ovs-ofctl dump-ports br0
OFPST_PORT reply (xid=0x2): 5 ports
  port  4: rx pkts=0, bytes=0, drop=0, errs=0, frame=?, over=?, crc=?
           tx pkts=0, bytes=0, drop=0, errs=?, coll=?
  port  2: rx pkts=0, bytes=0, drop=0, errs=0, frame=?, over=?, crc=?
           tx pkts=0, bytes=0, drop=0, errs=?, coll=?
  port  1: rx pkts=0, bytes=0, drop=0, errs=0, frame=?, over=?, crc=?
           tx pkts=0, bytes=0, drop=0, errs=?, coll=?
  port  3: rx pkts=0, bytes=0, drop=0, errs=0, frame=?, over=?, crc=?
           tx pkts=0, bytes=0, drop=0, errs=?, coll=?
  port LOCAL: rx pkts=0, bytes=0, drop=0, errs=0, frame=0, over=0, crc=0
           tx pkts=0, bytes=0, drop=0, errs=0, coll=0
```
