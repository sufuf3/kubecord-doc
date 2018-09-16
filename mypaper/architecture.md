# Architecture
## New CORD 6.0 platform

![](https://i.imgur.com/vuVzohH.png)  

## Architecture of paper

![](https://i.imgur.com/3PjXBrN.png)  
![](https://i.imgur.com/rrstxrP.png)  
  
- NIC-1: is k8s CNI, as k8s control plane
- NIC-2: Multiple interface, as OVS + DPDK
- NIC-3: Multiple interface, as OVS + DPDK + SR-IOV
- NIC-4: Multiple interface, as SR-IOV

