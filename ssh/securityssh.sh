#!/usr/bin/env bash
# Usage:
#   bash <(wget -qO- https://raw.githubusercontent.com/azoway/across/main/ssh/securityssh.sh)
# Non-interactive:
#   SSH_PORT=2222 SSH_PUB_KEY='ssh-ed25519 AAAA... comment' bash securityssh.sh
#
# Env:
#   SSH_PORT     custom ssh port (1-65535)
#   SSH_PUB_KEY  public key line (ssh-ed25519 / ssh-rsa / ecdsa-sha2-* / sk-*)
#   RSA_PUB_KEY  legacy alias of SSH_PUB_KEY

set -euo pipefail

# only root can run this script
[[ $EUID -ne 0 ]] && { echo "Error: this script must be run as root!" >&2; exit 1; }

SSHD_CONFIG="${SSHD_CONFIG:-/etc/ssh/sshd_config}"
AUTHORIZED_KEYS="${AUTHORIZED_KEYS:-/root/.ssh/authorized_keys}"

is_valid_port() {
    local p="$1"
    [[ "$p" =~ ^[0-9]+$ ]] || return 1
    ((10#$p >= 1 && 10#$p <= 65535))
}

is_valid_pubkey() {
    local key="$1"
    # OpenSSH public key line: type base64 [comment]
    [[ "$key" =~ ^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp(256|384|521)|sk-ssh-ed25519@openssh\.com|sk-ecdsa-sha2-nistp256@openssh\.com)[[:space:]]+[A-Za-z0-9+/=]+([[:space:]].*)?$ ]]
}

set_sshd_option() {
    # set_sshd_option Key Value  — replace existing or append
    local key="$1" value="$2" conf="$SSHD_CONFIG"
    if grep -qE "^[#[:space:]]*${key}[[:space:]]" "$conf"; then
        sed -i -E "s|^[#[:space:]]*${key}[[:space:]].*|${key} ${value}|" "$conf"
    else
        printf '\n%s %s\n' "$key" "$value" >>"$conf"
    fi
}

# custom port
echo
echo "$(date) securing your ssh server with custom port..."
SSH_PORT="${SSH_PORT:-}"
while ! is_valid_port "${SSH_PORT:-}"; do
    read -r -p "custom ssh port (1-65535): " SSH_PORT </dev/tty
done

# custom public key (keep RSA_PUB_KEY as legacy env name)
echo
echo "$(date) securing your ssh server with authorized_keys..."
SSH_PUB_KEY="${SSH_PUB_KEY:-${RSA_PUB_KEY:-}}"
while ! is_valid_pubkey "${SSH_PUB_KEY:-}"; do
    read -r -p "public key (ed25519/rsa/ecdsa/sk-*): " SSH_PUB_KEY </dev/tty
done

# confirm
echo
echo "$(date) waiting for confirm..."
echo "port:     ${SSH_PORT}"
echo "pub_key:  ${SSH_PUB_KEY}"
echo
read -r -p "is_confirm? [y/n] " is_confirm </dev/tty
if [[ ${is_confirm} != "y" && ${is_confirm} != "Y" ]]; then
    echo
    echo "canceled..."
    exit 0
fi

# backup config
bakname="$(date +%Y%m%d%H%M%S)"
cp -a "$SSHD_CONFIG" "${SSHD_CONFIG}.${bakname}.bak"

# port
if grep -qE '^Port[[:space:]]+[0-9]+' "$SSHD_CONFIG"; then
    sed -i -E "s|^Port[[:space:]]+[0-9]+|Port ${SSH_PORT}|" "$SSHD_CONFIG"
elif grep -qE '^#Port[[:space:]]+[0-9]+' "$SSHD_CONFIG"; then
    sed -i -E "s|^#Port[[:space:]]+[0-9]+|Port ${SSH_PORT}|" "$SSHD_CONFIG"
else
    printf '\nPort %s\n' "$SSH_PORT" >>"$SSHD_CONFIG"
fi

# root key-only login + disable password / keyboard-interactive
set_sshd_option PermitRootLogin prohibit-password
set_sshd_option PasswordAuthentication no
set_sshd_option KbdInteractiveAuthentication no
set_sshd_option ChallengeResponseAuthentication no
set_sshd_option PubkeyAuthentication yes

# authorized_keys
mkdir -p /root/.ssh
chmod 700 /root/.ssh
touch "$AUTHORIZED_KEYS"
chmod 600 "$AUTHORIZED_KEYS"
# append then uniquify by whole line
printf '%s\n' "$SSH_PUB_KEY" >>"$AUTHORIZED_KEYS"
sort -u "$AUTHORIZED_KEYS" -o "$AUTHORIZED_KEYS"
chmod 600 "$AUTHORIZED_KEYS"

# validate config before restart — restore backup on failure
if ! sshd -t -f "$SSHD_CONFIG"; then
    echo "Error: sshd config test failed, restoring backup..." >&2
    cp -a "${SSHD_CONFIG}.${bakname}.bak" "$SSHD_CONFIG"
    exit 1
fi

# restart (Debian: ssh; some systems: sshd)
if systemctl list-unit-files 2>/dev/null | grep -qE '^ssh\.service'; then
    systemctl restart ssh
elif systemctl list-unit-files 2>/dev/null | grep -qE '^sshd\.service'; then
    systemctl restart sshd
elif command -v service >/dev/null 2>&1; then
    service ssh restart 2>/dev/null || service sshd restart
else
    echo "Error: cannot find ssh/sshd service to restart" >&2
    exit 1
fi

echo
echo "$(date) done."
echo "  port:       ${SSH_PORT}"
echo "  login:      root via authorized_keys only (password auth disabled)"
echo "  backup:     ${SSHD_CONFIG}.${bakname}.bak"
echo "  keep this session open and verify: ssh -p ${SSH_PORT} root@<host>"
