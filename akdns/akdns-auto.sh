#!/usr/bin/env bash
## 自动获取 AKDNS 最新列表 -> 并行测速 -> 选出前 3 -> 应用为系统 DNS，若全部超时，使用 DEFAULT_DNS。
### 参考：https://github.com/akile-network/aktools

set -u

RAW_URL="https://raw.githubusercontent.com/akile-network/aktools/refs/heads/main/akdns.sh"
DOMAIN="${DOMAIN:-www.google.com}"
COUNT="${COUNT:-5}"
TIMEOUT="${TIMEOUT:-1}"
# 若均超时时使用（逗号分隔）
DEFAULT_DNS="${DEFAULT_DNS:-8.8.8.8,1.1.1.1}"

need_cmd() { command -v "$1" &>/dev/null; }

as_root() {
  if [[ $EUID -ne 0 ]]; then
    exec sudo -E bash "$0" "$@"
  fi
}

fetch_dns_list() {
  if ! need_cmd curl; then
    echo "缺少 curl 请安装 sudo apt update && sudo apt install -y curl" >&2
    exit 1
  fi
  local raw
  raw="$(curl -fsSL "$RAW_URL")" || { echo "下载 AKDNS 列表失败：$RAW_URL" >&2; exit 1; }
  # 提取 DNS_LIST=( ... ) 中所有 IPv4
  echo "$raw" \
    | sed -n '/^[[:space:]]*DNS_LIST[[:space:]]*=[[:space:]]*(/,/^[[:space:]]*)/p' \
    | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | sort -u
}

run_speed_test() {
  # 需要 dig
  if ! need_cmd dig; then
    echo "缺少 dig 请安装 sudo apt update && sudo apt install -y dnsutils" >&2
    exit 1
  fi

  local tmpdir t
  tmpdir="$(mktemp -d)" || { echo "无法创建临时目录" >&2; exit 1; }
  # 关键修复点：RETURN（函数返回时）触发清理；并用 ${tmpdir:-} 防止未定义报错
  trap 'rm -rf "${tmpdir:-}"' RETURN

  echo
  echo "AKDNS 测速"
  echo "域名   : $DOMAIN"
  echo "次数   : $COUNT"
  echo "超时   : ${TIMEOUT}s"
  echo "------------------------------------"
  echo "正在测速，请稍候..."

  while IFS= read -r dns; do
    [[ -n "$dns" ]] || continue
    for ((i=1;i<=COUNT;i++)); do
      (
        t="$(dig @"$dns" "$DOMAIN" +stats +time="$TIMEOUT" +tries=1 2>/dev/null \
              | awk '/Query time/ {print $4}')"
        if [[ -n "$t" ]]; then
          echo "$dns $t"
        else
          echo "$dns 1000"
        fi
      ) >"$tmpdir/result_${dns}_${i}" &
    done
  done < <(printf "%s\n" "${DNS_LIST[@]}")

  wait

  cat "$tmpdir"/result_* 2>/dev/null >"$tmpdir/all" || true
  if [[ ! -s "$tmpdir/all" ]]; then
    echo "测速失败: 未获取到任何结果" >&2
    return 2
  fi

  echo
  echo "平均响应时间:"
  echo "------------------------------------"
  awk '{sum[$1]+=$2;cnt[$1]++} END{for(d in sum){printf "%d %s\n", sum[d]/cnt[d], d}}' "$tmpdir/all" \
    | sort -n | tee "$tmpdir/avg"

  local best_avg
  best_avg="$(head -n1 "$tmpdir/avg" | awk '{print $1}')"
  if [[ -z "$best_avg" || "$best_avg" -ge 1000 ]]; then
    echo "------------------------------------"
    echo "所有 DNS 测速均超时, 将使用 DEFAULT_DNS: $DEFAULT_DNS"
    # 用默认 DNS（转为空格分隔）
    IFS=',' read -r -a BEST3 <<<"$DEFAULT_DNS"
    return 0
  fi

  # 正常取前三
  mapfile -t BEST3 < <(head -n 3 "$tmpdir/avg" | awk '{print $2}')
  echo "------------------------------------"
  echo "最佳 3 个 DNS: ${BEST3[*]}"
  return 0
}

apply_with_resolved() {
  # 使用 systemd-resolved（resolvectl）按接口设置 DNS（推荐做法）
  local iface
  iface="$(ip route 2>/dev/null | awk '/default/ {print $5; exit}')"
  [[ -n "$iface" ]] || { echo "无法自动识别默认网卡接口" >&2; return 1; }

  resolvectl dns "$iface" "${BEST3[@]}" || return 1
  resolvectl flush-caches >/dev/null 2>&1 || true
  echo "已通过 systemd-resolved 为接口 $iface 应用 DNS: ${BEST3[*]}"
}

write_resolv_conf_plain() {
  {
    for ns in "${BEST3[@]}"; do
      printf "nameserver %s\n" "$ns"
    done
  } >/etc/resolv.conf
  echo "已写入 /etc/resolv.conf:"
  cat /etc/resolv.conf
}

main() {
  as_root "$@"

  # 拉取最新 DNS 列表
  mapfile -t DNS_LIST < <(fetch_dns_list)
  if [[ ${#DNS_LIST[@]} -eq 0 ]]; then
    echo "未能从上游脚本解析到 DNS 列表, 将使用 DEFAULT_DNS: $DEFAULT_DNS" >&2
    IFS=',' read -r -a BEST3 <<<"$DEFAULT_DNS"
  else
    # 测速并得到 BEST3（或默认）
    if ! run_speed_test; then
      echo "测速失败, 将使用 DEFAULT_DNS: $DEFAULT_DNS" >&2
      IFS=',' read -r -a BEST3 <<<"$DEFAULT_DNS"
    fi
  fi

  # 优先使用 systemd-resolved
  if systemctl is-active --quiet systemd-resolved.service && need_cmd resolvectl; then
    if apply_with_resolved; then
      # 若 resolv.conf 不是 symlink（极少数场景），同步写入普通 nameserver 列表
      if [[ ! -L /etc/resolv.conf ]]; then
        write_resolv_conf_plain
      fi
      exit 0
    fi
  fi

  # 回退：直接写 /etc/resolv.conf
  write_resolv_conf_plain
}

main "$@"