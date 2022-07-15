#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin; export PATH
# Usage: 把爆破我SSH的IP提交到GIST: https://gist.githubusercontent.com/mixool/495619a89bdd4da11e80115a82d177fe/raw
# wget -O /opt/blackholeips.sh https://raw.githubusercontent.com/mixool/across/master/personal/blackholeips.sh && chmod +x /opt/blackholeips.sh && /opt/blackholeips.sh $gist_token
## gist_token=***********; (crontab -l; echo "0 8 * * * /opt/blackholeips.sh $gist_token") | crontab -

# tempfile & rm it when exit
trap 'rm -f "$TMPFILE"' EXIT; TMPFILE=$(mktemp) || exit 1

# update gist file, leave them blank if no need
gist_token="$1"
gist_filename="blackhole_ssh.ips"
gist_fileuid="495619a89bdd4da11e80115a82d177fe"
#

# 获取GIST的IP列表
wget -qO- "https://gist.githubusercontent.com/mixool/$gist_fileuid/raw" | grep -oE "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" >$TMPFILE

# 获取nft的爆破记录 https://github.com/mixool/across/blob/master/nftables/nft.sh
nft list set inet my_table blackhole | grep -oE "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | sort -u >>$TMPFILE
sort -u $TMPFILE -o $TMPFILE

# gist update
if [[ $gist_filename != "" ]] && [[ $gist_fileuid != "" ]] && [[ $gist_token != "" ]]; then
    command -v gist-paste > /dev/null 2>&1 || apt install gist -y
    umask 0077 && echo $gist_token > ~/.gist
    echo; echo $(date) gist: $(gist-paste -pR -u $gist_fileuid -f $gist_filename $TMPFILE)
fi
