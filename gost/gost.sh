#!/usr/bin/env bash

# Wiki: https://docs.ginuerzh.xyz/gost/
# Usage: bash <(curl -s https://raw.githubusercontent.com/azoway/across/main/gost/gost.sh) -L=:8080
# Uninstall: systemctl stop gost; systemctl disable gost; rm -rf /etc/systemd/system/gost.service /usr/bin/gost

# 设置默认方法或者从命令行参数获取
[[ $# != 0 ]] && METHOD=$(echo $@) || METHOD="-L=ss://AEAD_AES_128_GCM:$(tr -dc 'a-zA-Z0-9' </dev/urandom | head -c 16)@:$(shuf -i 10000-65535 -n1)"

# 获取最新的 gost 版本下载链接
URL="$(wget -qO- https://api.github.com/repos/ginuerzh/gost/releases/latest | grep -E "browser_download_url.*gost_.*linux_amd64" | cut -f4 -d\" | head -n1)"
if [[ -z "$URL" ]]; then
    echo "Error: Unable to find the latest release URL from GitHub."
    exit 1
fi

# 下载并解压 gost 到 /usr/bin/gost
rm -rf /usr/bin/gost
echo "Downloading gost from $URL..."
wget -qO /usr/bin/gost.tar.gz $URL || { echo "Download failed!"; exit 1; }
tar -zxvf /usr/bin/gost.tar.gz -C /usr/bin/ && chmod +x /usr/bin/gost
rm -f /usr/bin/gost.tar.gz

# 创建 systemd 服务文件
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

# 启用并启动 gost 服务
systemctl enable gost.service && systemctl daemon-reload && systemctl restart gost.service && systemctl status gost
