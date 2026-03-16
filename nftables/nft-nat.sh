#!/usr/bin/env bash
# Usage: bash <(curl -s https://raw.githubusercontent.com/azoway/across/main/nftables/nft-nat.sh)
## Wiki: debian nftables https://wiki.archlinux.org/index.php/Nftables

# 说明
[ 0 -eq 1 ] && {
1. 需要先自行安装 nftables:
      apt update && apt install nftables -y
      systemctl enable nftables
      systemctl restart nftables
2. 必须先创建 /etc/nft.diy 文件，文件每行为一个转发规则:
      本地端口或端口段/远程域名或IP/远程端口或端口段
3. /etc/nft.diy 格式范本如下:
      20103/bing.com/443
      20104-20108/1.1.1.1/443
      30000-30108/www.example.com/30000-30108
4. 脚本运行后规则立即生效,重启后失效,可选择以下以下其中一种方式来持久化:
   4.1 适合目标为固定IP的转发,脚本运行完毕后使用下面命令保存规则:
      echo '#!/usr/sbin/nft -f' >/etc/nftables.conf
      echo 'flush ruleset' >>/etc/nftables.conf
      nft list ruleset >>/etc/nftables.conf
      systemctl restart nftables
   4.2 适合目标含有域名的转发,当 IP 变化时重新执行脚本即可，推荐使用定时任务:
      wget --no-check-certificate -O /opt/nft-nat.sh https://raw.githubusercontent.com/azoway/across/main/nftables/nft-nat.sh
      chmod 755 /opt/nft-nat.sh
      (crontab -l 2>/dev/null; echo "5 * * * * /opt/nft-nat.sh") | crontab -
}

### dependencies
command -v nft >/dev/null 2>&1 || { echo "Please install nftables"; exit 1; }
command -v getent >/dev/null 2>&1 || { echo "Please install libc-bin (getent)"; exit 1; }
command -v ip >/dev/null 2>&1 || { echo "Please install iproute2"; exit 1; }

### config file check
if [[ ! -f /etc/nft.diy ]]; then
    echo "Sorry, no file: /etc/nft.diy"
    exit 1
fi

### enable ipv4 forward
grep -qwE "^#?net.ipv4.ip_forward=1" /etc/sysctl.conf || echo "net.ipv4.ip_forward=1" >>/etc/sysctl.conf
sed -i "s/^#net\.ipv4\.ip_forward=1/net.ipv4.ip_forward=1/" /etc/sysctl.conf
echo 1 > /proc/sys/net/ipv4/ip_forward
sysctl -p >/dev/null

###
### recreate nat table/chain
nft list table ip nat >/dev/null 2>&1 && nft delete table ip nat
nft add table ip nat
nft add chain ip nat PREROUTING { type nat hook prerouting priority -100 \; }
nft add chain ip nat POSTROUTING { type nat hook postrouting priority 100 \; }

### detect first global IPv4 as local_ip
local_ip=$(ip -4 address show scope global | awk '/inet / {print $2}' | head -n1 | cut -d'/' -f1)
if [[ -z "$local_ip" ]]; then
    echo "Cannot detect local IPv4 address (scope global)."
    exit 1
fi

### read rules line by line
while IFS=/ read -r local_port remote_host remote_port; do
    [[ -z "$local_port" || -z "$remote_host" || -z "$remote_port" ]] && continue

    # resolve remote_host to IPv4 using getent (faster and no ICMP)
    remote_ip=$(getent ahostsv4 "$remote_host" | awk '{print $1; exit}')
    if [[ -z "$remote_ip" ]]; then
        echo "Failed to resolve host: $remote_host, skip."
        continue
    fi

    nft add rule ip nat PREROUTING tcp dport "$local_port" counter dnat to "$remote_ip":"$remote_port"
    nft add rule ip nat PREROUTING udp dport "$local_port" counter dnat to "$remote_ip":"$remote_port"

    nft add rule ip nat POSTROUTING ip daddr "$remote_ip" tcp dport "$remote_port" counter snat to "$local_ip"
    nft add rule ip nat POSTROUTING ip daddr "$remote_ip" udp dport "$remote_port" counter snat to "$local_ip"
done </etc/nft.diy

nft list ruleset