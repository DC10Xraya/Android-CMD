#resource/cmd_ping.bash
#Android CMD PING remake dev 2026_10_06
cmd_ping() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -eq 0 ]; then
    cecho -b "用法: PING [-n] [-nf/-inf] [-f] [-w] [-W] [-i] [-s] [-I] [-t] [-4|-6] [-b] [-B] [-S] [-r] [-L] [-D] [-Dp] [-v] [-q] [-V] <域名/IP>"
    cecho "选项说明: "
    cecho "-n 次数          指定发送的次数(正整数,默认4)"
    cecho "-nf/-inf         无限制发送(不限制包数)"
    cecho "-f               洪水模式(尝试真实洪水, 失败则模拟)"
    cecho "-w 总超时(s)     整个过程的总时间限制(正数)"
    cecho "-W 单包超时(s)   每个包的超时时间(正整数,默认1)"
    cecho "-i 间隔(s)       成功收到回复后等待的间隔时间(支持浮点数,最小0.2秒,默认0.5)"
    cecho "-s 包大小(字节)  发送的数据包大小(1-65507,默认56)"
    cecho "-I 接口/IP       指定源接口或源IP地址"
    cecho "-t TTL           设置 IP 生存时间 (1-255)"
    cecho "-4               强制使用 IPv4"
    cecho "-6               强制使用 IPv6(优先ping -6,回退ping6)"
    cecho "-b               允许 ping 广播地址"
    cecho "-B               不改变探测包的源地址"
    cecho "-S 缓冲区        设置发送缓冲区大小(字节)"
    cecho "-r               绕过路由表直接发送到本地接口"
    cecho "-L               抑制组播回环"
    cecho "-D               显示 Unix 时间戳"
    cecho "-Dp [格式]       显示人性化时间戳(格式可省略, 默认 HH:mm:ss)"
    cecho "占位符: YYYY=年  YY=两位年  MM=月  DD=日"
    cecho "       HH=24时  hh=12时  mm=分  ss=秒"
    cecho "       AA=星期全称  aa=星期缩写"
    cecho "       同时支持系统 date 格式"
    cecho "-v               直接显示系统的原始输出"
    cecho "-q               不显示每次回复, 只输出统计信息"
    cecho "-V               显示 PING 函数版本和底层 ping 版本"
    return 0
