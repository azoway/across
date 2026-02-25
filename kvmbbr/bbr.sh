#!/usr/bin/env bash
## bash <(curl -sSL https://raw.githubusercontent.com/azoway/across/main/kvmbbr/bbr.sh)
### https://github.com/klzgrad/naiveproxy/wiki/Performance-Tuning

set -euo pipefail

# root check
if [[ $EUID -ne 0 ]]; then
  echo "Error: This script must be run as root."
  exit 1
fi

# OS check
if [[ ! -r /etc/os-release ]]; then
  echo "Error: /etc/os-release not found."
  exit 1
fi

# Debian >= 12
DEB_VER=$(grep -oP '(?<=^VERSION_ID=")[0-9]+' /etc/os-release || true)
if [[ -z "${DEB_VER}" || "$DEB_VER" -lt 12 ]]; then
  echo "Error: Debian version must be >= 12."
  exit 1
fi

# Write sysctl.d file (modular; does not touch /etc/sysctl.conf)
mkdir -p /etc/sysctl.d
cat > /etc/sysctl.d/99-azoway-bbr.conf <<'EOF'
net.core.default_qdisc              = fq
net.ipv4.tcp_congestion_control     = bbr
net.ipv4.tcp_slow_start_after_idle  = 0
net.ipv4.tcp_notsent_lowat          = 131072
net.ipv4.tcp_rmem                   = 4096 131072 67108864
net.ipv4.tcp_wmem                   = 4096 131072 67108864
EOF

# Ensure modules available (harmless if built-in)
mkdir -p /etc/modules-load.d
printf "tcp_bbr\nsch_fq\n" > /etc/modules-load.d/bbr-fq.conf
modprobe tcp_bbr 2>/dev/null || true
modprobe sch_fq  2>/dev/null || true

# Load only this file to avoid extra noise/overrides
sysctl -p /etc/sysctl.d/99-azoway-bbr.conf

echo "BBR + fq applied (loaded: /etc/sysctl.d/99-azoway-bbr.conf). Done."