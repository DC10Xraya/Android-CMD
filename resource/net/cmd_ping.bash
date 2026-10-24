#resource/cmd_ping.bash
#Android CMD PING remake dev 2026_10_24
cmd_ping() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -eq 0 ]; then
    ccat << "EOF"
//cecho -b "用法: PING [-n] [--inf] [-f|--ff|--fs] [-w] [-W] [-i] [-s] [-I] [-t] [-4|-6] [-b] [-B] [-S] [-r] [-L] [-D] [-Dp] [-v] [-q] [-V] <域名/IP>"
//cecho -b "选项说明: "
-n 次数          指定发送的次数(正整数,默认4)
--inf            无限制发送(不限制包数)
-f               洪水模式(优先系统洪水, 失败则模拟)
--ff             强制使用系统洪水模式
--fs             强制使用模拟洪水模式
-w 总超时(s)     整个过程的总时间限制(正数)
-W 单包超时(s)   每个包的超时时间(正整数,默认1)
-i 间隔(s)       成功收到回复后等待的间隔时间(支持浮点数,>0,默认0.5)
                 root 设备可小于 0.2 秒; 非 root 最小 0.2 秒
-s 包大小(字节)  发送的数据包大小(IPv4:1-65507, IPv6:1-65487, 默认56)
-I 接口/IP       指定源接口或源IP地址
-t TTL/HLIM      设置 IP 生存时间/跳数限制 (1-255)
-4               强制使用 IPv4
-6               强制使用 IPv6(优先ping -6,回退ping6)
-b               允许 ping 广播地址
-B               不改变探测包的源地址
-S 缓冲区        设置发送缓冲区大小(字节)
-r               绕过路由表直接发送到本地接口
-L               抑制组播回环
-D               显示 Unix 时间戳
-Dp [格式]       显示人性化时间戳(格式可省略, 默认 HH:mm:ss)
//cecho -b "占位符:"
  YYYY=年  YY=两位年  MM=月  DD=日
  HH=24时  hh=12时  mm=分  ss=秒
  mmm=毫秒(3位总值)        如 802
  uuuuuu=微秒(6位总值)     如 802598
  uuu=微秒分量(3位)        如 598
  NNNNNNNNN=纳秒(9位总值)  如 802598399
  NN=纳秒分量(3位)         如 399
  AA=星期全称  aa=星期缩写
  TZ=时区偏移              如 +08:00
-v               直接显示系统的原始输出
-q               不显示每次回复, 只输出统计信息
-V               显示 PING 函数版本和底层 ping 版本
EOF
    return 0
