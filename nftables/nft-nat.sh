#!/usr/bin/env bash
# Usage: bash <(curl -s https://raw.githubusercontent.com/azples/across/main/nftables/nft-nat.sh)
## Wiki: debian buster nftables https://wiki.archlinux.org/index.php/Nftables

# 说明
[ 0 -eq 1 ] && {
1. 需要先自行安装nftable,确保nftables能正常工作，脚本仅在debian 10上测试：
   apt install nftables -y; systemctl enable nftables; systemctl restart nftables
2. 脚本运行后转发生效，重启后失效，可使用定时任务执行此脚本，或者脚本运行完毕使用下面命令保存规则:
   echo '#!/usr/sbin/nft -f' >/etc/nftables.conf; echo "flush ruleset" >>/etc/nftables.conf; nft list ruleset >>/etc/nftables.conf
3. 必须先创建/etc/nft.diy文件，文件每行为一个转发规则，支持端口段第一个为本地端口，第二个为远程域名或IP，第三个为远程端口
   第二个如填写的是域名，当IP变化时重新执行脚本即可，推荐使用定时任务
   wget --no-check-certificate -O /opt/nft-nat.sh https://raw.githubusercontent.com/azples/across/main/nftables/nft-nat.sh
   chmod 755 /opt/nft-nat.sh
   (crontab -l ; echo "0 */2 * * * /opt/nft-nat.sh") | crontab -
4. 文件/etc/nft.diy格式范本：
20103/bing.com/443
20104-20108/1.1.1.1/443
30000-30108/www.example.com/30000-30108
}

### dependencies
command -v nft > /dev/null 2>&1 || { echo "Please install nftables： apt update && apt -t buster-backports install nftables -y"; exit 1; }

###
[[ ! -f /etc/nft.diy ]] && echo Sorry, no File: /etc/nft.diy && exit 1

###
cat /etc/sysctl.conf | grep -qwE "^#net.ipv4.ip_forward=1" && sed -i "s/^#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/" /etc/sysctl.conf
echo 1 > /proc/sys/net/ipv4/ip_forward
sysctl -p >/dev/null

###
nft add table ip nat
nft delete table ip nat
nft add table ip nat
nft add chain nat PREROUTING { type nat hook prerouting priority \ -100 \; }
nft add chain nat POSTROUTING { type nat hook postrouting priority 100 \; }

for ((i=1; i<=$(cat /etc/nft.diy | grep -c ""); i++)); do

    local_port=$(cat /etc/nft.diy | sed -n "${i}p" | cut -f1 -d/)
    local_ip=$(ip address | grep -E "scope global" | head -n1 | cut -f6 -d" " | cut -f1 -d"/")
    
    remote_port=$(cat /etc/nft.diy | sed -n "${i}p" | cut -f3 -d/)
    remote_ip=$(ping -w 1 -c 1 $(cat /etc/nft.diy | sed -n "${i}p" | cut -f2 -d/) | head -n 1 | grep -oE "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | head -n 1)
    
    nft add rule ip nat PREROUTING tcp dport $local_port counter dnat to $remote_ip:$remote_port
    nft add rule ip nat PREROUTING udp dport $local_port counter dnat to $remote_ip:$remote_port
    
    nft add rule ip nat POSTROUTING ip daddr $remote_ip tcp dport $remote_port counter snat to $local_ip
    nft add rule ip nat POSTROUTING ip daddr $remote_ip udp dport $remote_port counter snat to $local_ip
    
done

nft list ruleset