fi

    # ---------- 选项解析 ----------
    local count=0 mode="count" target="" packet_size=""
    local per_packet_timeout=1
    local total_timeout=0
    local interval=0.5
    local valid_args=1
    local has_n=0 has_nf=0
    local flood_mode=0
    local source_iface="" ttl_val=""
    local verbose=0 quiet=0
    local ipv4=0 ipv6=0
    local bcast_ok=0 no_src_change=0 bypass_route=0 no_mcast_loop=0
    local sndbuf=""
    local show_timestamp=0 timestamp_pretty=0 timestamp_format="HH:mm:ss"
    local show_version=0

    local opt_s_provided=0 opt_i_provided=0

    while [ $# -gt 0 ]; do
        case "$1" in
            -n)
                if [ $# -ge 2 ] && echo "$2" | grep -qE '^[1-9][0-9]*$'; then
                    mode="count"; count="$2"; has_n=1; shift 2
                else
                    err "选项 -n 需要指定有效次数(大于0的整数)"; valid_args=0; break
                fi
                ;;
            -nf|-inf)
                mode="inf"; has_nf=1; shift
                ;;
            -f)
                if ! confirm "你想使用洪水模式吗?如果你是非root设备,我们将会模拟\n无论是真正的洪水模式还是模拟,这都会消耗一些流量,并且可能导致资源拥堵\n参考流量消耗:Really:6.5MB/s Sim:360KB/s"; then
                    return
                fi
                flood_mode=1
                shift
                ;;
            -s)
                opt_s_provided=1
                if [ $# -ge 2 ] && echo "$2" | grep -qE '^[0-9]+$' && [ "$2" -ge 1 ] && [ "$2" -le 65507 ]; then
                    packet_size="$2"; shift 2
                else
                    err "选项 -s 需要指定有效包大小(1-65507之间的正整数)"; valid_args=0; break
                fi
                ;;
            -w)
                if [ $# -ge 2 ] && echo "$2" | grep -qE '^[0-9]+(\.[0-9]+)?$' && [ "$(echo "$2 > 0" | bc 2>/dev/null)" = "1" ]; then
                    total_timeout="$2"; shift 2
                else
                    err "选项 -w 需要指定有效的总超时值(大于0的数字)"; valid_args=0; break
                fi
                ;;
            -W)
                if [ $# -ge 2 ] && echo "$2" | grep -qE '^[0-9]+$' && [ "$2" -ge 1 ]; then
                    per_packet_timeout="$2"; shift 2
                else
                    err "选项 -W 需要指定有效的单包超时值(正整数)"; valid_args=0; break
                fi
                ;;
            -i)
                opt_i_provided=1
                if [ $# -ge 2 ] && echo "$2" | grep -qE '^[0-9]+(\.[0-9]+)?$'; then
                    interval="$2"
                    if [ "$(echo "$interval < 0.2" | bc 2>/dev/null)" = "1" ]; then
                        err "选项 -i 间隔不能小于0.2秒"; valid_args=0; break
                    fi
                    shift 2
                else
                    err "选项 -i 需要指定有效的间隔时间(大于等于0.2的数字)"; valid_args=0; break
                fi
                ;;
            -I)
                if [ $# -ge 2 ]; then
                    source_iface="$2"; shift 2
                else
                    err "选项 -I 需要指定接口或IP地址"; valid_args=0; break
                fi
                ;;
            -t)
                if [ $# -ge 2 ] && echo "$2" | grep -qE '^[0-9]+$' && [ "$2" -ge 1 ] && [ "$2" -le 255 ]; then
                    ttl_val="$2"; shift 2
                else
                    err "选项 -t 需要指定有效的 TTL 值 (1-255)"; valid_args=0; break
                fi
                ;;
            -4)
                ipv4=1; shift
                ;;
            -6)
                ipv6=1; shift
                ;;
            -b)
                bcast_ok=1; shift
                ;;
            -B)
                no_src_change=1; shift
                ;;
            -S)
                if [ $# -ge 2 ] && echo "$2" | grep -qE '^[0-9]+$' && [ "$2" -ge 1 ]; then
                    sndbuf="$2"; shift 2
                else
                    err "选项 -S 需要指定有效的发送缓冲区大小(正整数)"; valid_args=0; break
                fi
                ;;
            -r)
                bypass_route=1; shift
                ;;
            -L)
                no_mcast_loop=1; shift
                ;;
            -Dp)
                show_timestamp=1
                timestamp_pretty=1
                if [ $# -ge 2 ] && echo "$2" | grep -qE 'YYYY|YY|MM|DD|HH|hh|mm|ss|AA|aa|%'; then
                    timestamp_format="$2"; shift 2
                else
                    timestamp_format="HH:mm:ss"; shift
                fi
                ;;
            -D)
                show_timestamp=1; shift
                ;;
            -V)
                show_version=1; shift
                ;;
            -v)
                verbose=1; shift
                ;;
            -q)
                quiet=1; shift
                ;;
            -*)
                err "未知选项: $1"; valid_args=0; break
                ;;
            *)
                if [ -z "$target" ]; then
                    target="$1"; shift
                else
                    err "多余的选项: $1"; valid_args=0; break
                fi
                ;;
        esac
    done

    [ $valid_args -eq 0 ] && return 1

    # ---------- 冲突检查 ----------
    if [ $flood_mode -eq 1 ]; then
        if [ $has_n -eq 1 ]; then
            err "选项 -f (洪水模式) 和 -n (指定次数) 不能同时使用"; return 1
        fi
        if [ $has_nf -eq 1 ]; then
            err "选项 -f (洪水模式) 和 -nf/-inf (无限制发送) 不能同时使用"; return 1
        fi
        if [ $opt_i_provided -eq 1 ]; then
            err "选项 -f (洪水模式) 和 -i (间隔) 不能同时使用 (洪水强制间隔0.2秒)"; return 1
        fi
        if [ $opt_s_provided -eq 1 ]; then
            err "选项 -f (洪水模式) 和 -s (包大小) 不能同时使用 (洪水强制包大小65507)"; return 1
        fi
    fi

    if [ $has_nf -eq 1 ] && [ $has_n -eq 1 ]; then
        err "选项 -nf/-inf (无限制发送) 和 -n (指定次数) 不能同时使用"; return 1
    fi

    if [ $ipv4 -eq 1 ] && [ $ipv6 -eq 1 ]; then
        err "选项 -4 (强制IPv4) 和 -6 (强制IPv6) 不能同时使用"; return 1
    fi

    if [ $timestamp_pretty -eq 1 ] && [ $verbose -eq 1 ]; then
        err "选项 -Dp (人性化时间戳) 和 -v (原始输出) 不能同时使用"; return 1
    fi

    # ---------- -V 版本信息 ----------
    if [ $show_version -eq 1 ]; then
    cecho -b "PING 函数版本: Android CMD PING remake dev 2026_10_06"
    cecho "底层 ping 版本信息:"
    local vout
    vout=$(ping -V 2>&1)
    if [ -n "$vout" ]; then
        echo "$vout" | while IFS= read -r vline; do
            cecho -c 92 "    $vline"
        done
    else
        err "    无法获取底层 ping 版本"
    fi
    if ping -6 -c 1 ::1 >/dev/null 2>&1; then
    cecho -c 92 "    ping 支持 -6选项"
    else
    err "    ping 不支持 -6选项"
    fi
    if command -v ping6 >/dev/null 2>&1; then
        cecho "ping6 (IPv6 回退方案):"
        local vout6
        vout6=$(ping6 -V 2>&1 | head -1)
        [ -n "$vout6" ] && cecho -c 92 "    $vout6"
    else
        err "    未检测到 ping6"
    fi
    cecho -b "TIP: 优先 ping -6, 回退ping6, 如果要使用IPV6 ping, 至少得有这两个中的其中一个"
    return 0
