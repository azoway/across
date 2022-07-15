###### Tips
* 订阅转换器安装脚本,需先把节点放入/etc/links.diy文件,每行一个  
* [更多配置参考subconverter](https://github.com/tindy2013/subconverter)  
* 安装:
```bash
bash <(curl -s https://raw.githubusercontent.com/azoway/across/master/subconverter/run.sh) my.domain.com
```
* 卸载:
```bash
apt purge caddy -y
systemctl stop subconverter; systemctl disable subconverter; rm -rf /etc/systemd/system/subconverter.service /root/subconverter
```
