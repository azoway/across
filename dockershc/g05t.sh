#!/bin/sh
## 用于https://github.com/mixool/dockershc项目安装运行gost的脚本

if [[ "$(command -v workerone)" == "" ]]; then
    # install and rename
    gost_URL="$(wget -qO- https://api.github.com/repos/ginuerzh/gost/releases/latest | grep -E "browser_download_url.*linux-amd64" | cut -f4 -d\")"
    wget -O - $gost_URL | gzip -d > /usr/bin/workerone && chmod +x /usr/bin/workerone
else
    # start 
    workerone -L=ss+ws://AEAD_CHACHA20_POLY1305:password@:3000?path=/gostpath >/dev/null 2>&1
fi
