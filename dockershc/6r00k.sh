#!/bin/sh
## 用于https://github.com/mixool/dockershc项目安装运行brook的脚本

if [[ "$(command -v workerone)" == "" ]]; then
    # install and rename
    wget -O /usr/bin/workerone https://github.com/txthinking/brook/releases/latest/download/brook_linux_amd64 && chmod +x /usr/bin/workerone
else
    # start 
    workerone wsserver -l 0.0.0.0:3000 --path /brookpath -p password >/dev/null 2>&1
fi
