# resource/cmd_netneig.bash
cmd_netneig() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        err "用法: NETNEIG"
        cecho "扫描当前局域网下的所有存活主机 (自动探测子网)"
        return 0
    fi

    local base
    base=$(_detect_lan_prefix)
    if [ -z "$base" ]; then
        cecho -b "无法自动探测本地子网，回退到默认 192.168.1.x"
        base="192.168.1"
    fi

    # 复用 scan
    cmd_scan "$base" .1 .254
}

# 尝试多种方式探测本机所在的 /24 网段前缀（前三段）
_detect_lan_prefix() {
    local ip="" gw=""

    # 1) ip -4 addr (Linux iproute2)
    if command -v ip >/dev/null 2>&1; then
        ip=$(ip -4 addr show scope global 2>/dev/null \
            | grep -oP '(?<=inet\s)\d+(\.\d+){3}' \
            | grep -v '^127\.' | head -1)
    fi

    # 2) ifconfig (BSD / macOS / 老式 Linux)
    if [ -z "$ip" ] && command -v ifconfig >/dev/null 2>&1; then
        ip=$(ifconfig 2>/dev/null \
            | awk '/[ \t]inet[ \t]/ && $2 != "127.0.0.1" {print $2; exit}')
    fi

    # 3) hostname -I (Linux util-linux)
    if [ -z "$ip" ] && command -v hostname >/dev/null 2>&1; then
        ip=$(hostname -I 2>/dev/null | tr ' ' '\n' \
            | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' \
            | grep -v '^127\.' | head -1)
    fi

    # 4) 通过默认路由网关反推（同网段场景下网关与主机通常在一起）
    if [ -z "$ip" ]; then
        if command -v ip >/dev/null 2>&1; then
            gw=$(ip route 2>/dev/null | awk '/^default/ {print $3; exit}')
        fi
        if [ -z "$gw" ] && command -v route >/dev/null 2>&1; then
            # Linux: route -n；macOS/BSD: route -n get default
            gw=$(route -n 2>/dev/null | awk '$1=="0.0.0.0" {print $2; exit}')
            [ -z "$gw" ] && gw=$(route -n get default 2>/dev/null \
                | awk '/gateway:/ {print $2; exit}')
        fi
        if [ -z "$gw" ] && command -v netstat >/dev/null 2>&1; then
            gw=$(netstat -rn 2>/dev/null \
                | awk '$1=="0.0.0.0" || $1=="default" {print $2; exit}')
        fi
        [ -n "$gw" ] && ip="$gw"
    fi

    # 5) 直接解析 /proc/net/route（Linux 无 ip/route 命令时的兜底）
    if [ -z "$ip" ] && [ -r /proc/net/route ]; then
        local hex
        hex=$(awk '$2=="00000000" {print $3; exit}' /proc/net/route)
        if [ -n "$hex" ] && [ "$hex" != "00000000" ]; then
            # 小端 hex -> 点分十进制，例如 0100A8C0 -> 192.168.0.1
            ip=$(printf '%d.%d.%d.%d' \
                "$((0x${hex:6:2}))" "$((0x${hex:4:2}))" \
                "$((0x${hex:2:2}))" "$((0x${hex:0:2}))")
        fi
    fi

    if [ -z "$ip" ]; then
        return 1
    fi

    echo "$ip" | cut -d. -f1-3
}