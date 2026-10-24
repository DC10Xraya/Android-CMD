#resource/cmd_dns.bash
_dns_help() {
    cecho -b "用法: DNS [参数] <域名/IPv4地址>"
    cecho ""
    cecho -b "解析方向:"
    cecho "  默认根据目标自动判断(IPv4→反向, 域名→正向)"
    cecho "  -0                强制正向解析(域名 → IPv4)"
    cecho "  -1                强制反向解析(IPv4 → 域名)"
    echo ""
    cecho -b "输出控制:"
    cecho "  -q                安静模式, 只输出结果(不显示方向/来源)"
    cecho "  -v                显示系统命令/API 的原始输出"
    echo ""
    cecho -b "解析渠道(选一, 不可同时使用):"
    cecho "  -n                强制走网络API(跳过所有本地工具)"
    cecho "  -w <0/1/URL>      指定网络API (自动隐含 -n)"
    cecho "                      0     = 阿里云API (默认)"
    cecho "                      1     = Cloudflare DoH"
    cecho "                      其他  = 自定义 URL"
    cecho "  --nslookup        仅使用 nslookup"
    cecho "  --host            仅使用 host"
    cecho "  --dig             仅使用 dig"
    cecho "  --getent          仅使用 getent"
    cecho "  --busybox         仅使用 busybox nslookup"
    cecho "  --ping            仅使用 ping (仅正向)"
    echo ""
    cecho -b "其它:"
    cecho "  -t, --test        列出当前可用的本地/网络工具"
}

# ---------- 工具检测与展示 ----------
_dns_print_tool_line() {
    local name="$1"
    local path
    path=$(command -v "$name" 2>/dev/null)
    if [ -n "$path" ]; then
        _cprint -c 92 -n "  ✓ "
        printf "%-16s" "$name"
        _cprint -c 90 "$path"
    else
        _cprint -c 91 -n "  ✗ "
        printf "%-16s" "$name"
        _cprint -c 90 "(未找到)"
    fi
}

_dns_list_tools() {
    cecho -b "[本地解析工具]"
    _dns_print_tool_line "nslookup"
    _dns_print_tool_line "host"
    _dns_print_tool_line "dig"
    _dns_print_tool_line "getent"
    _dns_print_tool_line "busybox"
    _dns_print_tool_line "ping"
    echo ""
    cecho -b "[网络工具 (用于 API 查询)]"
    _dns_print_tool_line "curl"
    _dns_print_tool_line "wget"
    echo ""
    local has_local_rev=0
    for t in nslookup host dig getent busybox; do
        command -v "$t" >/dev/null 2>&1 && { has_local_rev=1; break; }
    done
    if [ $has_local_rev -eq 1 ]; then
        cecho "  提示: 至少有一个可用于反向解析的本地工具"
    else
        err "  提示: 无任何本地反向解析工具, 反向解析将仅依赖网络 API"
    fi

    if command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1; then
        cecho "  提示: 网络 API 可用 (阿里云API / Cloudflare DoH)"
    else
        err "  提示: 无 curl / wget, 网络 API 不可用"
    fi
}

# ---------- 原始输出展示(输出到 stderr, 避免污染 $(...) 捕获) ----------
_dns_verbose_show() {
    local label="$1"
    local output="$2"
    {
        _cprint -c 90 "----- [原始输出] $label -----"
        if [ -n "$output" ]; then
            echo "$output" | while IFS= read -r line; do
                _cprint -c 90 "$line"
            done
        else
            _cprint -c 90 "(空)"
        fi
        _cprint -c 90 "-----------------------------"
    } >&2
}

# ---------- 统一输出 ----------
_dns_output_result() {
    local direction="$1"
    local result="$2"
    local source="$3"
    local quiet="$4"

    if [ "$quiet" -eq 1 ]; then
        cecho "$result"
    else
        if [ "$direction" = "reverse" ]; then
            _cprint -n -c 96 "[反向解析] "
        else
            _cprint -n -c 92 "[正向解析] "
        fi
        cecho "$result ($source)"
    fi
}

