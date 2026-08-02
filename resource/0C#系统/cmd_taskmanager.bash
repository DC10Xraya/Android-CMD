#resource/cmd_taskmanager.bash
cmd_taskmanager() {
    err "请收起软键盘, 保持终端全屏 (3s)"
    sleep 1
    err "请收起软键盘, 保持终端全屏 (2s)"
    sleep 1
    err "请收起软键盘, 保持终端全屏 (1s)"
    sleep 1
    cmd_cls_no_title
    cecho "启动中...请保持终端全屏,请勿上拉软键盘"
    # ---- 检查依赖 ----
    if ! command -v top >/dev/null 2>&1; then
        err "错误: 未找到 top 命令, 请安装 busybox 或 procps"
        return 1
    fi
    if ! command -v ps >/dev/null 2>&1; then
        err "错误: 未找到 ps 命令"
        return 1
    fi

    # 检测 ps 支持 -o 选项
    local ps_has_o=0
    if ps -A -o pid,comm,rss 2>/dev/null | head -n1 | grep -q "PID"; then
        ps_has_o=1
    fi

    # ---- 温度传感器探测 ----
    local thermal_base="/sys/class/thermal"
    local cpu_sensor=""
    local gpu_sensor=""
    local battery_sensor=""
    if [ -d "$thermal_base" ]; then
        for zone in "$thermal_base"/thermal_zone*; do
            [ -d "$zone" ] || continue
            local type_file="$zone/type"
            local temp_file="$zone/temp"
            [ -r "$type_file" ] && [ -r "$temp_file" ] || continue
            local sensor_type=$($_CAT "$type_file" 2>/dev/null | tr -d '\n\r')
            case "$sensor_type" in
                cpu-0-0|cpuss-0|cpu-0-1|cpuss-1|cpu-1-0) [ -z "$cpu_sensor" ] && cpu_sensor="$temp_file" ;;
                gpuss-0|gpuss-1|gpu) [ -z "$gpu_sensor" ] && gpu_sensor="$temp_file" ;;
                battery) battery_sensor="$temp_file" ;;
            esac
        done
    fi
    [ -z "$battery_sensor" ] && [ -r "/sys/class/power_supply/battery/temp" ] && battery_sensor="/sys/class/power_supply/battery/temp"

    _get_temp() {
        local path="$1"
        [ -n "$path" ] && [ -r "$path" ] || { echo "N/A"; return; }
        local raw=$($_CAT "$path" 2>/dev/null | tr -d '\n\r')
        [ -z "$raw" ] && { echo "N/A"; return; }
        if [ "$raw" -gt 1000 ] 2>/dev/null; then
            raw=$((raw / 1000))
        fi
        if [ "$raw" -gt 5 ] && [ "$raw" -lt 120 ] 2>/dev/null; then
            echo "${raw}°C"
        else
            echo "N/A"
        fi
    }

    printf "\033[?25l"          # 隐藏光标
    trap 'printf "\033[?25h"; exit' INT TERM EXIT

    local stop=0
    while [ $stop -eq 0 ]; do
        printf "\033[H"

        # ---- 时间 / 运行时间 ----
        local current_time=$($_DATE "+%Y-%m-%d %H:%M:%S")
        local uptime_raw=$(uptime 2>/dev/null | sed 's/.*up \([^,]*\),.*/\1/')
        [ -z "$uptime_raw" ] && uptime_raw="N/A"

        # ---- 获取 top 输出(一次) ----
        local top_output=$(top -n 1 -b 2>/dev/null)
        
        # ---- 解析 Tasks 行 ----
        local tasks_line=$(echo "$top_output" | head -n1)
        local tasks_display=""
        if [[ "$tasks_line" =~ Tasks:[[:space:]]*([0-9]+)[[:space:]]+total,[[:space:]]*([0-9]+)[[:space:]]+running,[[:space:]]*([0-9]+)[[:space:]]+sleeping,[[:space:]]*([0-9]+)[[:space:]]+stopped ]]; then
            local t_total=${BASH_REMATCH[1]}
            local t_running=${BASH_REMATCH[2]}
            local t_sleeping=${BASH_REMATCH[3]}
            local t_stopped=${BASH_REMATCH[4]}
            tasks_display="Tasks: ${t_total} total, ${t_running} running, ${t_sleeping} sleeping, ${t_stopped} stopped"
        elif [[ "$tasks_line" =~ Tasks:[[:space:]]*([0-9]+)[[:space:]]+total,[[:space:]]*([0-9]+)[[:space:]]+running,[[:space:]]*([0-9]+)[[:space:]]+sleeping,[[:space:]]*([0-9]+)[[:space:]]+stopped,[[:space:]]*([0-9]+)[[:space:]]+zombie ]]; then
            local t_total=${BASH_REMATCH[1]}
            local t_running=${BASH_REMATCH[2]}
            local t_sleeping=${BASH_REMATCH[3]}
            local t_stopped=${BASH_REMATCH[4]}
            local t_zombie=${BASH_REMATCH[5]}
            tasks_display="Tasks: ${t_total} total, ${t_running} running, ${t_sleeping} sleeping, ${t_stopped} stopped, ${t_zombie} zombie"
        else
            tasks_display=$(echo "$tasks_line" | sed 's/^[ \t]*//')
        fi

        # 彻底重写 CPU 解析(适配 busybox top 格式)
        local cpu_line=$(echo "$top_output" | grep -E '^[[:space:]]*[0-9]+%cpu|[0-9]+%user|[0-9]+%idle' | head -1)
        local cpu_display="CPU: N/A"
        if [ -n "$cpu_line" ]; then
            local user=0 nice=0 sys=0 idle=0 iowait=0
            # 按空格拆字段
            for field in $cpu_line; do
                # 去掉可能的逗号
                field=$(echo "$field" | tr -d ',')
                case "$field" in
                    *%user)   user=${field%%%*} ;;
                    *%nice)   nice=${field%%%*} ;;
                    *%sys)    sys=${field%%%*} ;;
                    *%idle)   idle=${field%%%*} ;;
                    *%iowait|*%iow) iowait=${field%%%*} ;;
                esac
            done
            # 构造显示
            if [ $idle -gt 0 ] || [ $user -gt 0 ] || [ $sys -gt 0 ]; then
                cpu_display="CPU: ${user}% user, ${nice}% nice, ${sys}% sys, ${idle}% idle, ${iowait}% iowait"
            else
                # 可能全部为零,但至少显示已知值
                cpu_display="CPU: ${user}% user, ${nice}% nice, ${sys}% sys, ${idle}% idle, ${iowait}% iowait"
            fi
        fi

        # ---- 解析 Mem 和 Swap(含补充) ----
        local mem_line=$(echo "$top_output" | grep '^Mem:' | head -1)
        local swap_line=$(echo "$top_output" | grep '^Swap:' | head -1)
        local mem_swap_display=""
        if [ -n "$mem_line" ]; then
            local mem_total=$(echo "$mem_line" | awk '{print $2}')
            local mem_used=$(echo "$mem_line" | awk '{print $4}')
            local mem_free=$(echo "$mem_line" | awk '{print $6}')
            mem_swap_display="Mem: ${mem_total} total, ${mem_used} used, ${mem_free} free"
            if [ -n "$swap_line" ]; then
                local swap_total=$(echo "$swap_line" | awk '{print $2}')
                local swap_used=$(echo "$swap_line" | awk '{print $4}')
                local swap_free=$(echo "$swap_line" | awk '{print $6}')
                mem_swap_display="${mem_swap_display}  Swap: ${swap_total} total, ${swap_used} used, ${swap_free} free"
            else
                # 补充 Swap(从 /proc/meminfo)
                local swap_total_kb=$($_GREP 'SwapTotal' /proc/meminfo 2>/dev/null | awk '{print $2}')
                local swap_free_kb=$($_GREP 'SwapFree' /proc/meminfo 2>/dev/null | awk '{print $2}')
                if [ -n "$swap_total_kb" ] && [ -n "$swap_free_kb" ]; then
                    local swap_used_kb=$((swap_total_kb - swap_free_kb))
                    local swap_total_mb=$((swap_total_kb / 1024))
                    local swap_used_mb=$((swap_used_kb / 1024))
                    mem_swap_display="${mem_swap_display}  Swap: ${swap_used_mb}M / ${swap_total_mb}M"
                fi
            fi
        else
            # 回退(完全从 /proc/meminfo)
            local mem_total_kb=$($_GREP 'MemTotal' /proc/meminfo 2>/dev/null | awk '{print $2}')
            local mem_avail_kb=$($_GREP 'MemAvailable' /proc/meminfo 2>/dev/null | awk '{print $2}')
            if [ -n "$mem_total_kb" ] && [ -n "$mem_avail_kb" ]; then
                local mem_used_kb=$((mem_total_kb - mem_avail_kb))
                local mem_total_mb=$((mem_total_kb / 1024))
                local mem_used_mb=$((mem_used_kb / 1024))
                local mem_percent=$(( (mem_used_kb * 100) / mem_total_kb ))
                mem_swap_display="MEM: ${mem_used_mb}M / ${mem_total_mb}M (${mem_percent}%)"
            else
                mem_swap_display="MEM: 无法读取"
            fi
            # 补充 Swap
            local swap_total_kb=$($_GREP 'SwapTotal' /proc/meminfo 2>/dev/null | awk '{print $2}')
            local swap_free_kb=$($_GREP 'SwapFree' /proc/meminfo 2>/dev/null | awk '{print $2}')
            if [ -n "$swap_total_kb" ] && [ -n "$swap_free_kb" ]; then
                local swap_used_kb=$((swap_total_kb - swap_free_kb))
                local swap_total_mb=$((swap_total_kb / 1024))
                local swap_used_mb=$((swap_used_kb / 1024))
                mem_swap_display="${mem_swap_display}  Swap: ${swap_used_mb}M / ${swap_total_mb}M"
            fi
        fi

        # ---- 温度 ----
        local cpu_temp=$(_get_temp "$cpu_sensor")
        local gpu_temp=$(_get_temp "$gpu_sensor")
        local bat_temp=$(_get_temp "$battery_sensor")

        # ---- 进程列表(用 top 解析,按 RSS 降序,紧凑对齐) ----
        local proc_display=""
        local sorted_lines=""
        local total_cpu_sum=0
        local pid_line=$(echo "$top_output" | grep -n '^[ ]*PID' | head -1 | cut -d: -f1)
        if [ -n "$pid_line" ]; then
            sorted_lines=$(echo "$top_output" | tail -n +$((pid_line+1)) | head -n 50 | awk '{
                if (NF < 8) next;
                res=$6;
                if (res ~ /M$/) { val=res*1024; } 
                else if (res ~ /G$/) { val=res*1048576; } 
                else { val=res; }
                print val, $0
            }' | sort -nr -k1 | head -15 | cut -d' ' -f2-)
            if [ -n "$sorted_lines" ]; then
                proc_display=$(echo "$sorted_lines" | awk '{
                    pid=$1; user=$2; res=$6; state=$8; pcpu=$9; time=$11; cmd=$NF;
                    gsub(/%/,"",pcpu);
                    total += pcpu;
                    if (length(cmd)>12) cmd=substr(cmd,1,12)"..";
                    printf " %-5s %-8s %-14s %5s %4s %-2s %6s\n", pid, user, cmd, res, pcpu"%", state, time
                }' total=0)
                total_cpu_sum=$(echo "$proc_display" | awk '{gsub(/%/,"",$5); sum+=$5} END {printf "%.1f", sum}')
            fi
        fi

        if [ -z "$proc_display" ]; then
            sorted_lines=""
            if [ $ps_has_o -eq 1 ]; then
                proc_display=$(ps -A -o pid,user,comm,rss 2>/dev/null | tail -n +2 | sort -nr -k4 | head -n 15 | awk '{
                    pid=$1; user=$2; cmd=$3; rss=$4;
                    if (rss ~ /^[0-9]+$/ && rss > 0) {
                        printf " %-5s %-8s %-14s %5.0fM\n", pid, user, cmd, rss/1024;
                    } else {
                        printf " %-5s %-8s %-14s %5s\n", pid, user, cmd, "N/A";
                    }
                }')
            else
                proc_display=$(ps -A 2>/dev/null | tail -n +2 | awk '{
                    user=$1; pid=$2; rss=$5; cmd=$NF;
                    if (rss ~ /^[0-9]+$/ && rss > 0) {
                        printf "%s %d %s %d\n", user, pid, cmd, rss;
                    }
                }' | sort -nr -k4 | head -n 15 | awk '{
                    printf " %-5s %-8s %-14s %5.0fM\n", $2, $1, $3, $4/1024;
                }')
            fi
        fi

        if [ -z "$proc_display" ]; then
            proc_display=" 无法获取进程列表"
        fi

        # ---- 输出 ----
        cecho -b "------------任务管理器(BASH,by DC10Xray)------------"
        cecho "时间: $current_time    系统运行时间: $uptime_raw"
        cecho "$CMD_delimiter"
        cecho "$tasks_display"
        cecho "$mem_swap_display"
        cecho "$cpu_display"
        if [ -n "$sorted_lines" ] && [ "$total_cpu_sum" != "0" ] && [ "$total_cpu_sum" != "" ]; then
            cecho "进程总CPU占用率: ${total_cpu_sum}%"
        fi


        cecho "CPU温度: $cpu_temp    GPU温度: $gpu_temp    电池温度: $bat_temp"
        cecho "$CMD_delimiter"
        if [ -n "$sorted_lines" ]; then
            cecho -b -c 40 -cb "#FAF9F6" "进程列表 (按RSS降序)"
            printf " %-5s %-8s %-14s %5s %4s %-2s %6s\n" "PID" "USER" "TASK" "RSS" "%CPU" "S" "TIME+"
        else
            cecho -b -c 40 -cb "#FAF9F6" "进程列表 (按RSS降序, 仅4列)"
            printf " %-5s %-8s %-14s %5s\n" "PID" "USER" "TASK" "RSS"
        fi
        echo "$proc_display"
        local count=$(echo "$proc_display" | wc -l)
        if [ $count -lt 15 ]; then
            for i in $(seq $((count+1)) 15); do echo "  "; done
        fi
        cecho "$CMD_delimiter"
        cecho "按ESC退出, ↓刷新(如果显示混乱)"
        err "始终保持终端全屏,请勿上拉软键盘,这会导致再次下拉软键盘显示混乱"
        err "如果显示混乱,请按下方向键(↓)刷新"

        # ---- 按键检测 ----
        local key=""
        read -t 0.1 -n1 key 2>/dev/null
        if [ "$key" = $'\033' ]; then
            read -t 0.01 -n1 key2 2>/dev/null
            if [ "$key2" = "[" ]; then
                read -t 0.01 -n1 key3 2>/dev/null
                if [ "$key3" = "B" ]; then
                    cmd_cls_no_title
                    cecho "刷新中...请保持终端全屏,请勿上拉软键盘"
                    sleep 0.5
                    continue
                fi
            fi
            stop=1
            break
        fi

        sleep 0.5
    done

    printf "\033[?25h"
    cmd_cls
}