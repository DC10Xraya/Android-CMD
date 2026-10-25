cmd_taskmanager() {
    if ! command -v top >/dev/null 2>&1; then
        err "错误: 未找到 top 命令, 请安装 busybox 或 procps"
        return 1
    fi

    cmd_cls -n
    cecho "收起软键盘(1.5s)"
    sleep 1.5
    cmd_cls -n
    cecho "启动中..."

    local ps_has_o=0
    if ps -A -o pid,comm,rss 2>/dev/null | head -n1 | grep -q "PID"; then
        ps_has_o=1
    fi

    # 核心数
    local _tm_cores=0 _cl
    while IFS= read -r _cl; do
        [[ "$_cl" == processor* ]] && _tm_cores=$((_tm_cores + 1))
    done < /proc/cpuinfo 2>/dev/null
    [ "$_tm_cores" -le 0 ] && _tm_cores=1

    # 温度传感器
    local thermal_base="/sys/class/thermal"
    local cpu_sensor="" gpu_sensor="" battery_sensor=""
    if [ -d "$thermal_base" ]; then
        local zone type_file temp_file sensor_type
        for zone in "$thermal_base"/thermal_zone*; do
            [ -d "$zone" ] || continue
            type_file="$zone/type"; temp_file="$zone/temp"
            [ -r "$type_file" ] && [ -r "$temp_file" ] || continue
            sensor_type=""
            IFS= read -r sensor_type < "$type_file" 2>/dev/null
            sensor_type="${sensor_type%$'\r'}"
            case "$sensor_type" in
                cpu-0-0|cpuss-0|cpu-0-1|cpuss-1|cpu-1-0) [ -z "$cpu_sensor" ] && cpu_sensor="$temp_file" ;;
                gpuss-0|gpuss-1|gpu) [ -z "$gpu_sensor" ] && gpu_sensor="$temp_file" ;;
                battery) battery_sensor="$temp_file" ;;
            esac
        done
    fi
    [ -z "$battery_sensor" ] && [ -r "/sys/class/power_supply/battery/temp" ] \
        && battery_sensor="/sys/class/power_supply/battery/temp"

    _tm_read_temp() {
        local __var="$1" __path="$2"
        local __raw=""
        if [ -n "$__path" ] && [ -r "$__path" ]; then
            IFS= read -r __raw < "$__path" 2>/dev/null
            __raw="${__raw%$'\r'}"
        fi
        if [ -z "$__raw" ] || ! [[ "$__raw" =~ ^[0-9]+$ ]]; then
            printf -v "$__var" 'N/A'; return
        fi
        local __c
        if [ "$__raw" -gt 1000 ]; then __c=$((__raw / 1000)); else __c="$__raw"; fi
        if [ "$__c" -gt 5 ] && [ "$__c" -lt 120 ]; then
            printf -v "$__var" '%s°C' "$__c"
        else
            printf -v "$__var" 'N/A'
        fi
    }

    _tm_line() {
        printf '\033[K'
        cecho "$@"
    }

    local _tm_has_pT=0 _tm_test=""
    if printf -v _tm_test '%(%s)T' -1 2>/dev/null && [[ "$_tm_test" =~ ^[0-9]+$ ]]; then
        _tm_has_pT=1
    fi

    printf '\033[?25l'
    local old_int_trap=$(trap -p INT)
    local stop=0
    trap 'stop=1' INT
    trap 'printf "\033[?25h"' EXIT

    local start_time=""
    if [ $_tm_has_pT -eq 1 ]; then
        printf -v start_time '%(%s)T' -1
    else
        start_time=$($_DATE +%s)
    fi

    # 滚动偏移（跨循环保持）
    local _tm_scroll=0

    # 首次全清一次，之后只归位覆盖
    printf '\033[3J\033[2J\033[H'

    while [ $stop -eq 0 ]; do
        printf '\033[H'

        # 时间
        local current_time="" current_time_stamp=""
        if [ $_tm_has_pT -eq 1 ]; then
            printf -v current_time '%(%Y-%m-%d %H:%M:%S)T' -1
            printf -v current_time_stamp '%(%s)T' -1
        else
            current_time=$($_DATE "+%Y-%m-%d %H:%M:%S")
            current_time_stamp=$($_DATE +%s)
        fi

        # uptime 汉化
        local uptime_display="N/A"
        local up_raw=""
        up_raw=$($_UPTIME 2>/dev/null)
        if [ -n "$up_raw" ]; then
            local up_str=""
            if [[ "$up_raw" =~ up[[:space:]]+(.+),[[:space:]]+[0-9]+[[:space:]]+users?, ]]; then
                up_str="${BASH_REMATCH[1]}"
            elif [[ "$up_raw" =~ up[[:space:]]+(.+),[[:space:]]+load ]]; then
                up_str="${BASH_REMATCH[1]}"
            fi
            if [ -n "$up_str" ]; then
                if type -t _translate_uptime >/dev/null 2>&1; then
                    uptime_display=$(_translate_uptime "$up_str")
                else
                    uptime_display="$up_str"
                fi
            fi
        fi

        # 监测时长
        local elapsed=$(( current_time_stamp - start_time ))
        local elapsed_formatted
        if [ $elapsed -lt 60 ]; then
            elapsed_formatted="${elapsed}s"
        elif [ $elapsed -lt 3600 ]; then
            elapsed_formatted="$((elapsed / 60))m$((elapsed % 60))s"
        else
            elapsed_formatted="$((elapsed / 3600))h$(((elapsed % 3600) / 60))m$((elapsed % 60))s"
        fi

        # top
        local top_output=""
        top_output=$(top -n 1 -b 2>/dev/null)

        # awk 解析：输出全部进程（不截断）
        local parsed=""
        parsed=$($_AWK '
            BEGIN { n = 0; cpu_line = ""; pid_line = 0 }
            /^[[:space:]]*Tasks:/ && cpu_line == "" { print "_TASKS_:" $0; next }
            /%user|%usr|%sys|%idle/ && !/Tasks:/ && !/Mem/ && !/Swap/ && cpu_line == "" {
                cpu_line = $0; next
            }
            /^[[:space:]]*PID[[:space:]]/ { pid_line = NR; next }
            (pid_line == 0 || NR > pid_line) && $1 ~ /^[0-9]+$/ {
                res = $6
                if (res == "" || res == "-") { res_val = 0; res = "0" }
                else if (res ~ /G$/) res_val = (res + 0) * 1048576
                else if (res ~ /M$/) res_val = (res + 0) * 1024
                else res_val = res + 0
                n++
                pids[n]=$1; users[n]=$2; cmds[n]=$NF
                states[n]=$8; pcpuss[n]=$9; times[n]=$11
                res_strs[n]=res; rss_vals[n]=res_val
            }
            END {
                if (cpu_line != "") print "_CPU_:" cpu_line
                for (i = 2; i <= n; i++) {
                    key = rss_vals[i]
                    kp=pids[i]; ku=users[i]; kc=cmds[i]
                    ks=states[i]; kcpu=pcpuss[i]; kt=times[i]; kr=res_strs[i]
                    j = i - 1
                    while (j >= 1 && rss_vals[j] < key) {
                        rss_vals[j+1]=rss_vals[j]
                        pids[j+1]=pids[j]; users[j+1]=users[j]; cmds[j+1]=cmds[j]
                        states[j+1]=states[j]; pcpuss[j+1]=pcpuss[j]; times[j+1]=times[j]
                        res_strs[j+1]=res_strs[j]
                        j--
                    }
                    rss_vals[j+1]=key
                    pids[j+1]=kp; users[j+1]=ku; cmds[j+1]=kc
                    states[j+1]=ks; pcpuss[j+1]=kcpu; times[j+1]=kt
                    res_strs[j+1]=kr
                }
                total = 0
                for (i = 1; i <= n; i++) {
                    c = cmds[i]
                    if (length(c) > 12) c = substr(c, 1, 12) ".."
                    p = pcpuss[i]; gsub(/%/, "", p)
                    total += p + 0
                    printf "_PROC_: %-5s %-8s %-14s %5s %4s %-2s %6s\n", \
                        pids[i], users[i], c, res_strs[i], pcpuss[i], states[i], times[i]
                }
                printf "_TOTAL_:%.1f\n", total
            }
        ' <<< "$top_output")

        # 拆包
        local -a _proc_lines=()
        local tasks_display="" cpu_line="" total_cpu=""
        local _pl
        while IFS= read -r _pl; do
            case "$_pl" in
                _TASKS_:*) tasks_display="${_pl#_TASKS_:}" ;;
                _CPU_:*)   cpu_line="${_pl#_CPU_:}" ;;
                _PROC_:*)  _proc_lines+=("${_pl#_PROC_:}") ;;
                _TOTAL_:*) total_cpu="${_pl#_TOTAL_:}" ;;
            esac
        done <<< "$parsed"

        # top 完全失败时 ps 回退
        if [ ${#_proc_lines[@]} -eq 0 ] && [ -z "$top_output" ] && [ $ps_has_o -eq 1 ]; then
            local ps_out=""
            ps_out=$(ps -A -o pid,user,comm,rss 2>/dev/null)
            if [ -n "$ps_out" ]; then
                local _n=0
                local -a _pids=() _users=() _cmds=() _rsss=()
                local _pl2
                while IFS= read -r _pl2; do
                    [[ "$_pl2" =~ ^[[:space:]]*([0-9]+)[[:space:]]+([^[:space:]]+)[[:space:]]+([^[:space:]]+)[[:space:]]+([0-9]+) ]] || continue
                    _pids+=("${BASH_REMATCH[1]}"); _users+=("${BASH_REMATCH[2]}")
                    _cmds+=("${BASH_REMATCH[3]}"); _rsss+=("${BASH_REMATCH[4]}")
                    _n=$((_n + 1))
                done <<< "$ps_out"
                local i j kp ku kc kr
                for ((i=1; i<_n; i++)); do
                    kr=${_rsss[i]}; kp=${_pids[i]}; ku=${_users[i]}; kc=${_cmds[i]}
                    j=$((i - 1))
                    while [ $j -ge 0 ] && [ "${_rsss[j]}" -lt "$kr" ]; do
                        _rsss[j+1]=${_rsss[j]}
                        _pids[j+1]=${_pids[j]}; _users[j+1]=${_users[j]}; _cmds[j+1]=${_cmds[j]}
                        j=$((j - 1))
                    done
                    _rsss[j+1]=$kr; _pids[j+1]=$kp; _users[j+1]=$ku; _cmds[j+1]=$kc
                done
                local k _line
                for ((k=0; k<_n; k++)); do
                    local _c="${_cmds[k]}"
                    [ ${#_c} -gt 12 ] && _c="${_c:0:12}.."
                    printf -v _line " %-5s %-8s %-14s %5s" \
                        "${_pids[k]}" "${_users[k]}" "$_c" "$((_rsss[k] / 1024))M"
                    _proc_lines+=("$_line")
                done
            fi
        fi

        # ---- 滚动边界计算 ----
        local _proc_total=${#_proc_lines[@]}
        local _max_offset=$(( _proc_total - 15 ))
        [ $_max_offset -lt 0 ] && _max_offset=0
        # 修正越界的 scroll（进程数变少时）
        [ $_tm_scroll -gt $_max_offset ] && _tm_scroll=$_max_offset
        [ $_tm_scroll -lt 0 ] && _tm_scroll=0

        local _end=$(( _tm_scroll + 15 ))
        [ $_end -gt $_proc_total ] && _end=$_proc_total

        local _range_info=""
        if [ $_proc_total -gt 15 ]; then
            _range_info=" [$((_tm_scroll+1))-$_end/$_proc_total]"
        fi

        # Tasks 汉化
        if [ -z "$tasks_display" ]; then
            local _t_total=0 _t_running=0 _t_sleeping=0 _t_stopped=0 _t_zombie=0
            local _stat_lines=""
            _stat_lines=$(ps -A -o stat= 2>/dev/null)
            if [ -n "$_stat_lines" ]; then
                local _line
                while IFS= read -r _line; do
                    [ -z "$_line" ] && continue
                    _t_total=$((_t_total + 1))
                    case "${_line:0:1}" in
                        R) _t_running=$((_t_running + 1)) ;;
                        S|D) _t_sleeping=$((_t_sleeping + 1)) ;;
                        T) _t_stopped=$((_t_stopped + 1)) ;;
                        Z) _t_zombie=$((_t_zombie + 1)) ;;
                    esac
                done <<< "$_stat_lines"
                [ $_t_total -gt 0 ] && tasks_display="任务: ${_t_total} 总, ${_t_running} 运行, ${_t_sleeping} 睡眠, ${_t_stopped} 停止, ${_t_zombie} 僵尸"
            fi
            [ -z "$tasks_display" ] && tasks_display="任务: 无法读取"
        else
            if [[ "$tasks_display" =~ Tasks:[[:space:]]*([0-9]+)[[:space:]]+total,[[:space:]]*([0-9]+)[[:space:]]+running,[[:space:]]*([0-9]+)[[:space:]]+sleeping,[[:space:]]*([0-9]+)[[:space:]]+stopped,[[:space:]]*([0-9]+)[[:space:]]+zombie ]]; then
                tasks_display="任务: ${BASH_REMATCH[1]} 总, ${BASH_REMATCH[2]} 运行, ${BASH_REMATCH[3]} 睡眠, ${BASH_REMATCH[4]} 停止, ${BASH_REMATCH[5]} 僵尸"
            elif [[ "$tasks_display" =~ Tasks:[[:space:]]*([0-9]+)[[:space:]]+total,[[:space:]]*([0-9]+)[[:space:]]+running,[[:space:]]*([0-9]+)[[:space:]]+sleeping,[[:space:]]*([0-9]+)[[:space:]]+stopped ]]; then
                tasks_display="任务: ${BASH_REMATCH[1]} 总, ${BASH_REMATCH[2]} 运行, ${BASH_REMATCH[3]} 睡眠, ${BASH_REMATCH[4]} 停止"
            else
                tasks_display="${tasks_display#"${tasks_display%%[![:space:]]*}"}"
            fi
        fi

        # CPU（多核除以核心数）
        local cpu_display="CPU: N/A"
        if [ -n "$cpu_line" ]; then
            local user=0 nice=0 sys=0 idle=0 iowait=0
            local _f
            for _f in $cpu_line; do
                _f="${_f//,/}"
                case "$_f" in
                    *%user|*%usr) user="${_f%%\%*}" ;;
                    *%nice) nice="${_f%%\%*}" ;;
                    *%sys)  sys="${_f%%\%*}" ;;
                    *%idle) idle="${_f%%\%*}" ;;
                    *%iow*) iowait="${_f%%\%*}" ;;
                esac
            done
            if [ "$_tm_cores" -gt 1 ]; then
                cpu_display="CPU: $((user / _tm_cores))% 用户  $((sys / _tm_cores))% 系统  $((idle / _tm_cores))% 空闲  (${_tm_cores}核)"
            else
                cpu_display="CPU: ${user}% 用户  ${sys}% 系统  ${idle}% 空闲"
            fi
        fi

        # Mem/Swap
        local mem_display="" swap_display=""
        local _mem_total=0 _mem_avail=0 _mem_free=0 _buf=0 _cache=0 _swap_total=0 _swap_free=0
        local _k _v _rest
        while IFS=': ' read -r _k _v _rest; do
            case "$_k" in
                MemTotal)     _mem_total=${_v:-0} ;;
                MemAvailable) _mem_avail=${_v:-0} ;;
                MemFree)      _mem_free=${_v:-0} ;;
                Buffers)      _buf=${_v:-0} ;;
                Cached)       _cache=${_v:-0} ;;
                SwapTotal)    _swap_total=${_v:-0} ;;
                SwapFree)     _swap_free=${_v:-0} ;;
            esac
        done < /proc/meminfo 2>/dev/null
        if [ "$_mem_avail" -eq 0 ] 2>/dev/null && [ "$_mem_total" -gt 0 ] 2>/dev/null; then
            _mem_avail=$((_mem_free + _buf + _cache))
        fi
        if [ "$_mem_total" -gt 0 ] 2>/dev/null; then
            local _used=$((_mem_total - _mem_avail))
            mem_display="内存: 已用 $((_used / 1024))M / 总共 $((_mem_total / 1024))M ($((_used * 100 / _mem_total))%)"
        else
            mem_display="内存: 无法读取"
        fi
        if [ "$_swap_total" -gt 0 ] 2>/dev/null; then
            swap_display="Swap: 已用 $(((_swap_total - _swap_free) / 1024))M / 总共 $((_swap_total / 1024))M"
        else
            swap_display="Swap: 未启用"
        fi

        # 温度
        local cpu_temp="" gpu_temp="" bat_temp=""
        _tm_read_temp cpu_temp "$cpu_sensor"
        _tm_read_temp gpu_temp "$gpu_sensor"
        _tm_read_temp bat_temp "$battery_sensor"

        # === 覆盖式绘制（固定 30 行） ===
        _tm_line -b "------------任务管理器(BASH,by DC10Xray)------------"
        _tm_line "时间: $current_time  监测: $elapsed_formatted  运行: $uptime_display"
        _tm_line "$CMD_delimiter"
        _tm_line "$tasks_display"
        _tm_line "$mem_display"
        _tm_line "$swap_display"
        _tm_line "$cpu_display"

        if [ -n "$total_cpu" ] && [ "$total_cpu" != "0.0" ]; then
            _tm_line "进程总CPU占用率: ${total_cpu}%"
        else
            printf '\033[K\n'
        fi

        _tm_line "CPU温度: $cpu_temp    GPU温度: $gpu_temp    电池温度: $bat_temp"
        _tm_line "$CMD_delimiter"

        if [ $_proc_total -gt 0 ]; then
            _tm_line -b -c 93 "进程列表 (按RSS降序)${_range_info}"
            printf '\033[K %-5s %-8s %-14s %5s %4s %-2s %6s\n' "PID" "USER" "TASK" "RSS" "%CPU" "S" "TIME+"
        else
            _tm_line -b -c 93 "进程列表 (按RSS降序, 仅4列)${_range_info}"
            printf '\033[K %-5s %-8s %-14s %5s\n' "PID" "USER" "TASK" "RSS"
        fi

        local _shown=0 _i2
        for ((_i2=_tm_scroll; _i2<_end; _i2++)); do
            printf '\033[K%s\n' "${_proc_lines[_i2]}"
            _shown=$((_shown + 1))
        done
        for ((_i2=_shown+1; _i2<=15; _i2++)); do
            printf '\033[K\n'
        done

        _tm_line "$CMD_delimiter"
        _tm_line "↑↓滚动进程, ←刷新, ESC退出"
        _tm_line -c 31 "如果显示错乱, 按任一方向键重绘"

        # ---- 按键处理 ----
        local key=""
        if read -t 0.3 -n1 key 2>/dev/null; then
            if [ "$key" = $'\033' ]; then
                local key2="" key3=""
                read -t 0.01 -n1 key2 2>/dev/null
                if [ -z "$key2" ]; then
                    # 单独的 ESC → 退出
                    stop=1
                    break
                fi
                if [ "$key2" = "[" ]; then
                    read -t 0.01 -n1 key3 2>/dev/null
                    case "$key3" in
                        A)  # ↑ 上滚
                            [ $_tm_scroll -gt 0 ] && _tm_scroll=$((_tm_scroll - 1))
                            continue ;;
                        B)  # ↓ 下滚
                            [ $_tm_scroll -lt $_max_offset ] && _tm_scroll=$((_tm_scroll + 1))
                            continue ;;
                        D)  # ← 刷新
                            continue ;;
                        *)  # 其他 CSI 序列，忽略并重绘
                            continue ;;
                    esac
                fi
                # 其他 ESC 序列，忽略
                continue
            fi
        fi
    done

    printf '\033[?25h'
    eval "$old_int_trap" 2>/dev/null || trap - INT
    trap - EXIT
    unset -f _tm_line _tm_read_temp 2>/dev/null
    cmd_cls
}