#resource/cmd_portscan.bash
cmd_portscan() {
    if [ $# -eq 0 ]; then
        err "用法: PORTSCAN [-t 线程数] [-W 超时(s)] [-i 间隔(s)] <域名/IP> <开始端口> <结束端口>"
        cecho "示例: PORTSCAN -t 8 -W 1 -i 0.5 xraymc.top 25500 25600"
        return 1
    fi

    local target start_port end_port timeout_sec=1 interval=0.2 max_workers=4
    local show_help=0

    # ---------- 参数解析（不变） ----------
    while [ $# -gt 0 ]; do
        case "$1" in
            -t)
                if [ $# -ge 2 ] && echo "$2" | grep -qE '^[0-9]+$' && [ "$2" -gt 0 ] && [ "$2" -le 128 ]; then
                    max_workers="$2"
                    shift 2
                else
                    err "选项 -t 需要指定有效的线程数(1-128)"
                    return 1
                fi
                ;;
            -W)
                if [ $# -ge 2 ] && echo "$2" | grep -qE '^[0-9]+$' && [ "$2" -ge 1 ]; then
                    timeout_sec="$2"
                    shift 2
                else
                    err "选项 -W 需要指定有效的超时值(大于等于1的整数)"
                    return 1
                fi
                ;;
            -i)
                if [ $# -ge 2 ]; then
                    interval=$(echo "$2" | sed 's/[^0-9.]//g')
                    if [ -z "$interval" ] || [ "$interval" = "." ] || [ $(echo "$interval < 0" | bc 2>/dev/null || echo 0) -eq 1 ]; then
                        err "选项 -i 需要指定有效的间隔时间(大于等于0的数字)"
                        return 1
                    fi
                    shift 2
                else
                    err "选项 -i 需要指定间隔时间"
                    return 1
                fi
                ;;
            -h|--help)
                show_help=1
                shift
                ;;
            -*)
                err "未知选项: $1"
                return 1
                ;;
            *)
                target="$1"
                if [ $# -ge 3 ]; then
                    start_port="$2"
                    end_port="$3"
                    shift 3
                else
                    err "参数不足用法: PORTSCAN [-t 线程数] [-W 超时(s)] [-i 间隔(s)] <域名/IP> <开始端口> <结束端口>"
                    cecho "示例: PORTSCAN -t 8 -w 1 -i 0.5 xraymc.top 1145 1200"
                    return 1
                fi
                ;;
        esac
    done

    if [ -z "$target" ] || [ -z "$start_port" ] || [ -z "$end_port" ]; then
        err "无效参数用法: PORTSCAN [-t 线程数] [-w 超时(s)] [-i 间隔(s)] <域名/IP> <开始端口> <结束端口>"
        cecho "示例: PORTSCAN -t 8 -W 1 -i 0.5 xraymc.top 1145 1200"
        return 1
    fi

    start_port=$(echo "$start_port" | sed 's/[^0-9]//g')
    end_port=$(echo "$end_port" | sed 's/[^0-9]//g')

    if [ -z "$start_port" ] || [ -z "$end_port" ] || \
       [ "$start_port" -lt 1 ] || [ "$start_port" -gt 65535 ] || \
       [ "$end_port" -lt 1 ] || [ "$end_port" -gt 65535 ] || \
       [ "$start_port" -gt "$end_port" ]; then
        err "无效的端口号范围 (1-65535)"
        return 1
    fi

    # ---------- 域名解析（不变） ----------
    local ip="$target"
    local ip_regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
    if ! echo "$target" | grep -qE "$ip_regex"; then
        local resolved_ip=""
        if command -v getent >/dev/null 2>&1; then
            resolved_ip=$(getent hosts "$target" 2>/dev/null | awk '{print $1; exit}')
        fi

        if [ -z "$resolved_ip" ]; then
            ping_out=$($_PING -c 1 "$target" 2>/dev/null)
            resolved_ip=$(echo "$ping_out" | head -1 | sed -n 's/.*(\([0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\)).*/\1/p')
        fi

        if [ -z "$resolved_ip" ] && command -v nslookup >/dev/null 2>&1; then
            resolved_ip=$(nslookup "$target" 2>/dev/null | awk '/Address: / {print $2}' | grep -v '#' | head -1)
        fi

        if [ -n "$resolved_ip" ]; then
            ip="$resolved_ip"
        else
            err "无法解析域名 $target,将直接使用原名称连接"
        fi
    fi

    # ---------- 检测可用的端口测试工具（不变） ----------
    local conn_tool=""
    if command -v nc >/dev/null 2>&1; then
        if nc -z -w 1 localhost 1 >/dev/null 2>&1; then
            conn_tool="nc -z -w $timeout_sec"
        fi
    fi

    if [ -z "$conn_tool" ] && command -v bash >/dev/null 2>&1; then
        conn_tool="bash -c \"exec 2>/dev/null >/dev/tcp/$target/%PORT%\""
    fi

    if [ -z "$conn_tool" ]; then
        err "无法继续扫描,端口扫描需要 nc 或 bash"
        return 1
    fi

    local total_ports=$((end_port - start_port + 1))
    cecho "已设置参数: 线程数=${max_workers},超时=${timeout_sec}秒,间隔=${interval}秒"
    sleep 0.2
    cecho "开始扫描 $target ($ip) 端口 $start_port-$end_port (按Ctrl+C终止扫描)"
    echo ""

    # ---------- 设置运行标志 ----------
    GLOBAL_CMD_RUNNING=1
    GLOBAL_WORKER_PIDS=()
    GLOBAL_PROGRESS_PID=0

    # ---------- 创建临时目录和文件 ----------
    local tmp_dir="${TMP_DIR:-/storage/emulated/0/tmp}/portscan_$$"
    if ! mkdir -p "$tmp_dir" 2>/dev/null; then
        err "无法创建临时目录: $tmp_dir"
        GLOBAL_CMD_RUNNING=0
        return 1
    fi

    local open_file="$tmp_dir/open.txt"
    local result_file="$tmp_dir/results.txt"
    local stop_file="$tmp_dir/stop"

    rm -f "$open_file" "$result_file" "$stop_file" 2>/dev/null
    touch "$open_file"
    touch "$result_file"

    # ---------- 端口扫描函数 ----------
    portscan_worker() {
        local worker_id="$1"
        local worker_start="$2"
        local worker_end="$3"

        local use_bash=0
        if echo "$conn_tool" | grep -q "bash"; then
            use_bash=1
        else
            local nc_cmd="nc -z -w $timeout_sec"
        fi

        for port in $(seq $worker_start $worker_end); do
            if [ -f "$stop_file" ]; then
                break
            fi
            local alive=0
            if [ $use_bash -eq 1 ]; then
                if timeout "$timeout_sec" bash -c "exec 2>/dev/null >/dev/tcp/$target/$port" 2>/dev/null; then
                    alive=1
                fi
            else
                if $nc_cmd "$target" "$port" 2>/dev/null; then
                    alive=1
                fi
            fi

            if [ $alive -eq 1 ]; then
                echo "$port" >> "$open_file"
                echo "OPEN $port" >> "$result_file"
            else
                echo "CLOSED $port" >> "$result_file"
            fi

            if [ "$interval" != "0" ] && [ -n "$interval" ]; then
                sleep "$interval" 2>/dev/null || sleep 1
            fi
        done
    }

    # ---------- 进度显示函数 ----------
    show_progress() {
        local start_time=$(date +%s)
        local last_update=0
        local prev_scanned=0

        while true; do
            if [ -f "$stop_file" ]; then
                break
            fi
            local now=$(date +%s)
            local elapsed=$((now - start_time))

            if [ $((elapsed - last_update)) -ge 2 ] || [ $elapsed -eq 0 ]; then
                local scanned_count=$(wc -l < "$result_file" 2>/dev/null || echo 0)
                local open_count=$(wc -l < "$open_file" 2>/dev/null || echo 0)

                if [ "$scanned_count" -ne "$prev_scanned" ] || [ $elapsed -eq 0 ]; then
                    printf "\r已扫描: %d/%d (%.1f%%) | 开放: %d | 耗时: %d秒" \
                        "$scanned_count" "$total_ports" \
                        $(echo "scale=1; $scanned_count * 100 / $total_ports" | bc 2>/dev/null || echo 0) \
                        "$open_count" "$elapsed"
                    prev_scanned="$scanned_count"
                    last_update=$elapsed
                fi

                if [ "$scanned_count" -ge "$total_ports" ]; then
                    break
                fi
            fi
            sleep 1
        done
    }

    # ---------- 计算任务分配 ----------
    local ports_per_worker=$(( (total_ports + max_workers - 1) / max_workers ))

    # 启动进度显示
    show_progress &
    GLOBAL_PROGRESS_PID=$!

    # 启动端口扫描线程
    local worker_pids=()
    for ((worker=0; worker<max_workers; worker++)); do
        local worker_start=$((start_port + worker * ports_per_worker))
        local worker_end=$((worker_start + ports_per_worker - 1))

        [ $worker_start -gt $end_port ] && break
        [ $worker_end -gt $end_port ] && worker_end=$end_port
        [ $worker_start -gt $worker_end ] && break

        portscan_worker $worker $worker_start $worker_end &
        local worker_pid=$!
        worker_pids+=($worker_pid)
        GLOBAL_WORKER_PIDS+=($worker_pid)
    done

    # ---------- 局部信号捕获 ----------
    local old_trap=$(trap -p INT)
    local interrupted=0
    trap 'interrupted=1; touch "$stop_file" 2>/dev/null' INT

    # ---------- 主线程监控（只检测局部中断标志） ----------
    local cancelled=0
    while true; do
        if [ $interrupted -eq 1 ]; then
            echo ""
            cecho "收到终止信号,正在停止端口扫描..."
            cancelled=1
            break
        fi

        local all_done=1
        for pid in "${worker_pids[@]}"; do
            if kill -0 "$pid" 2>/dev/null; then
                all_done=0
                break
            fi
        done
        if [ $all_done -eq 1 ]; then
            break
        fi

        sleep 0.1
    done

    # 恢复旧 trap
    if [ -n "$old_trap" ]; then
        eval "$old_trap"
    else
        trap - INT
    fi

    for pid in "${worker_pids[@]}"; do
        wait "$pid" 2>/dev/null || true
    done

    if [ $GLOBAL_PROGRESS_PID -ne 0 ] && kill -0 "$GLOBAL_PROGRESS_PID" 2>/dev/null; then
        kill "$GLOBAL_PROGRESS_PID" 2>/dev/null
        wait "$GLOBAL_PROGRESS_PID" 2>/dev/null || true
        GLOBAL_PROGRESS_PID=0
    fi

    echo ""

    # ---------- 统计结果（不变） ----------
    local open_count=0
    [ -f "$open_file" ] && open_count=$(wc -l < "$open_file" 2>/dev/null | tr -d ' ' || echo 0)
    local scanned_count=$(wc -l < "$result_file" 2>/dev/null || echo 0)

    echo ""
    cecho "╔══════════════════════════════════════╗"
    cecho "║          端口扫描统计结果            ║"
    cecho "╠══════════════════════════════════════╣"
    cecho "║ 扫描目标: $target ($ip)"
    cecho "║ 扫描端口: $start_port - $end_port"
    cecho "║ 扫描端口数: $total_ports"
    [ $cancelled -eq 1 ] && cecho "║ 实际扫描: $scanned_count (用户终止)"
    cecho "║ 开放端口: $open_count"
    if [ $scanned_count -gt 0 ]; then
        local rate=$(printf "%.1f" $(echo "scale=1; $open_count * 100 / $scanned_count" | bc 2>/dev/null || echo 0))
        cecho "║ 开放率: $rate%"
    else
        cecho "║ 开放率: 0.0%"
    fi

    if [ $open_count -gt 0 ]; then
        cecho "╠══════════════════════════════════════╣"
        cecho "║           开放端口列表               ║"
        cecho "╠══════════════════════════════════════╣"
        sort -n "$open_file" 2>/dev/null | while read -r port; do
            local service=""
            case "$port" in
                20|21) service="FTP" ;;
                22) service="SSH" ;;
                23) service="Telnet" ;;
                25) service="SMTP" ;;
                53) service="DNS" ;;
                80) service="HTTP" ;;
                443) service="HTTPS" ;;
                3306) service="MySQL" ;;
                3389) service="RDP" ;;
                *) service="" ;;
            esac
            if [ -n "$service" ]; then
                cecho "║  $port/tcp  -  $service"
            else
                cecho "║  $port/tcp"
            fi
        done
    fi
    cecho "╚══════════════════════════════════════╝"

    rm -rf "$tmp_dir" 2>/dev/null || true
    GLOBAL_CMD_RUNNING=0
    GLOBAL_WORKER_PIDS=()
}