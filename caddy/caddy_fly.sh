#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin; export PATH

# tempfile & rm it when exit
trap 'rm -f "$TMPFILE"' EXIT; TMPFILE=$(mktemp) || exit 1

########
[[ $# != 1 ]] && [[ $# != 2 ]] && echo Err  !!! Useage: bash this_script.sh uuid my.domain.com && exit 1
[[ $# == 1 ]] && uuid="$(cat /proc/sys/kernel/random/uuid)" && domain="$1"
[[ $# == 2 ]] && uuid="$1" && domain="$2"
########

function _install(){
    caddyURL="$(wget -qO- https://api.github.com/repos/caddyserver/caddy/releases | grep -E "browser_download_url.*linux_$(dpkg --print-architecture)\.deb" | cut -f4 -d\" | head -n1)"
    naivecaddyURL="https://caddyserver.com/api/download?os=linux&arch=$(dpkg --print-architecture)&p=github.com%2Fcaddy-dns%2Fcloudflare&p=github.com%2Fmholt%2Fcaddy-l4&p=github.com%2Fimgk%2Fcaddy-trojan&p=github.com%2Fcaddyserver%2Fforwardproxy"
    wget -O $TMPFILE $caddyURL && dpkg -i $TMPFILE
    wget -O $TMPFILE $naivecaddyURL && cp -f $TMPFILE /usr/bin/caddy && chmod +x /usr/bin/caddy
}

function _config(){
    cat <<EOF >/etc/caddy/Caddyfile
{
    order trojan before route
    order forward_proxy before trojan
    admin off
    servers :443 {
        listener_wrappers {
            trojan
        }
    }
    trojan {
        caddy
        no_proxy
        users $uuid
    }
}

:443, $domain {
    forward_proxy {
        basic_auth $uuid $uuid
        hide_ip
        hide_via
        probe_resistance $uuid.com
    }
    trojan {
        connect_method
        websocket
    }
    @host host $domain
    route @host {
        file_server {
            root /usr/share/caddy
        }
    }
}
EOF
    cat <<EOF >/lib/systemd/system/caddy.service
[Unit]
Description=Caddy
Documentation=https://caddyserver.com/docs/
After=network.target network-online.target
Requires=network-online.target

[Service]
Type=notify
User=root
Group=root
ExecStart=/usr/bin/caddy run --environ --config /etc/caddy/Caddyfile
ExecReload=/usr/bin/caddy reload --config /etc/caddy/Caddyfile --force
TimeoutStopSec=5s
LimitNOFILE=1048576
LimitNPROC=512
PrivateTmp=true
ProtectSystem=full
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF
}

function _info(){
    systemctl enable caddy && systemctl restart caddy && sleep 3 && systemctl status caddy | grep -A 2 "service" | tee $TMPFILE
    cat <<EOF >$TMPFILE
$(date)
trojan://$uuid@$domain:443#$domain-trojan

naiveproxy: https://$uuid:$uuid@$domain
probe_resistance: $uuid.com
shadowrocket use http2

Visit: https://$domain
EOF
    cat $TMPFILE | tee /var/log/${TMPFILE##*/} && echo && echo $(date) Info saved: /var/log/${TMPFILE##*/}
}

function main(){
    _install
    _config
    _info
}

main
