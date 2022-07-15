#!/usr/bin/env bash
# Wiki: https://github.com/tindy2013/subconverter
# Usage: bash <(curl -s https://raw.githubusercontent.com/azples/across/master/subconverter/run.sh) my.domain.com
# Uninstall: apt purge caddy -y; systemctl stop subconverter; systemctl disable subconverter; rm -rf /etc/systemd/system/subconverter.service /root/subconverter

# 需先把节点放入/etc/links.diy文件,每行一个
[[ ! -f /etc/links.diy ]] && echo Sorry, no File: /etc/links.diy && exit 1

# 需传入域名参数,如未输入token参数,则使用随机uuid作为token
[[ $# != 1 ]] && [[ $# != 2 ]]&& echo Err  !!! Useage: bash this_script.sh uuid my.domain.com && exit 1
[[ $# == 1 ]] && token="$(cat /proc/sys/kernel/random/uuid)" && domain="$1"
[[ $# == 2 ]] && token="$1" && domain="$2"

# tempfile & rm it when exit
trap 'rm -f "$TMPFILE"' EXIT; TMPFILE=$(mktemp) || exit 1

# 安装caddy作为前端,转发请求到subconverter监听地址
caddyURL="$(wget -qO-  https://api.github.com/repos/caddyserver/caddy/releases | grep -E "browser_download_url.*linux_amd64\.deb" | cut -f4 -d\" | head -n1)"
wget -O $TMPFILE $caddyURL && dpkg -i $TMPFILE
cat <<EOF >/etc/caddy/Caddyfile
$domain
root * /usr/share/caddy
file_server
reverse_proxy http://127.0.0.1:25500
EOF

# 安装subconverter服务
URL="$(wget -qO- https://api.github.com/repos/tindy2013/subconverter/releases/latest | grep -E "browser_download_url.*linux64.tar.gz" | cut -f4 -d\")"
rm -rf /root/subconverter /root/subconverter_linux64.tar.gz
wget $URL && tar -zxf subconverter_linux64.tar.gz && chmod +x /root/subconverter/subconverter && rm -rf /root/subconverter_linux64.tar.gz
cat <<EOF > /etc/systemd/system/subconverter.service
[Unit]
Description=subconverter
[Service]
ExecStart=/root/subconverter/subconverter
Restart=always
User=root
[Install]
WantedBy=multi-user.target
EOF

# 修改监听端口为127.0.0.1,设置token参数
sed -i -e "s/listen=0.0.0.0/listen=127.0.0.1/g" -e "s/api_access_token=password/api_access_token=$token/g" /root/subconverter/pref.ini 

# 生成订阅节点信息配置文件
cat <<EOF > /root/subconverter/profiles/auto.ini
[Profile]
target=auto
url=$(cat /etc/links.diy | tr "\n" "|")
EOF

# systemctl
systemctl enable caddy subconverter && systemctl daemon-reload && systemctl restart caddy subconverter && sleep 3 && systemctl status caddy subconverter | grep -A 2 "service"

# info
echo $(date) Visit: https://$domain
echo; echo For Subconverter: "https://$domain/getprofile?name=profiles/auto.ini&token=$token"
