#!/usr/bin/env bash
# Wiki: https://github.com/iovxw/rssbot https://github.com/nadam/userinfobot https://core.telegram.org/bots#3-how-do-i-create-a-bot
# Usage: bash <(curl -s https://raw.githubusercontent.com/tdcnull/across/main/rssbot/rssbot.sh) --single-user <userid> <token>
# Uninstall: systemctl stop rssbot; systemctl disable rssbot; rm -rf /etc/systemd/system/rssbot.service /usr/bin/rssbot

[[ $# != 0 ]] && METHOD=$(echo $@) || exit 1

URL="$(wget -qO- https://api.github.com/repos/iovxw/rssbot/releases/latest | grep -E "browser_download_url.*rssbot-en-amd64-linux" | cut -f4 -d\")"
rm -rf /usr/bin/rssbot
wget -O /usr/bin/rssbot $URL && chmod +x /usr/bin/rssbot

cat <<EOF > /etc/systemd/system/rssbot.service
[Unit]
Description=rssbot
[Service]
ExecStart=/usr/bin/rssbot $METHOD
Restart=always
User=root
[Install]
WantedBy=multi-user.target
EOF

systemctl enable rssbot.service && systemctl daemon-reload && systemctl restart rssbot.service && systemctl status rssbot