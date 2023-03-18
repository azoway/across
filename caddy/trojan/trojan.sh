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
    wget -O $TMPFILE $caddyURL && dpkg -i $TMPFILE
    caddy add-package github.com/imgk/caddy-trojan
}

function _config(){
    cat <<EOF >/etc/caddy/Caddyfile
{
    order trojan before route
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
$(date) https://$domain
trojan://$uuid@$domain:443#$domain-trojan
EOF
    cat $TMPFILE | tee /var/log/${TMPFILE##*/} && echo && echo $(date) Info saved: /var/log/${TMPFILE##*/}
}

function main(){
    _install
    _config
    _info
}

main
