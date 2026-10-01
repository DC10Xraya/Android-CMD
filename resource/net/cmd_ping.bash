#resource/cmd_ping.bash
#Android CMD PING remake dev 2026_10_01
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
    cecho "-Dp 格式         显示人性化时间戳, 默认 HH:mm:ss"
    cecho "占位符: YYYY=年  YY=两位年  MM=月  DD=日"
    cecho "       HH=24时  hh=12时  mm=分  ss=秒"
    cecho "       AA=星期全称  aa=星期缩写"
    cecho "       同时支持系统 date 格式"
    cecho "-v               直接显示系统的原始输出"
    cecho "-q               不显示每次回复, 只输出统计信息"
    cecho "-V               显示 PING 函数版本和底层 ping 版本"
    return 0
fi

    # ---------- 参数解析 ----------
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

    # 临时存储解析过程中是否遇到 -s 或 -i(用于冲突检测)
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
            -nf|-inf)   # 支持两种写法
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
                if [ $# -ge 2 ]; then
                    interval=$(echo "$2" | sed 's/[^0-9.]//g')
                    if [ -z "$interval" ] || [ "$interval" = "." ]; then
                        err "选项 -i 需要指定有效的间隔时间(大于等于0.2的数字)"; valid_args=0; break
                    fi
                    if [ "$(echo "$interval < 0.2" | bc 2>/dev/null)" = "1" ]; then
                        err "选项 -i 间隔不能小于0.2秒"; valid_args=0; break
                    fi
                    shift 2
                else
                    err "选项 -i 需要指定间隔时间"; valid_args=0; break
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
                # 自定义占位符 或 系统 date 格式(%开头) 均可作为格式串
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
                    err "多余的参数: $1"; valid_args=0; break
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

    # -nf 和 -n 互斥
    if [ $has_nf -eq 1 ] && [ $has_n -eq 1 ]; then
        err "选项 -nf/-inf (无限制发送) 和 -n (指定次数) 不能同时使用"; return 1
    fi

    # -4 和 -6 互斥
    if [ $ipv4 -eq 1 ] && [ $ipv6 -eq 1 ]; then
        err "选项 -4 (强制IPv4) 和 -6 (强制IPv6) 不能同时使用"; return 1
    fi

    # -Dp 和 -v 互斥( -v 直接透传原始输出, 人性化时间戳包装不会生效 )
    if [ $timestamp_pretty -eq 1 ] && [ $verbose -eq 1 ]; then
        err "选项 -Dp (人性化时间戳) 和 -v (原始输出) 不能同时使用"; return 1
    fi

    # ---------- -V 版本信息 ----------
    if [ $show_version -eq 1 ]; then
        cecho -b "PING 函数版本: Android CMD PING remake dev 2026_10_01"
        cecho "底层 ping 版本信息:"
        local vout
        vout=$(ping -V 2>&1)
        if [ -n "$vout" ]; then
            echo "$vout" | while IFS= read -r vline; do
                cecho "    $vline"
            done
        else
            err "    无法获取底层 ping 版本"
        fi
        if command -v ping6 >/dev/null 2>&1; then
            cecho "ping6 (IPv6 回退方案):"
            local vout6
            vout6=$(ping6 -V 2>&1 | head -1)
            [ -n "$vout6" ] && cecho "    $vout6"
        else
            cecho "未检测到 ping6"
        fi
        return 0
    fi

    [ -z "$target" ] && { err "需要指定目标 IP 地址或域名"; return 1; }

    if [ "$mode" = "count" ] && [ "$count" -eq 0 ]; then
        count=4
    fi

    # ---------- 工具检测 ----------
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

    # 检测是否支持真正的 -f
    can_use_real_flood() {
        local output
        output=$(ping -f -c 1 -W 1 127.0.0.1 2>&1)
        local ret=$?
        if [ $ret -eq 0 ]; then
            return 0
        else
            if echo "$output" | grep -qiE "cannot flood|operation not permitted|not allowed"; then
                return 1
            else
                return 1
            fi
        fi
    }

    # 检测 ping 是否支持 -6 选项
    can_use_ping_dash6() {
        local output
        output=$(ping -6 -c 1 -W 1 ::1 2>&1)
        # 只要报的是"选项无效"类的错误, 就说明不支持 -6
        if echo "$output" | grep -qiE "invalid option|unknown option|unrecognized option|usage:"; then
            return 1
        fi
        return 0
    }

    # 检测 ping 是否支持 -D 选项(用于 -v 模式下透传系统时间戳)
    can_use_ping_dashD() {
        local output
        output=$(ping -D -c 1 -W 1 127.0.0.1 2>&1)
        if echo "$output" | grep -qiE "invalid option|unknown option|unrecognized option|usage:"; then
            return 1
        fi
        return 0
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

    # 人性化时间戳: 自定义占位符 -> 系统 date 格式, 系统格式原样透传
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

    # ---------- IPv6 回退方案检测 ----------
    # 用户输入 -6 时: 先尝试 ping -6, 失败则回退到 ping6
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

    # ---------- 构建显示目标和解析后的 IP ----------
    local display_target="$target"
    local resolved_ip=""
    if [ $ipv6 -eq 1 ]; then
        # 强制 IPv6 时不做 IPv4 解析, 直接展示用户输入
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

    # ---------- 构建 ping 命令 ----------
    local ping_cmd="ping"
    local data_bytes=56   # 默认显示, 会被后续覆盖
    local icmp_header=28  # IPv4 头部 28 字节, IPv6 为 40

    # IPv6 回退: 使用 ping6 命令时不再传 -6
    if [ $use_ping6 -eq 1 ]; then
        ping_cmd="ping6"
        icmp_header=40
    else
        [ $ipv4 -eq 1 ] && ping_cmd="$ping_cmd -4"
        [ $ipv6 -eq 1 ] && ping_cmd="$ping_cmd -6" && icmp_header=40
    fi

    # 全局附加选项(两种模式通用)
    [ $bcast_ok -eq 1 ] && ping_cmd="$ping_cmd -b"
    [ $no_src_change -eq 1 ] && ping_cmd="$ping_cmd -B"
    [ $bypass_route -eq 1 ] && ping_cmd="$ping_cmd -r"
    [ $no_mcast_loop -eq 1 ] && ping_cmd="$ping_cmd -L"
    [ -n "$sndbuf" ] && ping_cmd="$ping_cmd -S $sndbuf"

    if [ $flood_mode -eq 1 ]; then
        if can_use_real_flood; then
            ping_cmd="$ping_cmd -f"
            [ -n "$source_iface" ] && ping_cmd="$ping_cmd -I $source_iface"
            [ -n "$ttl_val" ] && ping_cmd="$ping_cmd -t $ttl_val"
            ping_cmd="$ping_cmd -W $per_packet_timeout"
            if [ "$(echo "$total_timeout > 0" | bc 2>/dev/null)" = "1" ] && command -v timeout >/dev/null 2>&1; then
                ping_cmd="timeout $total_timeout $ping_cmd"
            fi
            ping_cmd="$ping_cmd $target"
            data_bytes=56
        else
            # 模拟洪水：强制参数
            local fake_count=9999999
            local fake_interval=0.2
            local fake_packet_size=65507   # 强制固定
            data_bytes=$fake_packet_size
            ping_cmd="$ping_cmd -c $fake_count -s $fake_packet_size -i $fake_interval -W $per_packet_timeout"
            [ -n "$source_iface" ] && ping_cmd="$ping_cmd -I $source_iface"
            [ -n "$ttl_val" ] && ping_cmd="$ping_cmd -t $ttl_val"
            if [ "$(echo "$total_timeout > 0" | bc 2>/dev/null)" = "1" ] && command -v timeout >/dev/null 2>&1; then
                ping_cmd="timeout $total_timeout $ping_cmd"
            fi
            ping_cmd="$ping_cmd $target"
        fi
    else
        # 非洪水模式
        [ "$mode" = "count" ] && ping_cmd="$ping_cmd -c $count"
        ping_cmd="$ping_cmd -i $interval -W $per_packet_timeout"
        [ -n "$packet_size" ] && ping_cmd="$ping_cmd -s $packet_size" && data_bytes=$packet_size
        [ -n "$source_iface" ] && ping_cmd="$ping_cmd -I $source_iface"
        [ -n "$ttl_val" ] && ping_cmd="$ping_cmd -t $ttl_val"
        if [ "$(echo "$total_timeout > 0" | bc 2>/dev/null)" = "1" ] && command -v timeout >/dev/null 2>&1; then
            ping_cmd="timeout $total_timeout $ping_cmd"
        fi
        ping_cmd="$ping_cmd $target"
        # data_bytes 已在上面设置
    fi

    # ---------- 处理 -v 模式 ----------
    if [ $verbose -eq 1 ]; then
        # -v 与 -D 同用: 直接把系统 -D 透传给底层 ping
        if [ $show_timestamp -eq 1 ] && [ $timestamp_pretty -eq 0 ]; then
            if ! can_use_ping_dashD; then
                err "当前 ping 不支持 -D 选项, 无法在 -v 模式下使用系统时间戳"
                return 1
            fi
            ping_cmd="${ping_cmd% $target} -D $target"
        fi
        local old_trap=$(trap -p INT)
        trap 'echo ""; return 130' INT
        eval "$ping_cmd"
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

    local start_time=$(get_time)

    if [ $quiet -eq 0 ]; then
        if [ $flood_mode -eq 1 ] && ! can_use_real_flood; then
            cecho "洪水模拟模式: 发送接近无限个包, 包大小${data_bytes}字节, 间隔0.2秒"
        fi
        if [ $use_ping6 -eq 1 ]; then
            cecho "已回退至 ping6"
        fi
        cecho "正在 Ping $display_target 具有 $data_bytes($(echo "$data_bytes+$icmp_header" | bc)) 字节的数据:"
    fi

    local interrupted=0
    local old_trap=$(trap -p INT)
    trap 'interrupted=1' INT

    eval "$ping_cmd" 2>&1 | {
        trap 'write_stats_and_exit' INT TERM

        local sent=0 recv=0
        local sum=0 min="" max="" count=0
        local error_flag=0

        write_stats_and_exit() {
            if [ $error_flag -eq 0 ]; then
                echo "SENT=$sent" > "$tmp_stat"
                echo "RECV=$recv" >> "$tmp_stat"
                echo "SUM=$sum" >> "$tmp_stat"
                echo "MIN=$min" >> "$tmp_stat"
                echo "MAX=$max" >> "$tmp_stat"
                echo "COUNT=$count" >> "$tmp_stat"
            else
                echo "ERROR" > "$tmp_stat"
            fi
            exit 0
        }

        while IFS= read -r line; do
            if echo "$line" | grep -qiE "unknown host|name or service not known"; then
                err "未知的主机 \"$target\""
                error_flag=1
                break
            elif echo "$line" | grep -qiE "network is unreachable|no route to host"; then
                err "目标 \"$target\" 不可达"
                error_flag=1
                break
            elif echo "$line" | grep -qiE "invalid option|unknown option|unrecognized option"; then
                err "底层 ping 拒绝执行: $line"
                error_flag=1
                break
            fi

            if echo "$line" | grep -q "packets transmitted"; then
                sent=$(echo "$line" | grep -oE '[0-9]+ packets transmitted' | grep -oE '[0-9]+')
            fi

            if echo "$line" | grep -q "bytes from"; then
                recv=$((recv + 1))
                t=$(echo "$line" | grep -oE 'time[=<][0-9.]+' | grep -oE '[0-9.]+' | head -1)
                ttl=$(echo "$line" | grep -oE 'ttl=[0-9]+' | cut -d= -f2)
                # IPv6 用 hlim 替代 ttl
                [ -z "$ttl" ] && ttl=$(echo "$line" | grep -oE 'hlim=[0-9]+' | cut -d= -f2)
                [ -z "$ttl" ] && ttl="?"

                # -D/-Dp: 自己加时间戳包装, 黄色渲染
                local ts_prefix=""
                if [ $show_timestamp -eq 1 ]; then
                    if [ $timestamp_pretty -eq 1 ]; then
                        ts_prefix="[$(format_timestamp "$timestamp_format")] "
                    else
                        ts_prefix="[$(get_time)] "
                    fi
                fi

                if [ -n "$t" ]; then
                    if [ $quiet -eq 0 ]; then
                        printf -v display_time "%.3f" "$t"
                        if [ -n "$ts_prefix" ]; then
                            printf '\033[33m%s\033[0m' "$ts_prefix"
                        fi
                        _cprint -c 32 "来自 $resolved_ip 的回复: 字节=$data_bytes 时间=${display_time}ms TTL=$ttl"
                    fi
                    sum=$(echo "$sum + $t" | bc)
                    if [ -z "$min" ] || [ "$(echo "$t < $min" | bc)" = "1" ]; then
                        min="$t"
                    fi
                    if [ -z "$max" ] || [ "$(echo "$t > $max" | bc)" = "1" ]; then
                        max="$t"
                    fi
                    count=$((count + 1))
                else
                    if [ $quiet -eq 0 ]; then
                        if [ -n "$ts_prefix" ]; then
                            printf '\033[33m%s\033[0m' "$ts_prefix"
                        fi
                        _cprint -c 32 "$line"
                    fi
                fi
            fi
        done

        write_stats_and_exit
    }

    wait

    if [ -n "$old_trap" ]; then
        eval "$old_trap"
    else
        trap - INT
    fi

    if [ $interrupted -eq 1 ]; then
        echo ""
        cecho "Ping 已终止"
    fi

    local sent=0 recv=0 sum=0 min="" max="" count=0
    local error_flag=0
    if [ -f "$tmp_stat" ]; then
        while IFS= read -r line; do
            case "$line" in
                SENT=*) sent="${line#SENT=}" ;;
                RECV=*) recv="${line#RECV=}" ;;
                SUM=*) sum="${line#SUM=}" ;;
                MIN=*) min="${line#MIN=}" ;;
                MAX=*) max="${line#MAX=}" ;;
                COUNT=*) count="${line#COUNT=}" ;;
                ERROR) error_flag=1 ;;
            esac
        done < "$tmp_stat"
        rm -f "$tmp_stat"
    fi

    if [ $error_flag -eq 1 ]; then
        return 1
    fi

    if [ $sent -gt 0 ] || [ $recv -gt 0 ] || [ $count -gt 0 ]; then
        if [ $sent -eq 0 ]; then sent=$recv; fi
        local loss=$((sent - recv))
        local loss_rate=0
        [ $sent -gt 0 ] && loss_rate=$((loss * 100 / sent))
        echo ""
        cecho "$target 的 Ping 统计信息:"
        cecho "    数据包: 已发送 = $sent, 已接收 = $recv, 丢失 = $loss ($loss_rate% 丢失)"

        if [ $count -gt 0 ]; then
            # 安全计算平均值
            if [[ -n "$sum" && "$sum" =~ ^[0-9.]+$ ]] && [ "$count" -gt 0 ]; then
                avg=$(echo "scale=4; $sum / $count" | bc 2>/dev/null)
                if [ -z "$avg" ] || [ "$avg" = "0" ]; then
                    avg_disp="N/A"
                else
                    avg_disp=$(printf "%.3fms" "$avg")
                fi
            else
                avg_disp="N/A"
            fi
            min_disp=$(printf "%.3fms" "$min")
            max_disp=$(printf "%.3fms" "$max")
            cecho "数据包的往返时间统计(有效统计 $count 个包):"
            cecho "    最短 = ${min_disp}, 最长 = ${max_disp}, 平均 = ${avg_disp}"
        elif [ $recv -gt 0 ]; then
            err "   所有回复均无时间信息, 无法统计往返时间"
        else
            err "   没有收到任何有效回复"
        fi

        local end_time=$(get_time)
        local duration=$(echo "$end_time - $start_time" | bc 2>/dev/null)
        if [ -n "$duration" ] && [ "$(echo "$duration > 0" | bc 2>/dev/null)" = "1" ]; then
            printf -v duration_fmt "%.3f" "$duration"
            cecho "总耗时: ${duration_fmt} 秒"
        fi
    else
        err "还没有未发送任何包"
    fi

    return 0
}