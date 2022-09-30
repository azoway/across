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
    naivecaddyURL="$(wget -qO- https://api.github.com/repos/lxhao61/integrated-examples/releases | grep -E "browser_download_url.*linux-$(dpkg --print-architecture)\.tar.gz" | cut -f4 -d\" | head -n1)"
    wget -O $TMPFILE $caddyURL && dpkg -i $TMPFILE
    wget -4 -O $TMPFILE $naivecaddyURL && tar -zxf $TMPFILE -C /usr/bin && chmod +x /usr/bin/caddy
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
        protocols h1 h2c h2
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
