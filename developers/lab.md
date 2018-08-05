# Lab 紀錄
### 加入 controller 管理的 OVS 的現狀
因為變成 controller 要來管理 OVS 了，所以 OVS 就不做原本 switch 很聰明的 fowrding 功能。  
進到 k8s pod 中會發現， 互相 ping 不到對方了。  
而在 web 也看到  
![](https://i.imgur.com/EUBtpOk.png)  

