#resource/cmd_dns.bash
cmd_dns() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -eq 0 ]; then
        cecho -b "用法: DNS <域名/IPv4地址>"
        cecho "  正向解析: 输入域名, 显示对应 IPv4 地址"
        cecho "  反向解析: 输入 IPv4 地址, 显示对应域名"
        err "  (若没有反向解析工具, 将会使用阿里云 API 或 Cloudflare DoH)"
        cecho "示例:"
        cecho "  DNS google.com"
        cecho "  DNS 8.8.8.8"
        return 0
    fi

    local target="$1"
    local result=""

    # ---------- 判断是否为 IPv4 ----------
    if [[ "$target" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        # ===== 反向解析 =====
        # 1. 尝试本地工具
        if command -v nslookup >/dev/null 2>&1; then
            result=$(nslookup "$target" 2>/dev/null | grep -E "name =|in-addr.arpa" | head -1 | sed -E 's/.*name = //; s/\.$//')
        fi

        if [ -z "$result" ] && command -v host >/dev/null 2>&1; then
            result=$(host "$target" 2>/dev/null | head -1 | sed -E 's/.*pointer //; s/\.$//')
        fi

        if [ -z "$result" ] && command -v dig >/dev/null 2>&1; then
            result=$(dig -x "$target" +short 2>/dev/null | head -1)
        fi

        if [ -z "$result" ] && command -v getent >/dev/null 2>&1; then
            result=$(getent hosts "$target" 2>/dev/null | awk '{print $2}')
        fi

        if [ -z "$result" ] && command -v busybox >/dev/null 2>&1; then
            result=$(busybox nslookup "$target" 2>/dev/null | grep -E "name =|in-addr.arpa" | head -1 | sed -E 's/.*name = //; s/\.$//')
        fi

        # 2. 本地全部失败 → 使用阿里云 DNS API
        if [ -z "$result" ]; then
            if command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1; then
                local reverse=$(echo "$target" | awk -F. '{print $4"."$3"."$2"."$1".in-addr.arpa"}')
                local api_url="https://dns.alidns.com/resolve?name=$reverse&type=PTR"
                local json=""
                if command -v curl >/dev/null 2>&1; then
                    json=$(curl -s --connect-timeout 5 "$api_url" 2>/dev/null)
                else
                    json=$(wget -qO- --timeout=5 "$api_url" 2>/dev/null)
                fi
                result=$(echo "$json" | grep -o '"data":"[^"]*"' | head -1 | sed 's/"data":"//; s/"//')
            else
                err "未找到 curl 或 wget, 且无本地解析工具, 无法反向解析"
                return 1
            fi
        fi

        # 3. 阿里云也失败 → 尝试 Cloudflare DoH(备用)
        if [ -z "$result" ]; then
            if command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1; then
                local reverse=$(echo "$target" | awk -F. '{print $4"."$3"."$2"."$1".in-addr.arpa"}')
                local json=""
                if command -v curl >/dev/null 2>&1; then
                    json=$(curl -s --connect-timeout 3 -H "accept: application/dns-json" "https://cloudflare-dns.com/dns-query?name=$reverse&type=PTR" 2>/dev/null)
                else
                    json=$(wget -qO- --timeout=3 --header="accept: application/dns-json" "https://cloudflare-dns.com/dns-query?name=$reverse&type=PTR" 2>/dev/null)
                fi
                result=$(echo "$json" | grep -o '"data":"[^"]*"' | head -1 | sed 's/"data":"//; s/"//')
            fi
        fi

        if [ -n "$result" ]; then
            cecho "$result"
        else
            err "反向解析失败(无 PTR 记录或网络不可达)"
            return 1
        fi

    else
        # ===== 正向解析 =====
        # 1. 本地工具
        if command -v getent >/dev/null 2>&1; then
            result=$(getent ahosts "$target" 2>/dev/null | head -1 | awk '{print $1}')
        fi

        if [ -z "$result" ] && command -v nslookup >/dev/null 2>&1; then
            result=$(nslookup "$target" 2>/dev/null | grep -E "^Address:" | tail -1 | awk '{print $2}')
        fi

        if [ -z "$result" ] && command -v busybox >/dev/null 2>&1; then
            result=$(busybox nslookup "$target" 2>/dev/null | grep -E "^Address:" | tail -1 | awk '{print $2}')
        fi

        if [ -z "$result" ] && command -v ping >/dev/null 2>&1; then
            result=$(ping -c1 "$target" 2>/dev/null | head -1 | sed -n 's/.*(\([0-9.]\{7,15\}\)).*/\1/p')
        fi

        # 2. 本地失败 → 阿里云 DNS API 查询 A 记录
        if [ -z "$result" ]; then
            if command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1; then
                local api_url="https://dns.alidns.com/resolve?name=$target&type=A"
                local json=""
                if command -v curl >/dev/null 2>&1; then
                    json=$(curl -s --connect-timeout 5 "$api_url" 2>/dev/null)
                else
                    json=$(wget -qO- --timeout=5 "$api_url" 2>/dev/null)
                fi
                result=$(echo "$json" | grep -o '"data":"[^"]*"' | head -1 | sed 's/"data":"//; s/"//')
            else
                err "未找到 curl 或 wget, 且无本地解析工具, 无法正向解析"
                return 1
            fi
        fi

# 3. 阿里云也失败 → 尝试 Cloudflare DoH
if [ -z "$result" ]; then
    if command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1; then
        local reverse=$(echo "$target" | awk -F. '{print $4"."$3"."$2"."$1".in-addr.arpa"}')
        local json=""
        if command -v curl >/dev/null 2>&1; then
            json=$(curl -s --connect-timeout 3 -H "accept: application/dns-json" "https://cloudflare-dns.com/dns-query?name=$reverse&type=PTR" 2>/dev/null)
        else
            json=$(wget -qO- --timeout=3 --header="accept: application/dns-json" "https://cloudflare-dns.com/dns-query?name=$reverse&type=PTR" 2>/dev/null)
        fi
        result=$(echo "$json" | grep -o '"Answer":\[[^]]*\]' | grep -o '"data":"[^"]*"' | head -1 | sed 's/"data":"//; s/"//')
    fi
fi

        if [ -n "$result" ] && [[ "$result" =~ ^[0-9.]+$ ]]; then
            cecho "$result"
        else
            err "正向解析失败(域名不存在或网络不可达)"
            return 1
        fi
    fi
}