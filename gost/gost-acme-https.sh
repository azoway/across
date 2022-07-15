#!/usr/bin/env bash
# Wiki: https://docs.ginuerzh.xyz/gost/
# Usage: bash <(curl -s https://raw.githubusercontent.com/azoway/across/main/gost/gost-acme-https.sh) my.domain.com CF_Key CF_Email
## 一键GOST搭建443端口的服务端HTTPS代理，并开启防探测。使用acme和cloudflareApi自动管理证书，重复运行即可更改随机账号密码
## SwithcyOmega使用这个代理，先访问一次knock这个网址
## Uninstall: /root/.acme.sh/acme.sh --uninstall; systemctl stop gost; systemctl disable gost; rm -rf /etc/systemd/system/gost.service /usr/bin/gost /etc/gost

######## 脚本需要传入三个参数： 域名,Cloudflare账户的GobalAPI,Cloudflare账户的Email
[[ $# != 3 ]] && echo Err !!! Useage: bash this_script.sh my.domain.com CF_Key CF_Email && exit 1
domain="$1"
export CF_Key="$2"
export CF_Email="$3"
########

# install acme.sh
apt install socat -y
curl https://get.acme.sh | sh
source  ~/.bashrc
/root/.acme.sh/acme.sh --issue --dns dns_cf --keylength ec-256 -d $domain
rm -rf /etc/gost; mkdir -p /etc/gost
/root/.acme.sh/acme.sh --installcert -d $domain --ecc --fullchain-file /etc/gost/gost.crt --key-file /etc/gost/gost.key --reloadcmd "service gost restart"

# install gost
URL="$(wget -qO- https://api.github.com/repos/ginuerzh/gost/releases/latest | grep -E "browser_download_url.*gost-linux-amd64" | cut -f4 -d\")"
rm -rf /usr/bin/gost
wget -O - $URL | gzip -d > /usr/bin/gost && chmod +x /usr/bin/gost

## 探测防御使用caddy2默认页面
wget -O /etc/gost/index.html https://raw.githubusercontent.com/caddyserver/dist/master/welcome/index.html

## 代理账号密码以及Knock参数: https://docs.ginuerzh.xyz/gost/probe_resist/
username="$(tr -dc 'a-z0-9A-Z' </dev/urandom | head -c 8)"
password="$(tr -dc 'a-z0-9A-Z' </dev/urandom | head -c 8)"
knockpar="$(tr -dc 'a-z0-9A-Z' </dev/urandom | head -c 8).$domain"

cat <<EOF > /etc/systemd/system/gost.service
[Unit]
Description=gost
[Service]
ExecStart=/usr/bin/gost -L=https://$username:$password@:443?probe_resist=file:/etc/gost/index.html&knock=$knockpar&cert=/etc/gost/gost.crt&key=/etc/gost/gost.key
Restart=always
User=root
[Install]
WantedBy=multi-user.target
EOF

systemctl enable gost.service && systemctl daemon-reload && systemctl restart gost.service && systemctl status gost | more | grep -A 2 "gost.service"

# info
echo; echo $(date); echo knock: $knockpar; echo username: $username; echo password: $password; echo proxy: https://$username:$password@$domain
