#!/usr/bin/env bash
## 自动获取 AKDNS 最新列表 -> 并行测速 -> 选出最优 -> 整机接管系统 DNS。
## 自愈（兼容每 N 小时 cron）：
##   1. 拉列表走公共 DNS bootstrap，不依赖当前系统解析
##   2. 应用前校验、应用后体检；失败不留下坏 DNS
##   3. glibc 只认 3 条 nameserver：必须给 DEFAULT_DNS 留槽。
##      两次 cron 之间 AKDNS 全死时，解析器自己切到兜底，不必等下次任务
##   4. flock 防止任务重叠写坏 resolv.conf
### 参考：https://github.com/akile-network/aktools

set -u
export PATH="/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/sbin:/usr/local/bin"

RAW_URL="https://raw.githubusercontent.com/akile-network/aktools/refs/heads/main/akdns.sh"
RAW_HOST="raw.githubusercontent.com"
DOMAIN="${DOMAIN:-www.google.com}"
COUNT="${COUNT:-5}"
TIMEOUT="${TIMEOUT:-1}"
# 兜底 DNS（逗号分隔）。会写入系统 nameserver 列表，不只在 cron 运行时才回退。
DEFAULT_DNS="${DEFAULT_DNS:-8.8.8.8,1.1.1.1}"
# glibc MAXNS=3：最多用几个槽给 AKDNS，其余留给 DEFAULT_DNS。默认 2，
# 即 nameserver AK1 / AK2 / 8.8.8.8。改成 1 则是 一个AK + 两个兜底。
AKDNS_SLOTS="${AKDNS_SLOTS:-2}"
MAXNS=3
# 拉列表时用来解析 GitHub 的公共 DNS（逗号分隔），绕开当前系统 DNS
BOOTSTRAP_DNS="${BOOTSTRAP_DNS:-8.8.8.8,1.1.1.1}"
# 应用前/后必须能解析的域名（逗号分隔）；任一失败则视为不健康
HEALTH_DOMAINS="${HEALTH_DOMAINS:-www.google.com,one.one.one.one}"
LOCK_FILE="${LOCK_FILE:-/var/lock/akdns-auto.lock}"
# 测速至少成功次数，低于此值的节点直接丢弃（不再记成 1000ms 参与排名）
MIN_SUCCESS="${MIN_SUCCESS:-2}"
HEALTH_RETRIES="${HEALTH_RETRIES:-3}"

BEST3=()
APPLY_NS=()
DNS_LIST=()
DNS_USE_TCP=false

need_cmd() { command -v "$1" &>/dev/null; }

log() { echo "[$(date '+%F %T')] $*"; }

as_root() {
  if [[ $EUID -ne 0 ]]; then
    exec sudo -E bash "$0" "$@"
  fi
}

acquire_lock() {
  local dir
  dir="$(dirname "$LOCK_FILE")"
  mkdir -p "$dir" 2>/dev/null || true
  if ! need_cmd flock; then
    log "未找到 flock，跳过互斥锁" >&2
    return 0
  fi
  if ! exec 9>"$LOCK_FILE"; then
    log "无法创建锁文件 $LOCK_FILE，继续执行" >&2
    return 0
  fi
  if ! flock -n 9; then
    log "已有实例在运行，跳过本次 cron"
    exit 0
  fi
}

run_dig() {
  if need_cmd timeout; then
    timeout 3 dig "$@"
  else
    dig "$@"
  fi
}