# ---------- 单个本地工具的执行(返回结果, 或空) ----------
# 参数: tool target direction verbose
# 输出: 结果字符串(可能为空)
_dns_run_local_tool() {
    local tool="$1"
    local target="$2"
    local direction="$3"
    local verbose="$4"
    local raw="" result=""

    case "$tool" in
        nslookup)
            command -v nslookup >/dev/null 2>&1 || return 1
            raw=$(nslookup "$target" 2>&1)
            [ "$verbose" -eq 1 ] && _dns_verbose_show "nslookup $target" "$raw"
            if [ "$direction" = "reverse" ]; then
                result=$(echo "$raw" | grep -E "name =|in-addr.arpa" | head -1 | sed -E 's/.*name = //; s/\.$//')
            else
                result=$(echo "$raw" | grep -E "^Address:" | tail -1 | awk '{print $2}')
            fi
            ;;
        host)
            command -v host >/dev/null 2>&1 || return 1
            raw=$(host "$target" 2>&1)
            [ "$verbose" -eq 1 ] && _dns_verbose_show "host $target" "$raw"
            if [ "$direction" = "reverse" ]; then
                result=$(echo "$raw" | head -1 | sed -E 's/.*pointer //; s/\.$//')
            else
                result=$(echo "$raw" | grep -E "has address" | head -1 | awk '{print $NF}')
            fi
            ;;
        dig)
            command -v dig >/dev/null 2>&1 || return 1
            if [ "$direction" = "reverse" ]; then
                raw=$(dig -x "$target" +short 2>&1)
                [ "$verbose" -eq 1 ] && _dns_verbose_show "dig -x $target +short" "$raw"
                result=$(echo "$raw" | head -1)
            else
                raw=$(dig +short "$target" A 2>&1)
                [ "$verbose" -eq 1 ] && _dns_verbose_show "dig +short $target A" "$raw"
                result=$(echo "$raw" | grep -E '^[0-9.]+$' | head -1)
            fi
            ;;
        getent)
            command -v getent >/dev/null 2>&1 || return 1
            if [ "$direction" = "reverse" ]; then
                raw=$(getent hosts "$target" 2>&1)
                [ "$verbose" -eq 1 ] && _dns_verbose_show "getent hosts $target" "$raw"
                result=$(echo "$raw" | awk '{print $2}')
            else
                raw=$(getent ahosts "$target" 2>&1)
                [ "$verbose" -eq 1 ] && _dns_verbose_show "getent ahosts $target" "$raw"
                result=$(echo "$raw" | head -1 | awk '{print $1}')
            fi
            ;;
        busybox)
            command -v busybox >/dev/null 2>&1 || return 1
            raw=$(busybox nslookup "$target" 2>&1)
            [ "$verbose" -eq 1 ] && _dns_verbose_show "busybox nslookup $target" "$raw"
            if [ "$direction" = "reverse" ]; then
                result=$(echo "$raw" | grep -E "name =|in-addr.arpa" | head -1 | sed -E 's/.*name = //; s/\.$//')
            else
                result=$(echo "$raw" | grep -E "^Address:" | tail -1 | awk '{print $2}')
            fi
            ;;
        ping)
            command -v ping >/dev/null 2>&1 || return 1
            [ "$direction" = "reverse" ] && return 1
            raw=$(ping -c1 "$target" 2>&1)
            [ "$verbose" -eq 1 ] && _dns_verbose_show "ping -c1 $target" "$raw"
            result=$(echo "$raw" | head -1 | sed -n 's/.*(\([0-9.]\{7,15\}\)).*/\1/p')
            ;;
        *)
            return 1
            ;;
    esac

    [ -n "$result" ] && printf '%s' "$result"
    return 0
}

