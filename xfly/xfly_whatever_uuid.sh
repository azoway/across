#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin; export PATH

# tempfile & rm it when exit
trap 'rm -f "$TMPFILE"' EXIT; TMPFILE=$(mktemp) || exit 1

########
[[ $# != 1 ]] && [[ $# != 2 ]] && echo Err  !!! Useage: bash this_script.sh uuid my.domain.com && exit 1
[[ $# == 1 ]] && uuid="$(cat /proc/sys/kernel/random/uuid)" && domain="$1"
[[ $# == 2 ]] && uuid="$1" && domain="$2"
########

function install_xray_caddy(){
    # caddy with layer4 cloudflare-dns naiveproxy: https://github.com/azoway/caddys
    caddyURL="$(wget -qO- https://api.github.com/repos/caddyserver/caddy/releases | grep -E "browser_download_url.*linux_$(dpkg --print-architecture)\.deb" | cut -f4 -d\" | head -n1)"
    naivecaddyURL="$(wget -qO- https://api.github.com/repos/lxhao61/integrated-examples/releases | grep -E "browser_download_url.*linux_$(dpkg --print-architecture)\.tar.gz" | cut -f4 -d\" | head -n1)"
    wget -O $TMPFILE $caddyURL && dpkg -i $TMPFILE
    wget -4 -O $TMPFILE $naivecaddyURL && tar -zxf $TMPFILE -C /usr/bin && chmod +x /usr/bin/caddy
    sed -i -e "s/caddy\/Caddyfile$/caddy\/Caddyfile\.json/g" /lib/systemd/system/caddy.service && systemctl daemon-reload && systemctl restart caddy
    # xray install
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u root
}

function config_xray_caddy(){
# config xray
cat <<EOF >/usr/local/etc/xray/config.json
{
    "log": {"loglevel": "warning"},
    "inbounds": [
        {"listen": "127.0.0.1","port": 59876,"protocol": "socks","settings": {"udp": true}},
        {"listen": "@trojan","protocol": "trojan","settings": {"clients": [{"password":"$uuid"}],"fallbacks": [{"dest": "50080"}]}},
        {"listen": "0.0.0.0","port": 443,"protocol": "vless","settings": {"clients": [{"id": "$uuid"}],"decryption": "none","fallbacks": [{"name": "$domain","dest": "@trojan"}]},"streamSettings": {"network": "tcp","security": "tls","tlsSettings": {"certificates": [{"certificateFile": "/var/lib/caddy/certificates/acme-v02.api.letsencrypt.org-directory/$domain/$domain.crt","keyFile": "/var/lib/caddy/certificates/acme-v02.api.letsencrypt.org-directory/$domain/$domain.key"}]}}}
    ],
    "outbounds": 
    [
        {"protocol": "freedom","tag": "direct","settings": {}},
        {"protocol": "blackhole","tag": "blocked","settings": {}}
    ],
    "routing": 
    {
        "rules": 
        [
            {"type": "field","outboundTag": "blocked","ip": ["geoip:private"]},
            {"type": "field","outboundTag": "blocked","domain": ["geosite:private","geosite:category-ads-all"]},
            {"type": "field","outboundTag": "direct","domain": ["geosite:netflix","geosite:google"]}
        ]
    }
}
EOF

# caddy json config
cat <<EOF >/etc/caddy/Caddyfile.json
{
    "admin": {"disabled": true},
    "apps": {
        "tls": {"certificates": {"automate": ["$domain"]},"automation": {"policies": [{"storage": {"module": "file_system","root": "/var/lib/caddy"},"issuers": [{"module": "acme"}]}]}},
        "http": {
            "servers": {
                "srv0": {
                    "listen": [":80"],
                    "routes": [
                        {
                            "match": [{"host": ["$domain"]}],
                            "handle": [{"handler": "subroute","routes": [{"handle": [{"handler": "static_response","headers": {"Location": ["https://{http.request.host}{http.request.uri}"]},"status_code": 301}]}]}]
                        }
                    ]
                },
                "srv1": {
                    "listen": ["127.0.0.1:50080"],
                    "routes": 
                    [
                        {
                            "handle": [{
                                "handler": "forward_proxy",
                                "hide_ip": true,
                                "hide_via": true,
                                "auth_user_deprecated": "$uuid",
                                "auth_pass_deprecated": "$uuid",
                                "probe_resistance": {"domain": "$uuid.com"},
                                "upstream": "socks5://127.0.0.1:59876"
                            }]
                        },
                        {
                            "handle": [{
                                "handler": "file_server",
                                "root": "/usr/share/caddy"
                            }]
                        }
                    ],
                    "allow_h2c": true,
                    "experimental_http3": true
                }
            }
        }
    }
}
EOF

}

function start_info(){
    i=0
    until [[ -s /var/lib/caddy/certificates/acme-v02.api.letsencrypt.org-directory/$domain/$domain.crt && -s /var/lib/caddy/certificates/acme-v02.api.letsencrypt.org-directory/$domain/$domain.key ]]; do
        echo waiting for caddy acme tls module...
        sleep 3
        i=$((i+1))
        [[ $i -eq 10 ]] && systemctl restart caddy
        [[ $i -gt 20 ]] && echo caddy tls err && exit 1
    done
    systemctl enable caddy xray && systemctl restart caddy xray && sleep 3 && systemctl status caddy xray | grep -A 2 "service" | tee $TMPFILE
    grep -qE "failed" $TMPFILE && echo errrrrr && exit 1
    cat <<EOF >$TMPFILE
$(date) $domain xfly:

vless: $uuid + tls

trojan://$uuid@$domain:443#$domain-trojan

naiveproxy: https://$uuid:$uuid@$domain
probe_resistance: $uuid.com
shadowrocket use http2

$(date) Visit: https://$domain
EOF

    cat $TMPFILE | tee /var/log/${TMPFILE##*/} && echo && echo $(date) Info saved: /var/log/${TMPFILE##*/}
}

function remov_it(){
    apt purge caddy -y
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove --purge
    return 0
}

function main(){
    [[ "$domain" == "remov_it" ]] && remov_it && exit 0
    install_xray_caddy
    config_xray_caddy
    start_info
}

main
