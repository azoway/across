###### Tips
* 通过  [caddy](https://github.com/caddyserver/caddy/releases)  配置  [caddy-trojan](https://github.com/imgk/caddy-trojan) + [naiveproxy](https://github.com/klzgrad/naiveproxy)  **共用443端口**  
* 参考：[lxhao61](https://github.com/lxhao61/integrated-examples)
* 安装:
```bash
bash <(curl -s https://raw.githubusercontent.com/azoway/across/master/caddy/caddy_fly.sh) my.domain.com 
```
* 卸载:
```bash
apt purge caddy -y
```