# ---------- 网络 API 查询 ----------
# 参数: target direction api_kind verbose
# api_kind: 0 / 1 / URL
# 输出: "结果|来源标记"
_dns_query_api() {
    local target="$1"
    local direction="$2"
    local api_kind="$3"
    local verbose="$4"
    local raw="" result="" source=""
    local rr_type
    [ "$direction" = "reverse" ] && rr_type="PTR" || rr_type="A"

    if [ "$api_kind" = "1" ]; then
        local url="https://cloudflare-dns.com/dns-query?name=$target&type=$rr_type"
        [ "$verbose" -eq 1 ] && _dns_verbose_show "GET $url" ""
        if command -v curl >/dev/null 2>&1; then
            raw=$(curl -s --connect-timeout 5 -H "accept: application/dns-json" "$url" 2>&1)
        else
            raw=$(wget -qO- --timeout=5 --header="accept: application/dns-json" "$url" 2>&1)
        fi
        [ "$verbose" -eq 1 ] && _dns_verbose_show "GET $url" "$raw"
        result=$(echo "$raw" | grep -o '"data":"[^"]*"' | head -1 | sed 's/"data":"//; s/"//')
        source="Cloudflare DoH"
    elif [ "$api_kind" = "0" ]; then
        local url="https://dns.alidns.com/resolve?name=$target&type=$rr_type"
        [ "$verbose" -eq 1 ] && _dns_verbose_show "GET $url" ""
        if command -v curl >/dev/null 2>&1; then
            raw=$(curl -s --connect-timeout 5 "$url" 2>&1)
        else
            raw=$(wget -qO- --timeout=5 "$url" 2>&1)
        fi
        [ "$verbose" -eq 1 ] && _dns_verbose_show "GET $url" "$raw"
        result=$(echo "$raw" | grep -o '"data":"[^"]*"' | head -1 | sed 's/"data":"//; s/"//')
        source="阿里云API"
    else
        # 自定义 URL
        [ "$verbose" -eq 1 ] && _dns_verbose_show "GET $api_kind" ""
        if command -v curl >/dev/null 2>&1; then
            raw=$(curl -s --connect-timeout 5 "$api_kind" 2>&1)
        else
            raw=$(wget -qO- --timeout=5 "$api_kind" 2>&1)
        fi
        [ "$verbose" -eq 1 ] && _dns_verbose_show "GET $api_kind" "$raw"
        result=$(echo "$raw" | grep -o '"data":"[^"]*"' | head -1 | sed 's/"data":"//; s/"//')
        [ -z "$result" ] && result=$(echo "$raw" | head -1 | tr -d '\n\r')
        source="自定义API"
    fi

    [ -n "$result" ] && printf '%s|%s' "$result" "$source"
    return 0
}

