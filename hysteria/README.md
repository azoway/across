###### Tips
* [hysteria](https://github.com/HyNetwork/hysteria)
* 安装:
```bash
bash <(curl -s https://raw.githubusercontent.com/azoway/across/main/hysteria/hysteria.sh) my.domain.com 
```
* 卸载:
```bash
bash <(curl -s https://raw.githubusercontent.com/apernet/hysteria/master/scripts/install_server.sh) --remove
```
* 指定uuid作为密码
```bash
使用命令 cat /proc/sys/kernel/random/uuid 可生成 uuid
bash <(curl -s https://raw.githubusercontent.com/azoway/across/main/hysteria/hysteria.sh) 97697d26-04e5-47ba-84ac-65289558977d my.domain.com
```
