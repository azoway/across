#!/usr/bin/env bash
# Wiki: https://github.com/zhanghanyun/speedtest-rs
# Usage: bash <(curl -s https://raw.githubusercontent.com/azoway/across/main/speedtest/speedtest-rs.sh) my.domain.com
# Uninstall: apt purge caddy -y; systemctl stop speedtest-rs; systemctl disable speedtest-rs; rm -rf /etc/systemd/system/speedtest-rs.service /usr/bin/speedtest-rs

# tempfile & rm it when exit
trap 'rm -f "$TMPFILE"' EXIT && TMPFILE=$(mktemp) || exit 1

### dependencies
command -v unzip > /dev/null 2>&1 || { echo "Please install unzip： apt update && apt install unzip -y"; exit 1; }

# domain
[[ $# == 1 ]] && domain="$1" || { echo Err !!! Useage: bash this_script.sh my.domain.com; exit 1; }

# speedtest-rs 
URL="$(wget -qO- https://api.github.com/repos/zhanghanyun/speedtest-rs/releases/latest | grep -E "browser_download_url.*linux-amd64" | cut -f4 -d\")"
rm -rf /usr/bin/speedtest-rs
wget -O $TMPFILE $URL && unzip $TMPFILE -d /usr/bin/ && chmod +x /usr/bin/speedtest-rs

cat <<EOF > /etc/systemd/system/speedtest-rs.service
[Unit]
Description=speedtest-rs
[Service]
ExecStart=/usr/bin/speedtest-rs --ip 127.0.0.1 --port 18088
Restart=always
User=root
[Install]
WantedBy=multi-user.target
EOF

# caddy
caddyURL="$(wget -qO-  https://api.github.com/repos/caddyserver/caddy/releases | grep -E "browser_download_url.*linux_amd64\.deb" | cut -f4 -d\" | head -n1)"
wget -O $TMPFILE $caddyURL && dpkg -i $TMPFILE

cat <<EOF >/etc/caddy/Caddyfile
$domain
reverse_proxy 127.0.0.1:18088
EOF

# systemctl service info
systemctl enable caddy speedtest-rs && systemctl restart caddy speedtest-rs && sleep 3 && systemctl status caddy speedtest-rs | grep -A 2 "service"
echo $(date) Visit: https://$domain