# ==================================================
#                      主命令
# ==================================================
cmd_dns() {
    # ---------- 帮助优先 ----------
    if [ $# -eq 0 ]; then
        _dns_help
        return 0
    fi

    # 扫描是否含 -h/--help/-t/--test (这两者优先级最高, 可出现在任意位置)
    local scan
    for scan in "$@"; do
        case "$scan" in
            -h|--help) _dns_help; return 0 ;;
        esac
    done
    for scan in "$@"; do
        case "$scan" in
            -t|--test) _dns_list_tools; return 0 ;;
        esac
    done

    # ---------- 参数解析 ----------
    local force_forward=0
    local force_reverse=0
    local force_network=0
    local network_api=""
    local local_tool=""
    local quiet=0
    local verbose=0
    local target=""

    while [ $# -gt 0 ]; do
        case "$1" in
            -0) force_forward=1; shift ;;
            -1) force_reverse=1; shift ;;
            -n) force_network=1; shift ;;
            -q) quiet=1; shift ;;
            -v) verbose=1; shift ;;
            -w)
                if [ $# -lt 2 ]; then
                    err "参数 -w 需要指定值 (0/1/URL)"
                    return 1
                fi
                network_api="$2"
                force_network=1
                shift 2
                ;;
            --ping)     local_tool="ping";     shift ;;
            --nslookup) local_tool="nslookup"; shift ;;
            --host)     local_tool="host";     shift ;;
            --dig)      local_tool="dig";      shift ;;
            --getent)   local_tool="getent";   shift ;;
            --busybox)  local_tool="busybox";  shift ;;
            --) shift; break ;;
            -*)
                err "未知参数: $1, 使用 DNS -h 查看帮助"
                return 1
                ;;
            *) break ;;
        esac
    done

    # ---------- 冲突检查 ----------
    if [ $force_forward -eq 1 ] && [ $force_reverse -eq 1 ]; then
        err "参数冲突: -0 与 -1 不能同时使用"
        return 1
    fi
    if [ -n "$local_tool" ] && [ $force_network -eq 1 ]; then
        err "参数冲突: --$local_tool 与 -n/-w 不能同时使用"
        err "  --$local_tool 指定只用本地工具, -n/-w 指定只用网络API"
        return 1
    fi

    # ---------- 目标检查 ----------
    if [ $# -eq 0 ]; then
        err "缺少目标参数, 使用 DNS -h 查看帮助"
        return 1
    fi
    target="$1"

    # ---------- 方向判断 ----------
    local is_ipv4=0
    if [[ "$target" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        is_ipv4=1
    fi

    local direction
    if [ $force_forward -eq 1 ]; then
        direction="forward"
    elif [ $force_reverse -eq 1 ]; then
        direction="reverse"
    elif [ $is_ipv4 -eq 1 ]; then
        direction="reverse"
    else
        direction="forward"
    fi

    if [ "$direction" = "reverse" ] && [ $is_ipv4 -eq 0 ]; then
        err "反向解析需要 IPv4 地址(当前目标: $target)"
        return 1
    fi

    local reverse_name=""
    if [ "$direction" = "reverse" ]; then
        reverse_name=$(echo "$target" | awk -F. '{print $4"."$3"."$2"."$1".in-addr.arpa"}')
    fi

    local query_name="$target"
    [ "$direction" = "reverse" ] && query_name="$reverse_name"

    # ---------- 渠道选择 ----------
    local result="" source_label=""

    if [ -n "$local_tool" ]; then
        # 渠道 A: 只用指定的本地工具
        if [ "$local_tool" = "ping" ] && [ "$direction" = "reverse" ]; then
            err "工具 ping 不支持反向解析"
            return 1
        fi
        if ! command -v "$local_tool" >/dev/null 2>&1; then
            err "工具 $local_tool 不可用"
            return 1
        fi
        result=$(_dns_run_local_tool "$local_tool" "$target" "$direction" "$verbose")
        source_label="$local_tool"

    elif [ $force_network -eq 1 ]; then
        # 渠道 B: 只用网络 API
        if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
            err "未找到 curl 或 wget, 无法使用网络 API"
            return 1
        fi
        local api_kind="${network_api:-0}"
        local api_out
        api_out=$(_dns_query_api "$query_name" "$direction" "$api_kind" "$verbose")
        result="${api_out%%|*}"
        source_label="${api_out##*|}"

        # 默认阿里云失败时, 自动尝试 Cloudflare DoH
        if [ -z "$result" ] && [ "$api_kind" = "0" ]; then
            local api_out2
            api_out2=$(_dns_query_api "$query_name" "$direction" "1" "$verbose")
            result="${api_out2%%|*}"
            [ -n "$result" ] && source_label="${api_out2##*|}"
        fi

    else
        # 渠道 C: 本地依次尝试, 全失败再走网络
        local local_tools=()
        if [ "$direction" = "reverse" ]; then
            local_tools=("nslookup" "host" "dig" "getent" "busybox")
        else
            local_tools=("getent" "nslookup" "host" "dig" "busybox" "ping")
        fi

        local t
        for t in "${local_tools[@]}"; do
            result=$(_dns_run_local_tool "$t" "$target" "$direction" "$verbose")
            if [ -n "$result" ]; then
                source_label="$t"
                break
            fi
        done

        # 本地全失败 → 网络 API
        if [ -z "$result" ]; then
            if command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1; then
                local api_out
                api_out=$(_dns_query_api "$query_name" "$direction" "0" "$verbose")
                result="${api_out%%|*}"
                source_label="${api_out##*|}"
                if [ -z "$result" ]; then
                    api_out=$(_dns_query_api "$query_name" "$direction" "1" "$verbose")
                    result="${api_out%%|*}"
                    [ -n "$result" ] && source_label="${api_out##*|}"
                fi
            fi
        fi
    fi

    # ---------- 结果校验与输出 ----------
    if [ -z "$result" ]; then
        if [ "$direction" = "reverse" ]; then
            err "反向解析失败(无 PTR 记录或网络不可达)"
        else
            err "正向解析失败(域名不存在或网络不可达)"
        fi
        return 1
    fi

    # 正向结果必须是 IPv4
    if [ "$direction" = "forward" ] && ! [[ "$result" =~ ^[0-9.]+$ ]]; then
        err "正向解析失败(返回了非 IPv4 结果: $result)"
        return 1
    fi

    _dns_output_result "$direction" "$result" "$source_label" "$quiet"
    return 0
}