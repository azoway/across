#!/usr/bin/env bash
# Wiki: https://docs.ginuerzh.xyz/gost/
# Usage: bash <(curl -s https://raw.githubusercontent.com/tdcnull/across/main/gost/gost.sh) -L=:8080
# Uninstall: systemctl stop gost; systemctl disable gost; rm -rf /etc/systemd/system/gost.service /usr/bin/gost

[[ $# != 0 ]] && METHOD=$(echo $@) || METHOD="-L=ss://AEAD_AES_128_GCM:$(tr -dc 'a-z0-9A-Z' </dev/urandom | head -c 16)@:$(shuf -i 10000-65535 -n1)"

URL="$(wget -qO- https://api.github.com/repos/ginuerzh/gost/releases/latest | grep -E "browser_download_url.*gost-linux-amd64" | cut -f4 -d\")"
rm -rf /usr/bin/gost
wget -O - $URL | gzip -d > /usr/bin/gost && chmod +x /usr/bin/gost

cat <<EOF > /etc/systemd/system/gost.service
[Unit]
Description=gost
[Service]
ExecStart=/usr/bin/gost $METHOD
Restart=always
User=root
[Install]
WantedBy=multi-user.target
EOF

systemctl enable gost.service && systemctl daemon-reload && systemctl restart gost.service && systemctl status gost
