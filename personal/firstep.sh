#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin; export PATH
# Usage: bash <(wget -qO- https://raw.githubusercontent.com/mixool/across/master/personal/firstep.sh)

# only root can run this script
[[ $EUID -ne 0 ]] && echo "Error, This script must be run as root!" && exit 1

# tempfile & rm it when exit
trap 'rm -f "$TMPFILE"' EXIT; TMPFILE=$(mktemp) || exit 1

# sources.list backports 
version=$(cat /etc/os-release | grep -oE "VERSION_ID=\"(9|10)\"" | grep -oE "(9|10)")
if [[ $version == "9" ]]; then
    backports_version="stretch-backports-sloppy"
else
    [[ $version != "10" ]] && echo "Error, OS should be debian stretch or buster " && exit 1 || backports_version="buster-backports"
fi
cat /etc/apt/sources.list | grep -q "$backports_version" || echo -e "deb http://deb.debian.org/debian $backports_version main" >> /etc/apt/sources.list

# apt install 
apt update
apt install apt-transport-https ca-certificates curl vim wget -y
apt -t $backports_version install nftables -y

# timezone
timedatectl set-timezone Asia/Shanghai

# clean
apt autoremove -y --purge
apt clean