fi

[ -z "$target" ] && { err "需要指定目标 IP 地址或域名"; return 1; }

if [ "$mode" = "count" ] && [ "$count" -eq 0 ]; then
    count=4
fi

command -v ping >/dev/null 2>&1 || { err "未找到 ping 命令"; return 1; }
    # ---------- 辅助函数 ----------
    is_ip() {
        echo "$1" | grep -qE '^([0-9]{1,3}\.){3}[0-9]{1,3}$'
    }

    get_ip_from_domain() {
        local domain="$1"
        local ip=""
        if command -v nslookup >/dev/null 2>&1; then
            ip=$(nslookup "$domain" 2>/dev/null | grep -A1 'Name:' | grep 'Address:' | head -1 | awk '{print $2}')
            [ -n "$ip" ] && echo "$ip" && return
            ip=$(nslookup "$domain" 2>/dev/null | grep 'Address 1:' | head -1 | awk '{print $3}')
            [ -n "$ip" ] && echo "$ip" && return
        fi
        if command -v dig >/dev/null 2>&1; then
            ip=$(dig +short "$domain" 2>/dev/null | head -1)
            [ -n "$ip" ] && echo "$ip" && return
        fi
        if command -v host >/dev/null 2>&1; then
            ip=$(host "$domain" 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
            [ -n "$ip" ] && echo "$ip" && return
        fi
        if command -v ping >/dev/null 2>&1; then
            ip=$(ping -c 1 -W 1 -n "$domain" 2>/dev/null | head -1 | grep -oE '\([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\)' | sed 's/[()]//g')
            [ -n "$ip" ] && echo "$ip" && return
        fi
        echo ""
    }

    can_use_ping_opt() {
        local opt="$1"
        local out
        out=$(ping "$opt" -c 1 -W 1 127.0.0.1 2>&1)
        if echo "$out" | grep -qiE "invalid option|unknown option|unrecognized option"; then
            return 1
        fi
        return 0
    }

    can_use_real_flood() {
        ping -f -c 1 -W 1 127.0.0.1 >/dev/null 2>&1
    }

    can_use_ping_dash6() {
        local output
        output=$(ping -6 -c 1 -W 1 ::1 2>&1)
        if echo "$output" | grep -qiE "invalid option|unknown option|unrecognized option|usage:"; then
            return 1
        fi
        return 0
    }

    can_use_ping_dashD() {
        local output
        output=$(ping -D -c 1 -W 1 127.0.0.1 2>&1)
        if echo "$output" | grep -qiE "invalid option|unknown option|unrecognized option|usage:"; then
            return 1
        fi
        return 0
    }

    can_use_ping_dashw() {
        local out
        out=$(ping -w 1 -c 1 127.0.0.1 2>&1)
        if echo "$out" | grep -qiE "invalid option|unknown option|unrecognized option"; then
            return 1
        fi
        return 0
    }

    # 应用 -w：整数优先底层, 小数用 timeout
    apply_total_timeout() {
        [ "$(echo "$total_timeout > 0" | bc 2>/dev/null)" = "1" ] || return 0
        if echo "$total_timeout" | grep -qE '^[0-9]+$' && can_use_ping_dashw; then
            ping_cmd+=(-w "$total_timeout")
        elif command -v timeout >/dev/null 2>&1; then
            ping_cmd=(timeout "$total_timeout" "${ping_cmd[@]}")
        elif can_use_ping_dashw; then
            local tt_int=$(printf "%.0f" "$total_timeout")
            [ "$tt_int" -lt 1 ] && tt_int=1
            ping_cmd+=(-w "$tt_int")
        fi
    }

    get_time() {
        if command -v perl >/dev/null 2>&1; then
            perl -MTime::HiRes -e 'printf "%.3f", Time::HiRes::time' 2>/dev/null
        elif date +%s.%N 2>/dev/null | grep -qE '^[0-9]+\.[0-9]+$'; then
            date +%s.%N
        elif [ -r /proc/uptime ]; then
            awk '{print $1}' /proc/uptime 2>/dev/null
        else
            date +%s
        fi
    }

    format_timestamp() {
        local fmt="$1"
        fmt="${fmt//YYYY/%Y}"
        fmt="${fmt//YY/%y}"
        fmt="${fmt//MM/%m}"
        fmt="${fmt//DD/%d}"
        fmt="${fmt//HH/%H}"
        fmt="${fmt//hh/%I}"
        fmt="${fmt//mm/%M}"
        fmt="${fmt//ss/%S}"
        fmt="${fmt//AA/%A}"
        fmt="${fmt//aa/%a}"
        date +"$fmt" 2>/dev/null
    }

    # "0.474" -> 474 (微秒); "1.5" -> 1500; "10" -> 10000
    parse_ms_to_us() {
        local t="$1"
        local i="${t%%.*}"
        local d="${t#*.}"
        [ "$d" = "$t" ] && d="0"
        d="${d}000"
        d="${d:0:3}"
        [ -z "$i" ] && i=0
        echo $(( i * 1000 + 10#$d ))
    }

    us_to_ms_str() {
        local us="$1"
        [ -z "$us" ] && { echo "N/A"; return; }
        printf "%d.%03dms" $(( us / 1000 )) $(( us % 1000 ))
    }

    # ---------- IPv6 回退检测 ----------
    local use_ping6=0
    if [ $ipv6 -eq 1 ]; then
        if ! can_use_ping_dash6; then
            if command -v ping6 >/dev/null 2>&1; then
                use_ping6=1
            else
                err "当前 ping 不支持 -6 选项, 且系统未找到 ping6, 无法使用 IPv6"
                return 1
            fi
        fi
    fi

    # ---------- 显示目标 / 解析 IP ----------
    local display_target="$target"
    local resolved_ip=""
    if [ $ipv6 -eq 1 ]; then
        display_target="$target"
        resolved_ip="$target"
    elif is_ip "$target"; then
        display_target="$target"
        resolved_ip="$target"
    else
        local ip=$(get_ip_from_domain "$target")
        if [ -n "$ip" ]; then
            display_target="$target ($ip)"
            resolved_ip="$ip"
        else
            display_target="$target"
            resolved_ip="$target"
        fi
    fi

    # ---------- 构建 ping 命令(数组, 不用 eval) ----------
    local -a ping_cmd=(ping)
    local data_bytes=56
    local icmp_header=28

    if [ $use_ping6 -eq 1 ]; then
        ping_cmd=(ping6)
        icmp_header=48
    else
        if [ $ipv4 -eq 1 ] && can_use_ping_opt "-4"; then
            ping_cmd+=(-4)
        fi
        if [ $ipv6 -eq 1 ]; then
            ping_cmd+=(-6)
            icmp_header=48
        fi
    fi

    [ $bcast_ok -eq 1 ] && ping_cmd+=(-b)
    [ $no_src_change -eq 1 ] && ping_cmd+=(-B)
    [ $bypass_route -eq 1 ] && ping_cmd+=(-r)
    [ $no_mcast_loop -eq 1 ] && ping_cmd+=(-L)
    [ -n "$sndbuf" ] && ping_cmd+=(-S "$sndbuf")

    if [ $flood_mode -eq 1 ]; then
        if can_use_real_flood; then
            ping_cmd+=(-f)
            [ -n "$source_iface" ] && ping_cmd+=(-I "$source_iface")
            [ -n "$ttl_val" ] && ping_cmd+=(-t "$ttl_val")
            ping_cmd+=(-W "$per_packet_timeout")
            apply_total_timeout
            ping_cmd+=("$target")
            data_bytes=56
        else
            local fake_count=9999999
            local fake_interval=0.2
            local fake_packet_size=65507
            data_bytes=$fake_packet_size
            ping_cmd+=(-c "$fake_count" -s "$fake_packet_size" -i "$fake_interval" -W "$per_packet_timeout")
            [ -n "$source_iface" ] && ping_cmd+=(-I "$source_iface")
            [ -n "$ttl_val" ] && ping_cmd+=(-t "$ttl_val")
            apply_total_timeout
            ping_cmd+=("$target")
        fi
    else
        [ "$mode" = "count" ] && ping_cmd+=(-c "$count")
        ping_cmd+=(-i "$interval" -W "$per_packet_timeout")
        if [ -n "$packet_size" ]; then
            ping_cmd+=(-s "$packet_size")
            data_bytes=$packet_size
        fi
        [ -n "$source_iface" ] && ping_cmd+=(-I "$source_iface")
        [ -n "$ttl_val" ] && ping_cmd+=(-t "$ttl_val")
        apply_total_timeout
        ping_cmd+=("$target")
    fi

    # ---------- -v 模式 ----------
    if [ $verbose -eq 1 ]; then
        if [ $show_timestamp -eq 1 ] && [ $timestamp_pretty -eq 0 ]; then
            if ! can_use_ping_dashD; then
                err "当前 ping 不支持 -D 选项, 无法在 -v 模式下使用系统时间戳"
                return 1
            fi
            local last=$((${#ping_cmd[@]} - 1))
            ping_cmd=("${ping_cmd[@]:0:$last}" -D "${ping_cmd[@]:$last}")
        fi
        local old_trap=$(trap -p INT)
        trap 'echo ""; return 130' INT
        "${ping_cmd[@]}"
        local ret=$?
        if [ -n "$old_trap" ]; then
            eval "$old_trap"
        else
            trap - INT
        fi
        return $ret
    fi

    # ---------- 正常模式 ----------
    local tmp_stat="${TMP_DIR:-/storage/emulated/0/tmp}/ping_stat_$$_$RANDOM"
    mkdir -p "$(dirname "$tmp_stat")" 2>/dev/null
    > "$tmp_stat"

    if [ $quiet -eq 0 ]; then
        if [ $flood_mode -eq 1 ] && ! can_use_real_flood; then
            cecho "洪水模拟模式: 发送接近无限个包, 包大小${data_bytes}字节, 间隔0.2秒"
        fi
        cecho "正在 Ping $display_target 具有 $data_bytes($(echo "$data_bytes+$icmp_header" | bc)) 字节的数据:"
    fi

    local interrupted=0
    local old_trap=$(trap -p INT)
    trap 'interrupted=1' INT

    local start_time=$(get_time)
    "${ping_cmd[@]}" 2>&1 | {
        trap 'write_stats_and_exit' INT TERM

        local sent=0 recv=0
        local sum_us=0 min_us="" max_us=""
        local rtt_count=0
        local error_flag=0
        local RE_TIME='time[=<]([0-9.]+)'

        write_stats_and_exit() {
            if [ $error_flag -eq 0 ]; then
                echo "SENT=$sent" > "$tmp_stat"
                echo "RECV=$recv" >> "$tmp_stat"
                echo "SUM_US=$sum_us" >> "$tmp_stat"
                echo "MIN_US=$min_us" >> "$tmp_stat"
                echo "MAX_US=$max_us" >> "$tmp_stat"
                echo "RTT_COUNT=$rtt_count" >> "$tmp_stat"
            else
                echo "ERROR" > "$tmp_stat"
            fi
            exit 0
        }

        while IFS= read -r line; do
            if [[ "$line" == *"unknown host"* || "$line" == *"name or service not known"* ]]; then
                err "未知的主机 \"$target\""
                error_flag=1
                break
            elif [[ "$line" == *"network is unreachable"* || "$line" == *"no route to host"* ]]; then
                err "目标 \"$target\" 不可达"
                error_flag=1
                break
            elif [[ "$line" == *"no such device"* || "$line" == *"cannot bind"* || "$line" == *"bind failed"* || "$line" == *"SO_BINDTODEVICE"* || "$line" == *"bind: "* ]]; then
                err "无法绑定接口/源地址: $line"
                error_flag=1
                break
            elif [[ "$line" == *"invalid option"* || "$line" == *"unknown option"* || "$line" == *"unrecognized option"* ]]; then
                err "底层 ping 拒绝执行: $line"
                error_flag=1
                break
            fi

            if [[ "$line" =~ ([0-9]+)\ packets\ transmitted ]]; then
                sent="${BASH_REMATCH[1]}"
            fi

            if [[ "$line" == *"bytes from"* ]]; then
                t=""
                if [[ "$line" =~ $RE_TIME ]]; then
                    t="${BASH_REMATCH[1]}"
                fi
                ttl="?"
                if [[ "$line" =~ ttl=([0-9]+) ]]; then
                    ttl="${BASH_REMATCH[1]}"
                elif [[ "$line" =~ hlim=([0-9]+) ]]; then
                    ttl="${BASH_REMATCH[1]}"
                fi

                local ts_prefix=""
                if [ $show_timestamp -eq 1 ]; then
                    if [ $timestamp_pretty -eq 1 ]; then
                        ts_prefix="[$(format_timestamp "$timestamp_format")] "
                    else
                        ts_prefix="[$(get_time)] "
                    fi
                fi

                recv=$((recv + 1))

                if [ -n "$t" ]; then
                    local t_us=$(parse_ms_to_us "$t")
                    sum_us=$((sum_us + t_us))
                    rtt_count=$((rtt_count + 1))
                    if [ -z "$min_us" ] || [ $t_us -lt $min_us ]; then min_us=$t_us; fi
                    if [ -z "$max_us" ] || [ $t_us -gt $max_us ]; then max_us=$t_us; fi

                    if [ $quiet -eq 0 ]; then
                        printf -v display_time "%.3f" "$t"
                        if [ -n "$ts_prefix" ]; then
                            printf '\033[33m%s\033[0m' "$ts_prefix"
                        fi
                        _cprint -c 32 "来自 $resolved_ip 的回复: 字节=$data_bytes 时间=${display_time}ms TTL=$ttl"
                    fi
                else
                    if [ $quiet -eq 0 ]; then
                        if [ -n "$ts_prefix" ]; then
                            printf '\033[33m%s\033[0m' "$ts_prefix"
                        fi
                        _cprint -c 32 "来自 $resolved_ip 的回复: 字节=$data_bytes TTL=$ttl (无时间信息)"
                    fi
                fi
            fi
        done

        write_stats_and_exit
    }

    wait

    local end_time=$(get_time)

    if [ -n "$old_trap" ]; then
        eval "$old_trap"
    else
        trap - INT
    fi

    if [ $interrupted -eq 1 ]; then
        echo ""
        cecho "Ping 已终止"
    fi

    local sent=0 recv=0 sum_us=0 min_us="" max_us="" rtt_count=0
    local error_flag=0
    if [ -f "$tmp_stat" ]; then
        while IFS= read -r line; do
            case "$line" in
                SENT=*) sent="${line#SENT=}" ;;
                RECV=*) recv="${line#RECV=}" ;;
                SUM_US=*) sum_us="${line#SUM_US=}" ;;
                MIN_US=*) min_us="${line#MIN_US=}" ;;
                MAX_US=*) max_us="${line#MAX_US=}" ;;
                RTT_COUNT=*) rtt_count="${line#RTT_COUNT=}" ;;
                ERROR) error_flag=1 ;;
            esac
        done < "$tmp_stat"
        rm -f "$tmp_stat"
    fi

    if [ $error_flag -eq 1 ]; then
        return 1
    fi

    if [ $sent -gt 0 ] || [ $recv -gt 0 ]; then
        if [ $sent -eq 0 ]; then sent=$recv; fi
        local loss=$((sent - recv))
        local loss_rate=0
        [ $sent -gt 0 ] && loss_rate=$((loss * 100 / sent))
        echo ""
        cecho "$target 的 Ping 统计信息:"
        cecho "    数据包: 已发送 = $sent, 已接收 = $recv, 丢失 = $loss ($loss_rate% 丢失)"

        if [ $rtt_count -gt 0 ]; then
            local avg_us=$(( sum_us / rtt_count ))
            local min_disp=$(us_to_ms_str "$min_us")
            local max_disp=$(us_to_ms_str "$max_us")
            local avg_disp=$(us_to_ms_str "$avg_us")
            cecho "数据包的往返时间统计(有效统计 $rtt_count 个包):"
            cecho "    最短 = ${min_disp}, 最长 = ${max_disp}, 平均 = ${avg_disp}"
        elif [ $recv -gt 0 ]; then
            err "   收到 $recv 个回复, 但底层未提供 RTT 信息"
        else
            err "   没有收到任何有效回复"
        fi

        local duration=$(echo "$end_time - $start_time" | bc 2>/dev/null)
        if [ -n "$duration" ] && [ "$(echo "$duration > 0" | bc 2>/dev/null)" = "1" ]; then
            printf -v duration_fmt "%.3f" "$duration"
            cecho "总耗时: ${duration_fmt} 秒"
        fi
    else
        err "还没有发送任何包"
    fi

    return 0
}