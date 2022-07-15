#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin; export PATH
# wiki: https://github.com/521xueweihan/GitHub520

# tempfile & rm it when exit
trap 'rm -f "$TMPFILE"' EXIT; TMPFILE=$(mktemp) || exit 1

# get ips
URL="https://cdn.jsdelivr.net/gh/521xueweihan/GitHub520@main/hosts"
wget -qO $TMPFILE $URL

# save
domains=($(cat $TMPFILE | grep -oE "^[^#]*" | awk '{print $2}' | tr "\n" " "))
for onedomain in ${domains[*]}; do sed -i "/$onedomain/d" /etc/hosts; done
cat $TMPFILE | grep -oE "^[^#]*" >>/etc/hosts
