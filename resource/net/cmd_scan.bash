#resource/cmd_scan.bash
cmd_scan() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -eq 0 ]; then
    cecho -b "用法: SCAN [-t 线程数] [-W 超时(s)] [-i 间隔(s)] [-s 包大小(字节)] <IP前缀> [起始] [结束]"
    cecho "示例: SCAN -t 8 -s 64 127.0.0 .1 .255"
    return 0
fi

    local prefix start end timeout_sec=1 interval=0.2 max_workers=8 packet_size=""
    local parsed_args=()

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
            -s)
                if [ $# -ge 2 ] && echo "$2" | grep -qE '^[0-9]+$' && [ "$2" -ge 1 ] && [ "$2" -le 65507 ]; then
                    packet_size="$2"
                    shift 2
                else
                    err "选项 -s 需要指定有效包大小(1-65507之间的正整数)"
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
            -*)
                err "未知选项: $1"
                return 1
                ;;
            *)
                parsed_args+=("$1")
                shift
                ;;
        esac
    done

    # 解析IP范围参数（不变）
    if [ ${#parsed_args[@]} -eq 1 ]; then
        prefix="${parsed_args[0]}"
        start=1
        end=254
    elif [ ${#parsed_args[@]} -eq 2 ]; then
        prefix="${parsed_args[0]}"
        start=1
        end="${parsed_args[1]}"
    elif [ ${#parsed_args[@]} -eq 3 ]; then
        if [ "${parsed_args[1]#.}" != "${parsed_args[1]}" ]; then
            prefix="${parsed_args[0]}."
            start="${parsed_args[1]#.}"
            end="${parsed_args[2]}"
        else
            prefix="${parsed_args[0]}"
            start="${parsed_args[1]}"
            end="${parsed_args[2]}"
        fi
    else
        err "无效参数用法: SCAN [-t 线程数] [-W 超时(s)] [-i 间隔(s)] [-s 包大小(字节)] <IP前缀> [起始] [结束]"
        err "示例: SCAN -t 4 -s 64 192.168.1 1 254"
        return
    fi

    start=$(echo "$start" | sed 's/[^0-9]//g')
    end=$(echo "$end" | sed 's/[^0-9]//g')
    [ -z "$start" ] && start=1
    [ -z "$end" ] && end=254

    if [ "$start" -gt "$end" ]; then
        err "起始地址不能大于结束地址"
        return
    fi

    case "$prefix" in
        *.) ;;
        *) prefix="${prefix}." ;;
    esac

    local total_ips=$((end - start + 1))

    local packet_info=""
    [ -n "$packet_size" ] && packet_info=",包大小=${packet_size}字节"

    cecho "已设置参数: 线程数=${max_workers},超时=${timeout_sec}秒,间隔=${interval}秒${packet_info}"
    sleep 0.2
    cecho "开始扫描 $prefix$start - $prefix$end (按Ctrl+C终止扫描)"
    echo ""

    # ---------- 创建临时目录和文件 ----------
    local tmp_dir="${TMP_DIR:-/storage/emulated/0/tmp}/scan_$$"
    if ! mkdir -p "$tmp_dir" 2>/dev/null; then
        err "无法创建临时目录: $tmp_dir"
        return 1
    fi

    local alive_file="$tmp_dir/alive.txt"
    local result_file="$tmp_dir/results.txt"
    local stop_file="$tmp_dir/stop"

    rm -f "$alive_file" "$result_file" "$stop_file" 2>/dev/null
    touch "$alive_file"
    touch "$result_file"

    # ---------- 确定ping命令的超时参数 ----------
    local ping_timeout_arg=""
    if ping -W 1 -c 1 127.0.0.1 >/dev/null 2>&1; then
        ping_timeout_arg="-W $timeout_sec"
    elif ping -w 1 -c 1 127.0.0.1 >/dev/null 2>&1; then
        ping_timeout_arg="-w $timeout_sec"
    fi

    # ---------- 扫描函数 ----------
    scan_worker() {
        local worker_id="$1"
        local worker_start="$2"
        local worker_end="$3"

        local ping_base="ping -c 1"
        [ -n "$ping_timeout_arg" ] && ping_base="$ping_base $ping_timeout_arg"
        [ -n "$packet_size" ] && ping_base="$ping_base -s $packet_size"

        for i in $(seq $worker_start $worker_end); do
            if [ -f "$stop_file" ]; then
                break
            fi
            local ip="${prefix}${i}"
            if $ping_base "$ip" >/dev/null 2>&1; then
                echo "$ip" >> "$alive_file"
                echo "ALIVE $ip" >> "$result_file"
            else
                echo "DEAD $ip" >> "$result_file"
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
                local alive_count=$(wc -l < "$alive_file" 2>/dev/null || echo 0)

                if [ "$scanned_count" -ne "$prev_scanned" ] || [ $elapsed -eq 0 ]; then
                    printf "\r已扫描: %d/%d (%.1f%%) | 存活: %d | 耗时: %d秒" \
                        "$scanned_count" "$total_ips" \
                        $(echo "scale=1; $scanned_count * 100 / $total_ips" | bc 2>/dev/null || echo 0) \
                        "$alive_count" "$elapsed"
                    prev_scanned="$scanned_count"
                    last_update=$elapsed
                fi

                if [ "$scanned_count" -ge "$total_ips" ]; then
                    break
                fi
            fi
            sleep 1
        done
    }

    # ---------- 计算任务分配 ----------
    local ips_per_worker=$(( (total_ips + max_workers - 1) / max_workers ))

    # 启动进度显示
    local progress_pid=0
    show_progress &
    progress_pid=$!

    # 启动扫描线程
    local worker_pids=()
    for ((worker=0; worker<max_workers; worker++)); do
        local worker_start=$((start + worker * ips_per_worker))
        local worker_end=$((worker_start + ips_per_worker - 1))

        [ $worker_start -gt $end ] && break
        [ $worker_end -gt $end ] && worker_end=$end
        [ $worker_start -gt $worker_end ] && break

        scan_worker $worker $worker_start $worker_end &
        local worker_pid=$!
        worker_pids+=($worker_pid)
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
            cecho "收到终止信号,正在停止扫描..."
            cancelled=1
            break
        fi

        # 检查工作线程是否已完成
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

    # 等待所有扫描线程完成
    for pid in "${worker_pids[@]}"; do
        wait "$pid" 2>/dev/null || true
    done

    # 停止进度显示
    if [ $progress_pid -ne 0 ] && kill -0 "$progress_pid" 2>/dev/null; then
        kill "$progress_pid" 2>/dev/null
        wait "$progress_pid" 2>/dev/null || true
        progress_pid=0
    fi

    echo ""

    # ---------- 统计结果（不变） ----------
    local alive_count=0
    [ -f "$alive_file" ] && alive_count=$(wc -l < "$alive_file" 2>/dev/null | tr -d ' ' || echo 0)
    local scanned_count=$(wc -l < "$result_file" 2>/dev/null || echo 0)

    echo ""
    cecho "╔══════════════════════════════════════╗"
    cecho "║            扫描统计结果              ║"
    cecho "╠══════════════════════════════════════╣"
    cecho "║ 扫描范围: $prefix$start - $prefix$end"
    cecho "║ 扫描IP数: $total_ips"
    [ $cancelled -eq 1 ] && cecho "║ 实际扫描: $scanned_count (用户终止)"
    cecho "║ 存活主机: $alive_count"
    if [ $scanned_count -gt 0 ]; then
        local rate=$(printf "%.1f" $(echo "scale=1; $alive_count * 100 / $scanned_count" | bc 2>/dev/null || echo 0))
        cecho "║ 在线率: $rate%"
    else
        cecho "║ 在线率: 0.0%"
    fi

    if [ $alive_count -gt 0 ]; then
        cecho "╠══════════════════════════════════════╣"
        cecho "║           存活主机列表               ║"
        cecho "╠══════════════════════════════════════╣"
        sort -t . -k 1,1n -k 2,2n -k 3,3n -k 4,4n "$alive_file" 2>/dev/null | \
        while read -r ip; do
            cecho "║  $ip"
        done
    fi
    cecho "╚══════════════════════════════════════╝"

    rm -rf "$tmp_dir" 2>/dev/null || true
    return 0
}