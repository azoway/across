#!/usr/bin/env bash
# Wiki: https://github.com/p4gefau1t/trojan-go
# Usage: bash <(curl -s https://raw.githubusercontent.com/azoway/across/main/trojan-go/trojan-go-acme-cloudflare.sh) my.domain.com CF_Key CF_Email
## one key install trojan-go with acme and cloudflareApi
## Uninstall: /root/.acme.sh/acme.sh --uninstall; systemctl stop trojan-go.service; systemctl disable trojan-go.service; rm -rf /etc/systemd/system/trojan-go.service /usr/bin/trojan-go /etc/trojan-go
### 如不启用cloudflare cdn，脚本运行前需要关闭cloudflare的小云朵
### 如需启用cloudflare cdn，脚本运行前需要打开cloudflare的小云朵并设置ssl为full以上，并在脚本运行完成后修改两端的config.json文件中websocket项的false改为true后重新运行服务

# tempfile & rm it when exit
trap 'rm -f "$TMPFILE"' EXIT
TMPFILE=$(mktemp) || exit 1

######## 脚本需要传入三个参数： 域名,Cloudflare账户的GobalAPI,Cloudflare账户的Email,
[[ $# != 3 ]] && echo Err !!! Useage: bash this_script.sh my.domain.com CF_Key CF_Email && exit 1
domain="$1"
export CF_Key="$2"
export CF_Email="$3"

# install acme.sh
apt install socat -y
curl https://get.acme.sh | sh
source  ~/.bashrc
/root/.acme.sh/acme.sh --upgrade  --auto-upgrade
/root/.acme.sh/acme.sh --issue --dns dns_cf --keylength ec-256 -d $domain --force
rm -rf /etc/trojan-go; mkdir -p /etc/trojan-go
/root/.acme.sh/acme.sh --installcert -d $domain --ecc --fullchain-file /etc/trojan-go/trojan-go.crt --key-file /etc/trojan-go/trojan-go.key --reloadcmd "service trojan-go restart"

# install trojan-go
URL="$(wget -qO- https://api.github.com/repos/p4gefau1t/trojan-go/releases | grep -E "browser_download_url.*linux.*amd64" | head -n 1 | cut -f4 -d\")"
wget -O $TMPFILE $URL && unzip -o $TMPFILE "trojan-go" -d /usr/bin && chmod +x /usr/bin/trojan-go

wget -O /etc/systemd/system/trojan-go.service https://raw.githubusercontent.com/p4gefau1t/trojan-go/master/example/trojan-go.service
sed -i -e "s/User=nobody$/User=root/g" /etc/systemd/system/trojan-go.service

# config trojan-go
password="$(tr -dc 'a-z0-9A-Z' </dev/urandom | head -c 16)"
webspath="$(tr -dc 'a-z0-9A-Z' </dev/urandom | head -c 16)"

cat <<EOF > /etc/trojan-go/config.json
{
    "run_type": "server",
    "local_addr": "0.0.0.0",
    "local_port": 443,
    "remote_addr": "example.com",
    "remote_port": 80,
    "password": [
        "$password"
    ],
    "ssl": {
        "cert": "/etc/trojan-go/trojan-go.crt",
        "key": "/etc/trojan-go/trojan-go.key"
    },
    "websocket": {
        "enabled": false,
        "path": "/$webspath"
    }
}
EOF

systemctl enable trojan-go.service && systemctl daemon-reload && systemctl restart trojan-go.service && systemctl status trojan-go.service | more | grep -A 2 "trojan-go.service"

# info
echo; echo $(date) All Done, minimal client config.json:
cat <<EOF >$TMPFILE
{
    "run_type": "client",
    "local_addr": "127.0.0.1",
    "local_port": 1080,
    "remote_addr": "$domain",
    "remote_port": 443,
    "password": [
        "$password"
    ],
    "websocket": {
        "enabled": false,
        "path": "/$webspath"
    }
}
EOF

cat $TMPFILE
