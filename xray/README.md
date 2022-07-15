###### Tips
* 通过[caddy](https://github.com/caddyserver/caddy/releases)|[xray](https://github.com/XTLS/Xray-core/releases)|[acme.sh](https://github.com/acmesh-official/acme.sh)配置`vless(xtls) + vmess + trojan + ss+v2ray-plugin + naiveproxy`**共用443端口**  
* 参考：[xray](https://github.com/XTLS/Xray-examples)  &&  [lxhao61](https://github.com/lxhao61/integrated-examples)
* 安装:
```bash
bash <(curl -s https://raw.githubusercontent.com/azoway/across/main/xray/xray_whatever_uuid.sh) my.domain.com
```
* 卸载:
```bash
bash <(curl -s https://raw.githubusercontent.com/azoway/across/main/xray/xray_whatever_uuid.sh) remove_purge
```
