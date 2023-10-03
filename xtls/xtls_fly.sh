#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin; export PATH

# tempfile & rm it when exit
trap 'rm -f "$TMPFILE"' EXIT; TMPFILE=$(mktemp) || exit 1

########
all_parameter=($(echo $@))
uuid=$(echo ${all_parameter[*]} | tr ' ' '\n' | grep -oE "uuid@.*" | cut -f2 -d@ | head -n1)
domain=$(echo ${all_parameter[*]} | tr ' ' '\n' | grep -oE "domain@.*" | cut -f2 -d@ | head -n1)
fake_domain=$(echo ${all_parameter[*]} | tr ' ' '\n' | grep -oE "fk@.*" | cut -f2 -d@ | head -n1)
private_key=$(echo ${all_parameter[*]} | tr ' ' '\n' | grep -oE "pk@.*" | cut -f2 -d@ | head -n1)
if [[ "$domain" == "" ]]; then
     echo Err  !!! Useage: bash this_script.sh domain@my.domain.com && exit 1
fi
########

function _install(){
    # caddy install
    caddyURL="$(wget -qO- https://api.github.com/repos/caddyserver/caddy/releases | grep -E "browser_download_url.*linux_$(dpkg --print-architecture)\.deb" | cut -f4 -d\" | head -n1)"
    naivecaddyURL="$(wget -qO- https://api.github.com/repos/lxhao61/integrated-examples/releases | grep -E "browser_download_url.*linux-$(dpkg --print-architecture)\.tar.gz" | cut -f4 -d\" | head -n1)"
    wget -O $TMPFILE $caddyURL && dpkg -i $TMPFILE
    wget -4 -O $TMPFILE $naivecaddyURL && tar -zxf $TMPFILE -C /usr/bin && chmod +x /usr/bin/caddy
    if ! grep -qE "^Exec.*\.json" /lib/systemd/system/caddy.service; then
        sed -i -e "s/caddy\/Caddyfile/caddy\/Caddyfile\.json/g" /lib/systemd/system/caddy.service 
    fi
    # xray install
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u root
    xray x25519 >$TMPFILE
    if [[ "$uuid" == "" ]]; then
        uuid=$(xray uuid)
    fi
    if [[ "$fake_domain" == "" ]]; then
        fake_domain="www.amazon.com"
    fi
    if [[ "$private_key" == "" ]]; then
        public_key=$(grep -oE "Public key.*" $TMPFILE | cut -d' ' -f3)
        private_key=$(grep -oE "Private key.*" $TMPFILE | cut -d' ' -f3)
    else
        public_key="your_public_key"
    fi 
}

function _config(){
    # config xray
    
    cat <<EOF >/usr/local/etc/xray/config.json
{
	"inbounds": [
		{
			"listen": "@vless.sock",
			"protocol": "vless",
			"settings": {
				"clients": [
					{
						"id": "$uuid",
						"flow": "xtls-rprx-vision"
					}
				],
				"decryption": "none"
			},
			"streamSettings": {
				"network": "tcp",
				"security": "reality",
				"realitySettings": {
					"show": false,
					"dest": "$fake_domain:443",
					"xver": 0,
					"serverNames": [
						"$fake_domain"
					],
					"privateKey": "$private_key",
					"minClientVer": "",
					"maxClientVer": "",
					"maxTimeDiff": 0,
					"shortIds": [
						""
					]
				}
			}
		},
        {"port": 59876,"listen": "127.0.0.1","protocol": "socks","settings": {"auth": "password","accounts": [{"user": "$uuid","pass": "$uuid"}],"udp": true}}
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
	"admin": {
		"disabled": true
	},
	"apps": {
		"layer4": {
			"servers": {
				"yer0": {
					"listen": [":443"],
					"routes": [
						{
							"match": [{"tls": {"sni": ["$domain"]}}],
							"handle": [
								{
									"handler": "proxy",
									"upstreams": [{"dial": ["unix/@https.sock"]}]
								}
							]
						},
						{
							"match": [{"tls": {"sni": ["$fake_domain"]}}],
							"handle": [
								{
									"handler": "proxy",
									"upstreams": [{"dial": ["unix/@vless.sock"]}]
								}
							]
						}
					]
				}
			}
		},
		"http": {
			"servers": {
				"srv1": {
					"listen": [":80"],
					"routes": [
						{
							"match": [{"host": ["$domain"]}],
							"handle": [{"handler": "subroute","routes": [{"handle": [{"handler": "static_response","headers": {"Location": ["https://{http.request.host}{http.request.uri}"]},"status_code": 301}]}]}]
						}
					]
				},
				"srv0": {
					"listen": [
						"unix/@https.sock"
					],
					"listener_wrappers": [
						{
							"wrapper": "trojan"
						}
					],
					"routes": [
						{
							"handle": [
								{
									"auth_pass_deprecated": "$uuid",
									"auth_user_deprecated": "$uuid",
									"handler": "forward_proxy",
									"hide_ip": true,
									"hide_via": true,
									"probe_resistance": {
										"domain": "$uuid.com"
									},
                                    "upstream": "socks5://$uuid:$uuid@127.0.0.1:59876"
								},
								{
									"connect_method": true,
									"handler": "trojan",
									"websocket": true
								}
							]
						},
						{
							"match": [
								{
									"host": [
										"$domain"
									]
								}
							],
							"handle": [
								{
									"handler": "subroute",
									"routes": [
										{
											"handle": [{
												"handler": "file_server",
												"root": "/usr/share/caddy"
											}]
										}
									]
								}
							]
						}
					]
				}
			}
		},
		"tls": {
			"certificates": {
				"automate": [
					"$domain"
				]
			}
		},
		"trojan": {
			"upstream": {
				"upstream": "caddy"
			},
			"proxy": {
				"proxy": "no_proxy"
			},
			"users": [
				"$uuid"
			]
		}
	}
}
EOF
}

function _info(){
    systemctl enable caddy && systemctl restart caddy xray && sleep 3 && systemctl status caddy xray | grep -A 2 "service" | tee $TMPFILE
    cat <<EOF >$TMPFILE
$(date)
reality:
vless://$uuid@$domain:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$fake_domain&fp=chrome&pbk=$public_key&sid=&type=tcp&headerType=none#${domain}-reality

trojan://$uuid@$domain:443#$domain-trojan

naiveproxy(shadowrocket use http2):
https://$uuid:$uuid@$domain
probe_resistance: $uuid.com

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