is_ipv4() {
  local ip="$1" a b c d
  [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
  IFS=. read -r a b c d <<<"$ip"
  (( a<=255 && b<=255 && c<=255 && d<=255 )) || return 1
  (( a!=0 && a!=127 && a<224 ))
}

csv_ips() {
  local csv="$1" ns
  local -a out=()
  IFS=',' read -r -a _tmp <<<"$csv"
  for ns in "${_tmp[@]}"; do
    ns="${ns// /}"
    is_ipv4 "$ns" && out+=("$ns")
  done
  printf '%s\n' "${out[@]+"${out[@]}"}"
}

set_best_from_csv() {
  mapfile -t BEST3 < <(csv_ips "$1")
}

ns_in_list() {
  local needle="$1" x
  shift
  for x in "$@"; do
    [[ "$x" == "$needle" ]] && return 0
  done
  return 1
}

# 组装实际写入系统的 nameserver：AKDNS 在前，DEFAULT_DNS 垫底。
# 必须给兜底留槽，否则每 N 小时跑一次时，中间 AKDNS 全死就会断解析。
compose_apply_ns() {
  local ns fb
  local -a aks=() fbs=()
  local slots="$AKDNS_SLOTS"

  mapfile -t fbs < <(csv_ips "$DEFAULT_DNS")
  (( ${#fbs[@]} > 0 )) || fbs=(8.8.8.8 1.1.1.1)

  [[ "$slots" =~ ^[0-9]+$ ]] || slots=1
  (( slots < 0 )) && slots=0
  # 至少留 1 个槽给兜底
  (( slots > MAXNS - 1 )) && slots=$((MAXNS - 1))

  for ns in "${BEST3[@]+"${BEST3[@]}"}"; do
    ns="${ns// /}"
    is_ipv4 "$ns" || continue
    ns_in_list "$ns" "${aks[@]+"${aks[@]}"}" && continue
    aks+=("$ns")
    (( ${#aks[@]} >= slots )) && break
  done

  APPLY_NS=()
  for ns in "${aks[@]+"${aks[@]}"}" "${fbs[@]}"; do
    ns="${ns// /}"
    is_ipv4 "$ns" || continue
    ns_in_list "$ns" "${APPLY_NS[@]+"${APPLY_NS[@]}"}" && continue
    APPLY_NS+=("$ns")
    (( ${#APPLY_NS[@]} >= MAXNS )) && break
  done

  local has_fb=0
  for ns in "${APPLY_NS[@]+"${APPLY_NS[@]}"}"; do
    ns_in_list "$ns" "${fbs[@]}" && has_fb=1 && break
  done
  if (( has_fb == 0 )); then
    if (( ${#APPLY_NS[@]} >= MAXNS )); then
      APPLY_NS[$((MAXNS - 1))]="${fbs[0]}"
    else
      APPLY_NS+=("${fbs[0]}")
    fi
  fi

  (( ${#APPLY_NS[@]} > 0 ))
}

# 用公共 DNS 解析主机名，不走系统 resolv.conf
public_resolve() {
  local name="$1" ns ip
  local -a resolvers=()
  mapfile -t resolvers < <(csv_ips "$BOOTSTRAP_DNS")
  (( ${#resolvers[@]} > 0 )) || return 1
  need_cmd dig || return 1
  for ns in "${resolvers[@]}"; do
    ip="$(run_dig @"$ns" "$name" +short +time=2 +tries=1 A 2>/dev/null \
          | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -n1)"
    [[ -n "${ip:-}" ]] && { echo "$ip"; return 0; }
    ip="$(run_dig @"$ns" "$name" +short +time=2 +tries=1 +tcp A 2>/dev/null \
          | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -n1)"
    [[ -n "${ip:-}" ]] && { echo "$ip"; return 0; }
  done
  return 1
}

# 拉列表：先 bootstrap --resolve，再退回当前系统 DNS
curl_fetch() {
  local ip
  if ip="$(public_resolve "$RAW_HOST")"; then
    curl -4 -fsSL --connect-timeout 8 --max-time 20 \
      --resolve "${RAW_HOST}:443:${ip}" "$RAW_URL" && return 0
    log "bootstrap curl 失败，改用当前系统 DNS 重试" >&2
  else
    log "bootstrap 解析 $RAW_HOST 失败，改用当前系统 DNS" >&2
  fi
  curl -4 -fsSL --connect-timeout 8 --max-time 20 "$RAW_URL"
}

fetch_dns_list() {
  if ! need_cmd curl; then
    log "缺少 curl，跳过拉列表" >&2
    return 1
  fi
  local raw
  raw="$(curl_fetch)" || { log "下载 AKDNS 列表失败：$RAW_URL" >&2; return 1; }
  echo "$raw" \
    | sed -n '/^[[:space:]]*DNS_LIST[[:space:]]*=[[:space:]]*(/,/^[[:space:]]*)/p' \
    | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | sort -u \
    | while read -r ip; do
        is_ipv4 "$ip" && echo "$ip"
      done
}

# 指定 nameserver 能否解析某个域名（UDP，失败再试 TCP）
ns_can_resolve() {
  local ns="$1" name="$2" ans
  need_cmd dig || return 1
  ans="$(run_dig @"$ns" "$name" +short +time=2 +tries=1 A 2>/dev/null \
        | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -n1)"
  [[ -n "${ans:-}" ]] && return 0
  ans="$(run_dig @"$ns" "$name" +short +time=2 +tries=1 +tcp A 2>/dev/null \
        | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -n1)"
  if [[ -n "${ans:-}" ]]; then
    DNS_USE_TCP=true
    return 0
  fi
  return 1
}

ns_is_healthy() {
  local ns="$1" d
  local -a domains=()
  IFS=',' read -r -a domains <<<"$HEALTH_DOMAINS"
  for d in "${domains[@]}"; do
    d="${d// /}"
    [[ -n "$d" ]] || continue
    ns_can_resolve "$ns" "$d" || return 1
  done
  return 0
}

# 测当前系统解析（应用看到的），而不是某个 @server
system_dns_ok() {
  local d
  local -a domains=()
  IFS=',' read -r -a domains <<<"$HEALTH_DOMAINS"
  for d in "${domains[@]}"; do
    d="${d// /}"
    [[ -n "$d" ]] || continue
    if getent ahostsv4 "$d" 2>/dev/null | grep -Eq '([0-9]{1,3}\.){3}[0-9]{1,3}'; then
      continue
    fi
    if need_cmd dig && run_dig +time=2 +tries=1 +short "$d" A 2>/dev/null \
         | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
      continue
    fi
    return 1
  done
  return 0
}

wait_system_dns_ok() {
  local i
  for ((i=1; i<=HEALTH_RETRIES; i++)); do
    system_dns_ok && return 0
    sleep 1
  done
  return 1
}

validate_best3() {
  local ns
  local -a good=()
  for ns in "${BEST3[@]+"${BEST3[@]}"}"; do
    ns="${ns// /}"
    is_ipv4 "$ns" || continue
    if ns_is_healthy "$ns"; then
      good+=("$ns")
    else
      log "丢弃不可用 DNS: $ns" >&2
    fi
  done
  BEST3=("${good[@]+"${good[@]}"}")
  (( ${#BEST3[@]} > 0 ))
}

run_speed_test() {
  if ! need_cmd dig; then
    log "缺少 dig，跳过测速" >&2
    return 2
  fi
  (( ${#DNS_LIST[@]} > 0 )) || return 2

  local tmpdir t
  tmpdir="$(mktemp -d)" || { log "无法创建临时目录" >&2; return 2; }
  trap 'rm -rf "${tmpdir:-}"' RETURN

  echo
  echo "AKDNS 测速"
  echo "域名   : $DOMAIN"
  echo "次数   : $COUNT"
  echo "超时   : ${TIMEOUT}s"
  echo "------------------------------------"
  echo "正在测速，请稍候..."

  local dns i
  for dns in "${DNS_LIST[@]}"; do
    [[ -n "$dns" ]] || continue
    is_ipv4 "$dns" || continue
    for ((i=1; i<=COUNT; i++)); do
      (
        t="$(run_dig @"$dns" "$DOMAIN" +stats +time="$TIMEOUT" +tries=1 2>/dev/null \
              | awk '/Query time/ {print $4}')"
        # 超时/失败不记 1000，直接丢弃，避免半死节点进前三
        if [[ -n "${t:-}" && "$t" =~ ^[0-9]+$ && "$t" -lt 1000 ]]; then
          echo "$dns $t"
        fi
      ) >"$tmpdir/result_${dns}_${i}" &
    done
  done

  wait

  cat "$tmpdir"/result_* 2>/dev/null >"$tmpdir/all" || true
  if [[ ! -s "$tmpdir/all" ]]; then
    log "测速失败: 未获取到任何成功结果" >&2
    return 2
  fi

  echo
  echo "平均响应时间 (成功次数 >= $MIN_SUCCESS):"
  echo "------------------------------------"
  awk -v min="$MIN_SUCCESS" '
    { sum[$1]+=$2; cnt[$1]++ }
    END {
      for (d in sum)
        if (cnt[d] >= min) printf "%d %s\n", sum[d]/cnt[d], d
    }
  ' "$tmpdir/all" | sort -n | tee "$tmpdir/avg"

  if [[ ! -s "$tmpdir/avg" ]]; then
    log "没有节点达到最少成功次数 $MIN_SUCCESS" >&2
    return 2
  fi

  mapfile -t BEST3 < <(head -n 3 "$tmpdir/avg" | awk '{print $2}')
  echo "------------------------------------"
  echo "最佳 DNS 候选: ${BEST3[*]}"
  return 0
}

apply_with_resolved() {
  local iface
  iface="$(ip route 2>/dev/null | awk '/default/ {print $5; exit}')"
  [[ -n "${iface:-}" ]] || { log "无法自动识别默认网卡接口" >&2; return 1; }

  resolvectl dns "$iface" "${APPLY_NS[@]}" || return 1
  # 整机接管：该接口作为所有域名的默认解析路径，避免 DHCP DNS 继续分流
  resolvectl default-route "$iface" true >/dev/null 2>&1 || true
  resolvectl domain "$iface" '~.' >/dev/null 2>&1 || true
  resolvectl flush-caches >/dev/null 2>&1 || true
  log "已通过 systemd-resolved 为接口 $iface 应用 DNS: ${APPLY_NS[*]}"
}

write_resolv_conf_plain() {
  local tmp ns
  (( ${#APPLY_NS[@]} > 0 )) || return 1
  tmp="$(mktemp /tmp/resolv.conf.akdns.XXXXXX)" || return 1
  {
    echo "# Generated by akdns-auto.sh $(date '+%F %T')"
    echo "# AKDNS first, DEFAULT_DNS as glibc failover (MAXNS=3)"
    for ns in "${APPLY_NS[@]}"; do
      ns="${ns// /}"
      printf "nameserver %s\n" "$ns"
    done
    # attempts:1：第一条 AKDNS 超时后立刻试兜底，避免 N 小时间隔里卡在死节点上
    if [[ "$DNS_USE_TCP" == true ]]; then
      echo "options timeout:2 attempts:1 use-vc"
    else
      echo "options timeout:2 attempts:1"
    fi
  } >"$tmp"
  chmod 644 "$tmp"

  if [[ -L /etc/resolv.conf ]]; then
    rm -f /etc/resolv.conf
  else
    chattr -i /etc/resolv.conf 2>/dev/null || true
  fi

  if ! mv -f "$tmp" /etc/resolv.conf; then
    log "写入 /etc/resolv.conf 失败" >&2
    rm -f "$tmp"
    return 1
  fi
  # 锁住，避免 dhclient / cloud-init / NM 在两次 cron 之间把 DNS 改坏
  chattr +i /etc/resolv.conf 2>/dev/null || true
  log "已写入 /etc/resolv.conf:"
  cat /etc/resolv.conf
}

# 先把带兜底的列表落到 /etc/resolv.conf（N 小时间隔必须靠文件，不能只靠 resolvectl）
apply_dns() {
  compose_apply_ns || return 1
  log "将应用 nameserver: ${APPLY_NS[*]}"

  write_resolv_conf_plain || return 1

  if need_cmd systemctl && systemctl is-active --quiet systemd-resolved.service && need_cmd resolvectl; then
    apply_with_resolved || log "resolvectl 设置失败，已依赖 /etc/resolv.conf" >&2
  fi

  wait_system_dns_ok
}

keep_current_or_default() {
  local reason="$1"
  log "$reason" >&2
  if system_dns_ok; then
    log "当前系统 DNS 正常，保持不变，等待下次 cron 重试"
    exit 0
  fi
  log "当前系统 DNS 异常，回退 DEFAULT_DNS: $DEFAULT_DNS" >&2
  set_best_from_csv "$DEFAULT_DNS"
}

main() {
  as_root "$@"
  acquire_lock

  if need_cmd curl; then
    mapfile -t DNS_LIST < <(fetch_dns_list || true)
  else
    log "缺少 curl，跳过拉列表" >&2
  fi

  BEST3=()
  if (( ${#DNS_LIST[@]} > 0 )); then
    if ! run_speed_test; then
      log "测速未得到可用 AKDNS" >&2
      BEST3=()
    fi
  else
    log "未能从上游解析到 DNS 列表" >&2
  fi

  if (( ${#BEST3[@]} > 0 )); then
    validate_best3 || BEST3=()
  fi

  if (( ${#BEST3[@]} == 0 )); then
    keep_current_or_default "无通过校验的 AKDNS"
  fi

  if apply_dns; then
    log "系统 DNS 健康检查通过: ${APPLY_NS[*]}"
    exit 0
  fi

  log "应用后健康检查失败，回退 DEFAULT_DNS: $DEFAULT_DNS" >&2
  set_best_from_csv "$DEFAULT_DNS"
  DNS_USE_TCP=false
  if ns_is_healthy "${BEST3[0]}"; then
    :
  elif need_cmd dig && ns_can_resolve "${BEST3[0]}" "$DOMAIN"; then
    DNS_USE_TCP=true
  fi

  if apply_dns; then
    log "已回退 DEFAULT_DNS 且健康检查通过: ${APPLY_NS[*]}"
    exit 0
  fi

  log "健康检查仍失败，仍写入 DEFAULT_DNS 作为最后兜底" >&2
  set_best_from_csv "$DEFAULT_DNS"
  compose_apply_ns || true
  write_resolv_conf_plain || true
  exit 1
}

main "$@"
