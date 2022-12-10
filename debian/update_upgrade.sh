#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin; export PATH
## 自用脚本，记录为主，勿执行

# tempfile & rm it when exit
trap 'rm -f "$TMPFILE"' EXIT; TMPFILE=$(mktemp) || exit 1

declare -A dic_d && dic_d=( \
[buster]="10"
[bullseye]="11"
[bookworm]="12"
)

function _version(){
    # 获取本机版本信息
    command -v hostnamectl > /dev/null 2>&1 || { echo >&2 "DO NOT RUN THIS SCRIPT"; exit 1; }
    hostnamectl | grep -oE "Operating System.*" | grep -qE "Debian" || { echo >&2 "DO NOT RUN THIS SCRIPT"; exit 1; }
    this_versnum=$(hostnamectl | grep -oE "Operating System.*" | grep -oE "[0-9]+") && [[ $this_versnum == "" ]] && this_versnum=0
    if [[ $this_versnum -lt 10 ]]; then
        echo Not available in versions of Debian lower than 10 && exit 1
    fi
    
    # 从 http://deb.debian.org/debian/dists/README 获取目前稳定版本名称代号
    curl -sLA "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/108.0.0.0 Safari/537.36" --retry 5 "http://deb.debian.org/debian/dists/README" -o $TMPFILE
    for key in ${!dic_d[*]}; do
        grep -oE "^stable.*" $TMPFILE | grep -qE "$key" && stable_version="$key" && stable_versnum=$(echo ${dic_d[$key]})
    done
    if [[ $stable_version == "" || $stable_versnum == "" ]]; then
        echo $(date) stable version err && exit 1
    else
        echo $(date) stable version - debian $stable_versnum - $stable_version
    fi
    
    # 判断能否升级
    x_versnum=$((stable_versnum-this_versnum))
    if [[ $x_versnum == 0 ]]; then
        echo Debian $this_versnum is a stable release && exit 0
    elif [[ $x_versnum -lt 0 ]]; then
        echo Does not support downgrade operations && exit 0
    elif [[ $x_versnum -gt 1 ]]; then
        next_ver=$((this_versnum+1))
        for key in ${!dic_d[*]}; do
            [[ "${dic_d[$key]}" = "$next_ver" ]] && stable_version="$key" && stable_versnum=$(echo ${dic_d[$key]})
        done
        echo Debian $this_versnum can be upgraded - debian $stable_versnum - $stable_version
    else [[ $x_versnum == 1 ]]; then
        echo Debian $this_versnum can be upgraded to a stable release - debian $stable_versnum - $stable_version
    fi
}

function _sources(){
    cp -f /etc/apt/sources.list /etc/apt/sources.list.bak_$(date +%s)_
    cat <<EOF > /etc/apt/sources.list
deb http://deb.debian.org/debian $stable_version main
deb-src http://deb.debian.org/debian $stable_version main
deb http://security.debian.org/debian-security ${stable_version}-security main
deb-src http://security.debian.org/debian-security ${stable_version}-security main
deb http://deb.debian.org/debian ${stable_version}-updates main
deb-src http://deb.debian.org/debian ${stable_version}-updates main
deb http://deb.debian.org/debian ${stable_version}-backports main
deb-src http://deb.debian.org/debian ${stable_version}-backports main
EOF
}

function _upupup(){
    apt-get update -y
    apt-get upgrade
    apt-get autoremove
    apt-get autoclean
    _sources
    apt-get update -y
    apt-get upgrade
    apt-get dist-upgrade
    apt-get autoremove
    apt-get autoclean
}

function main(){
    _version
    _upupup
}

main