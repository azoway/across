###### Tips
* 通过  [xray](https://github.com/XTLS/Xray-core/releases) [caddy](https://github.com/caddyserver/caddy/releases)  配置  [reality](https://github.com/XTLS/REALITY) + [trojan](https://github.com/imgk/caddy-trojan) + [naiveproxy](https://github.com/klzgrad/naiveproxy)  **共用443端口**  
* 参考：[xray](https://github.com/XTLS/Xray-examples) [lxhao61](https://github.com/lxhao61/integrated-examples)
* 安装:
```bash
方法一: 假如已有域名 my.domain.com 指向服务器地址, 使用以下命令
bash <(curl -s https://raw.githubusercontent.com/azoway/across/master/xtls/xtls_fly.sh) domain@my.domain.com
 
方法二: 假如仅有IP地址 123.123.234.234 可使用DNS泛域名解析应用nip.io/sslip.io, 使用以下命令
bash <(curl -s https://raw.githubusercontent.com/azoway/across/master/xtls/xtls_fly.sh) domain@123.123.234.234.nip.io
  
加上uuid(默认随机)：
bash <(curl -s https://raw.githubusercontent.com/azoway/across/master/xtls/xtls_fly.sh) domain@123.123.234.234.nip.io uuid@97697d26-04e5-47ba-84ac-65289558977d 

加上伪装域名(默认www.amazon.com)：
bash <(curl -s https://raw.githubusercontent.com/azoway/across/master/xtls/xtls_fly.sh) domain@my.domain.com fk@www.amazon.com

加上privateKey(默认由 xray x25519 命令生成)：
bash <(curl -s https://raw.githubusercontent.com/azoway/across/master/xtls/xtls_fly.sh) domain@my.domain.com pk@YGSafufMK-803V3RH5j4dkGzTR_WT8-QSObNSBlqr3Y
```
* 卸载:
```bash
apt purge caddy -y
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove --purge
```
