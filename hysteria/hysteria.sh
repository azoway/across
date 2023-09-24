#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin; export PATH

# tempfile & rm it when exit
trap 'rm -f "$TMPFILE"' EXIT; TMPFILE=$(mktemp) || exit 1

########
[[ $# != 1 ]] && [[ $# != 2 ]] && echo Err  !!! Useage: bash this_script.sh uuid my.domain.com && exit 1
[[ $# == 1 ]] && uuid="$(cat /proc/sys/kernel/random/uuid)" && domain="$1"
[[ $# == 2 ]] && uuid="$1" && domain="$2"
########

function _install(){
    bash <(curl -s https://raw.githubusercontent.com/HyNetwork/hysteria/master/scripts/install_server.sh)
}

function _config(){
    cat <<EOF >/etc/hysteria/config.yaml
acme:
  domains:
    - $domain
  email: admin@$domain 

auth:
  type: password
  userpass:
    $uuid: $uuid
EOF
}

function _info(){
    systemctl enable hysteria-server && systemctl restart hysteria-server && sleep 3 && systemctl status hysteria-server | grep -A 2 "service" | tee $TMPFILE
    cat <<EOF >$TMPFILE
$(date)
server: hysteria2://$uuid:$uuid@$domain
EOF
    cat $TMPFILE | tee /var/log/${TMPFILE##*/} && echo && echo $(date) Info saved: /var/log/${TMPFILE##*/}
}

function main(){
    _install
    _config
    _info
}

main
