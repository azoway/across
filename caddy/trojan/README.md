###### Tips
* 通过  [caddy](https://github.com/caddyserver/caddy/releases)  配置  [trojan](https://github.com/imgk/caddy-trojan)
* 安装:
```bash
方法一: 假如已有域名 my.domain.com 指向服务器地址, 使用以下命令
bash <(curl -s https://raw.githubusercontent.com/azoway/across/master/caddy/trojan/trojan.sh) my.domain.com
 
方法二: 假如仅有IP地址 123.123.234.234 可使用DNS泛域名解析应用nip.io/sslip.io, 使用以下命令
bash <(curl -s https://raw.githubusercontent.com/azoway/across/master/caddy/trojan/trojan.sh) 123.123.234.234.nip.io
  
指定uuid：
使用命令 cat /proc/sys/kernel/random/uuid 可生成 uuid
bash <(curl -s https://raw.githubusercontent.com/azoway/across/master/caddy/trojan/trojan.sh) 97697d26-04e5-47ba-84ac-65289558977d 123.123.234.234.nip.io
```
* 卸载:
```bash
apt purge caddy -y
```