fi

    # ---------- 选项解析 ----------
    local count=0 mode="count" target="" packet_size=""
    local per_packet_timeout=1
    local total_timeout=0
    local interval=0.5
    local valid_args=1
    local has_n=0 has_nf=0
    local flood_mode=0 flood_force_sys=0 flood_force_sim=0
    local sys_flood_available=0
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
            --inf)
                mode="inf"; has_nf=1; shift
                ;;
            -f)
                if ! confirm "使用洪水?将自动选择系统或模拟\n系统洪水约6.5MB/s, 模拟洪水约360KB/s"; then
                    return
                fi
                flood_mode=1
                shift
                ;;
            --ff)
                if ! ping -f -c 1 -W 1 127.0.0.1 >/dev/null 2>&1; then
                    err "当前系统不支持系统洪水"
                    return 1
                fi
                sys_flood_available=1
                if ! confirm "使用系统洪水? 会消耗大量流量(无额外参数时约6.5MB/s)"; then
                    return
                fi
                flood_mode=1; flood_force_sys=1
                shift
                ;;
            --fs)
                if ! confirm "使用模拟洪水?会消耗一定流量(约360KB/s)"; then
                    return
                fi
                flood_mode=1; flood_force_sim=1
                shift
                ;;
            -s)
                opt_s_provided=1
                if [ $# -ge 2 ] && echo "$2" | grep -qE '^[0-9]+$' && [ "$2" -ge 1 ] && [ "$2" -le 65507 ]; then
                    packet_size="$2"; shift 2
                else
                    err "选项 -s 需要指定有效包大小(IPv4:1-65507, IPv6:1-65487)"; valid_args=0; break
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
                if [ $# -ge 2 ] && echo "$2" | grep -qE '^[0-9]+(\.[0-9]+)?$' && [ "$(echo "$2 > 0" | bc 2>/dev/null)" = "1" ]; then
                    interval="$2"; shift 2
                else
                    err "选项 -i 需要指定有效的间隔时间(大于0的数字)"; valid_args=0; break
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
                    err "选项 -t 需要指定有效的 TTL/HLIM 值 (1-255)"; valid_args=0; break
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
                if [ $# -ge 2 ] && echo "$2" | grep -qE 'YYYY|YY|MM|DD|HH|hh|mmm|uuu|mm|ss|NN|AA|aa|%'; then
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
    if [ $flood_force_sys -eq 1 ] && [ $flood_force_sim -eq 1 ]; then
        err "选项 --ff (强制系统洪水) 和 --fs (强制模拟洪水) 不能同时使用"; return 1
    fi

    if [ $flood_mode -eq 1 ] && [ $has_nf -eq 1 ]; then
        err "选项 -f/--ff/--fs (洪水模式) 和 --inf (无限制发送) 不能同时使用"; return 1
    fi

    if [ $has_nf -eq 1 ] && [ $has_n -eq 1 ]; then
        err "选项 --inf (无限制发送) 和 -n (指定次数) 不能同时使用"; return 1
    fi

    if [ $ipv4 -eq 1 ] && [ $ipv6 -eq 1 ]; then
        err "选项 -4 (强制IPv4) 和 -6 (强制IPv6) 不能同时使用"; return 1
    fi

    if [ $timestamp_pretty -eq 1 ] && [ $verbose -eq 1 ]; then
        err "选项 -Dp (人性化时间戳) 和 -v (原始输出) 不能同时使用"; return 1
    fi

    command -v ping >/dev/null 2>&1 || { err "未找到 ping 命令"; return 1; }
    # ---------- 辅助函数 ----------
    is_ip() {
        echo "$1" | grep -qE '^([0-9]{1,3}\.){3}[0-9]{1,3}$'
    }

    # 单目标显示截断: 超过25字符取前22字符 + "..."
    truncate_display() {
        local s="$1"
        if [ ${#s} -gt 25 ]; then
            echo "${s:0:22}..."
        else
            echo "$s"
        fi
    }

    # 域名+IP 显示: 保证括号完整, 且 domain 与 ip 两部分总长不超过25
    # 输出格式固定为 "domain (ip)"
    format_domain_ip() {
        local d="$1"
        local i="$2"
        local total=25

        # 单目标直接按 25 截断
        if [ -z "$i" ] || [ "$d" = "$i" ]; then
            truncate_display "$d"
            return
        fi

        local d_len=${#d}
        local i_len=${#i}

        # 两部分总长未超限, 原样输出
        if [ $((d_len + i_len)) -le $total ]; then
            echo "$d ($i)"
            return
        fi

        # 先给 IP 分配最多 12 个字符, 剩余给域名(至少 8 个)
        local i_alloc=12
        [ $i_len -lt $i_alloc ] && i_alloc=$i_len
        local d_alloc=$((total - i_alloc))
        [ $d_alloc -lt 8 ] && d_alloc=8

        # 若域名本身较短, 把剩余额度让给 IP
        if [ $d_len -lt $d_alloc ]; then
            d_alloc=$d_len
            i_alloc=$((total - d_alloc))
        fi

        local d_disp i_disp
        if [ $d_len -gt $d_alloc ]; then
            if [ $d_alloc -le 3 ]; then
                d_disp="..."
            else
                d_disp="${d:0:$((d_alloc - 3))}..."
            fi
        else
            d_disp="$d"
        fi

        if [ $i_len -gt $i_alloc ]; then
            if [ $i_alloc -le 3 ]; then
                i_disp="..."
            else
                i_disp="${i:0:$((i_alloc - 3))}..."
            fi
        else
            i_disp="$i"
        fi

        echo "$d_disp ($i_disp)"
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

    # 从 minimal interval 错误行中提取最小间隔, 支持 ms/us/ns/s
    extract_interval_min() {
        local line="$1"
        echo "$line" | grep -oE '[0-9]+(\.[0-9]+)?[[:space:]]*(ms|us|ns|s)' | head -1 | tr -d '[:space:]'
    }

    # 探测系统洪水可用性 (供 -V 和 -f 自动选择使用, 只探测一次)
    if [ $sys_flood_available -eq 0 ] && { [ $show_version -eq 1 ] || { [ $flood_mode -eq 1 ] && [ $flood_force_sim -eq 0 ]; }; }; then
        if can_use_real_flood; then
            sys_flood_available=1
        fi
    fi

    # ---------- -V 版本信息 ----------
    if [ $show_version -eq 1 ]; then
    cecho -b "PING/PING6 函数版本: Android CMD PING remake dev 2026_10_24"
    cecho -b "底层 ping 版本信息:"
    local vout
    vout=$(ping -V 2>&1)
    if [ -n "$vout" ]; then
        echo "$vout" | while IFS= read -r vline; do
            cecho -c 92 "    $vline"
        done
    else
        err "    无法获取底层 ping 版本"
    fi
    cecho -b "IPv6方案: "
    if ping -6 -c 1 ::1 >/dev/null 2>&1; then
    cecho -c 92 "    1. ping -6: 可用"
    else
    err "    1. ping -6: 不可用"
    fi
    if command -v ping6 >/dev/null 2>&1; then
        cecho -c 92 "    2. ping6:"
        local vout6
        vout6=$(ping6 -V 2>&1 | head -1)
        [ -n "$vout6" ] && cecho -c 92 "    $vout6"
    else
    err "    2. ping6: 不可用"
    fi
    cecho -c "#C0C0C0" "    [?]: IPv6方案优先ping -6, 其次ping6"
    cecho -b "功能支持: "
    if [ $sys_flood_available -eq 1 ]; then
        cecho -c 92 "    系统洪水: 可用"
    else
        err "    系统洪水: 不可用"
    fi
    local iv_test iv_err iv_min
    iv_test=$(ping -i 0.1 -c 1 -W 1 127.0.0.1 2>&1)
    if echo "$iv_test" | grep -qi "minimal interval"; then
        iv_err=$(echo "$iv_test" | grep -i "minimal interval" | head -1)
        iv_min=$(extract_interval_min "$iv_err")
        if [ -n "$iv_min" ]; then
            err "    间隔限制: 最小 $iv_min"
        else
            err "    间隔限制: $iv_err"
        fi
    else
        cecho -c 92 "    间隔限制: 无"
    fi
    return 0
fi

[ -z "$target" ] && { err "需要指定目标 IP 地址或域名"; return 1; }

if [ "$mode" = "count" ] && [ "$count" -eq 0 ] && [ $flood_mode -eq 0 ]; then
    count=4
fi

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

    # ---------- 判定实际 IPv6 目标 ----------
    local is_v6=0
    if [ $ipv6 -eq 1 ] || [ $use_ping6 -eq 1 ]; then
        is_v6=1
    elif [ $ipv4 -eq 0 ] && echo "$target" | grep -q ':'; then
        is_v6=1
    fi

    # ---------- -s 与 IPv6 兼容检查 ----------
    if [ -n "$packet_size" ] && [ $is_v6 -eq 1 ] && [ "$packet_size" -gt 65487 ]; then
        err "IPv6 模式下包大小不能超过 65487 字节 (当前 $packet_size)"; return 1
    fi

    # ---------- 显示目标 / 解析 IP ----------
    local display_target=""
    local resolved_ip=""
    if [ $ipv6 -eq 1 ]; then
        display_target=$(truncate_display "$target")
        resolved_ip="$target"
    elif is_ip "$target"; then
        display_target=$(truncate_display "$target")
        resolved_ip="$target"
    else
        local ip=$(get_ip_from_domain "$target")
        if [ -n "$ip" ]; then
            display_target=$(format_domain_ip "$target" "$ip")
            resolved_ip="$ip"
        else
            display_target=$(truncate_display "$target")
            resolved_ip="$target"
        fi
    fi

    # ---------- 构建 ping 命令(数组, 不用 eval) ----------
    local -a ping_cmd=(ping)
    local data_bytes=56
    local icmp_header=28
    local use_sys_flood=0

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
        if [ $flood_force_sys -eq 1 ]; then
            use_sys_flood=1
        elif [ $flood_force_sim -eq 1 ]; then
            use_sys_flood=0
        else
            if [ $sys_flood_available -eq 1 ]; then
                use_sys_flood=1
            fi
        fi

        if [ $use_sys_flood -eq 0 ]; then
            if [ $opt_i_provided -eq 1 ]; then
                err "模拟洪水和 -i (间隔) 不能同时使用 (强制间隔0.2秒)"; return 1
            fi
            if [ $opt_s_provided -eq 1 ]; then
                err "模拟洪水和 -s (包大小) 不能同时使用 (强制包大小65507)"; return 1
            fi
        fi

        if [ $use_sys_flood -eq 1 ]; then
            ping_cmd+=(-f)
            if [ $has_n -eq 1 ]; then
                ping_cmd+=(-c "$count")
            fi
            if [ -n "$packet_size" ]; then
                ping_cmd+=(-s "$packet_size")
                data_bytes=$packet_size
            fi
            if [ $opt_i_provided -eq 1 ]; then
                ping_cmd+=(-i "$interval")
            fi
            [ -n "$source_iface" ] && ping_cmd+=(-I "$source_iface")
            [ -n "$ttl_val" ] && ping_cmd+=(-t "$ttl_val")
            ping_cmd+=(-W "$per_packet_timeout")
            apply_total_timeout
            ping_cmd+=("$target")
        else
            local fake_interval=0.2
            local fake_packet_size=65507
            data_bytes=$fake_packet_size
            if [ $has_n -eq 1 ]; then
                ping_cmd+=(-c "$count")
            else
                ping_cmd+=(-c 9999999)
            fi
            ping_cmd+=(-s "$fake_packet_size" -i "$fake_interval" -W "$per_packet_timeout")
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
        if [ $flood_mode -eq 1 ] && [ $use_sys_flood -eq 0 ]; then
            cecho "洪水模拟模式: 发送接近无限个包, 包大小${data_bytes}字节, 间隔0.2秒"
        fi
        if [ $is_v6 -eq 1 ]; then
            cecho "正在 IPV6 Ping $display_target 具有 $data_bytes($(echo "$data_bytes+$icmp_header" | bc)) 字节的数据:"
        else
            cecho "正在 Ping $display_target 具有 $data_bytes($(echo "$data_bytes+$icmp_header" | bc)) 字节的数据:"
        fi
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
            elif [[ "$line" == *"minimal interval"* ]]; then
                local iv_min=$(extract_interval_min "$line")
                if [ -n "$iv_min" ]; then
                    err "间隔设置过小: 最小间隔为 $iv_min"
                else
                    err "间隔设置过小: $line"
                fi
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
                ttl_label="TTL"
                
                if [[ "$line" =~ ttl=([0-9]+) ]]; then
                    ttl="${BASH_REMATCH[1]}"
                    # 如果明确是 IPv6，但系统输出的是 ttl=，则修正显示为 HLIM
                    if [ "$is_v6" -eq 1 ]; then
                        ttl_label="HLIM"
                    fi
                elif [[ "$line" =~ hlim=([0-9]+) ]]; then
                    ttl="${BASH_REMATCH[1]}"
                    ttl_label="HLIM"
                fi

                local ts_prefix=""
                if [ $show_timestamp -eq 1 ]; then
                    if [ $timestamp_pretty -eq 1 ]; then
                        ts_prefix="[$(_human_date_now "$timestamp_format")] "
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
                        _cprint -c 32 "来自 $(truncate_display "$resolved_ip") 的回复: 字节=$data_bytes 时间=${display_time}ms ${ttl_label}=$ttl"
                    fi
                else
                    if [ $quiet -eq 0 ]; then
                        if [ -n "$ts_prefix" ]; then
                            printf '\033[33m%s\033[0m' "$ts_prefix"
                        fi
                        _cprint -c 32 "来自 $(truncate_display "$resolved_ip") 的回复: 字节=$data_bytes ${ttl_label}=$ttl (无时间信息)"
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
        cecho "$display_target 的 Ping 统计信息:"
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