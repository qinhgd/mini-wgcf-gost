#!/bin/sh
set -e

BEST_IP_FILE="/wgcf/best_ips.txt"
RECONNECT_FLAG_FILE="/wgcf/reconnect.flag"
OPTIMIZE_INTERVAL="${OPTIMIZE_INTERVAL:-21600}"
WARP_CONNECT_TIMEOUT="${WARP_CONNECT_TIMEOUT:-5}"
BEST_IP_COUNT="${BEST_IP_COUNT:-20}"
HEALTH_CHECK_INTERVAL="${HEALTH_CHECK_INTERVAL:-60}"
MAX_FAILURES="${MAX_FAILURES:-10}"

green() { echo -e "\033[32m\033[01m$1\033[0m"; }
red() { echo -e "\033[31m\033[01m$1\033[0m"; }

run_ip_selection() {
    green "🌐 优选 WARP IP..."
    /usr/local/bin/warp -t "$WARP_CONNECT_TIMEOUT" > /dev/null
    awk -F, '($2+0)<50 && $3!="timeout ms" {print $1}' result.csv | head -n "$BEST_IP_COUNT" > "$BEST_IP_FILE"
    if [ ! -s "$BEST_IP_FILE" ]; then
        red "❌ 优选失败，使用默认 IP"
        echo "engage.cloudflareclient.com:2408" > "$BEST_IP_FILE"
    else
        green "✅ IP 优选完成，共 $(wc -l < "$BEST_IP_FILE") 个"
    fi
    rm -f result.csv
}

update_wg_endpoint() {
    [ ! -s "$BEST_IP_FILE" ] && run_ip_selection
    IP=$(shuf -n1 "$BEST_IP_FILE")
    sed -i "s/^Endpoint = .*/Endpoint = $IP/" /etc/wireguard/wgcf.conf
    green "🔁 设置新 Endpoint: $IP"
}

check_warp_connection() {
    curl -s --max-time 5 https://www.cloudflare.com/cdn-cgi/trace | grep -q "warp=on"
}

start_gost() {
    if ! pgrep -f gost >/dev/null; then
        green "🚀 启动 GOST 代理 (UDP 支持)"
        gost -L "socks5://0.0.0.0:1080?udp=true" -L "http://0.0.0.0:8080" &
    fi
}

runwgcf() {
    # 注册配置
    [ ! -f wgcf-account.toml ] && wgcf register --accept-tos
    [ ! -f wgcf-profile.conf ] && wgcf generate
    cp wgcf-profile.conf /etc/wireguard/wgcf.conf

    # 启动 IP 优选任务
    [ ! -f "$BEST_IP_FILE" ] && run_ip_selection

    (
        while true; do
            sleep "$OPTIMIZE_INTERVAL"
            run_ip_selection
            touch "$RECONNECT_FLAG_FILE"
        done
    ) &

    while true; do
        local failures=0
        while true; do
            update_wg_endpoint
            wg-quick up wgcf
            if check_warp_connection; then
                green "✅ WireGuard 已连接"
                failures=0
                break
            else
                red "⚠️ 连接失败，重试 ($((++failures))/$MAX_FAILURES)"
                wg-quick down wgcf >/dev/null 2>&1 || true
                sleep 2
            fi
            [ "$failures" -ge "$MAX_FAILURES" ] && exit 1
        done

        start_gost
        green "🟢 进入监控模式..."

        while true; do
            [ -f "$RECONNECT_FLAG_FILE" ] && rm -f "$RECONNECT_FLAG_FILE" && wg-quick down wgcf && break
            sleep "$HEALTH_CHECK_INTERVAL"
            check_warp_connection || ( red "⚠️ 检测到断线，重连..." && wg-quick down wgcf && break )
        done
    done
}

cd /wgcf
runwgcf "$@"
