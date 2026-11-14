cmd_systeminfo() {
    # ---- 变量集中声明 ----
    local hostname osver sdkver manuf model kernel
    local cpu_model cpu_cores freq_info
    local mem_total_kb mem_free_kb mem_buffers_kb mem_cached_kb mem_avail_kb
    local swap_total_kb swap_free_kb
    local cpu_temp gpu_temp bat_temp uptime_raw
    local _line _val _k _v _rest _cpuinfo _freq _core _mhz _dec _cpu_dir _zone _sensor_type
    local _soc _hw _props

    # ---------- 主机名：先判可读, 避免 Permission denied 泄漏到 stderr ----------
    hostname=""
    if [ -r /proc/sys/kernel/hostname ]; then
        read -r hostname < /proc/sys/kernel/hostname 2>/dev/null
    fi
    if [ -z "$hostname" ]; then
        hostname=$(getprop net.hostname 2>/dev/null)
    fi
    [ -z "$hostname" ] && hostname=$($_HOSTNAME 2>/dev/null || echo 'unknown')

    kernel=$($_UNAME -r 2>/dev/null || echo 'unknown')

    # ---------- 系统属性：一次 getprop, 纯 shell 解析(含 SOC 回退) ----------
    osver='?' sdkver='?' manuf='?' model='?'
    _soc="" _hw=""
    if _props=$(getprop 2>/dev/null) && [ -n "$_props" ]; then
        while IFS= read -r _line; do
            case "$_line" in
                '[ro.build.version.release]: '*)
                    _val=${_line#*]: [}; osver=${_val%]};;
                '[ro.build.version.sdk]: '*)
                    _val=${_line#*]: [}; sdkver=${_val%]};;
                '[ro.product.manufacturer]: '*)
                    _val=${_line#*]: [}; manuf=${_val%]};;
                '[ro.product.model]: '*)
                    _val=${_line#*]: [}; model=${_val%]};;
                '[ro.soc.model]: '*)
                    [ -z "$_soc" ] && { _val=${_line#*]: [}; _soc=${_val%]}; };;
                '[ro.board.platform]: '*)
                    [ -z "$_soc" ] && { _val=${_line#*]: [}; _soc=${_val%]}; };;
                '[ro.hardware]: '*)
                    [ -z "$_hw" ] && { _val=${_line#*]: [}; _hw=${_val%]}; };;
            esac
        done <<< "$_props"
    fi

    # ---------- CPU 型号 / 核心数：一次 awk 解析 /proc/cpuinfo ----------
    _cpuinfo=$(awk '
        /^[ \t]*processor[ \t]*:/ { cores++ }
        /^[ \t]*(Processor|Hardware|model name|chip)[ \t]*:/ {
            if (!got) {
                sub(/^[^:]*:[ \t]*/, ""); sub(/[ \t\r]+$/, "")
                model = $0; got = 1
            }
        }
        END { printf "%s|%d\n", (got ? model : ""), cores + 0 }
    ' /proc/cpuinfo 2>/dev/null)
    cpu_model=${_cpuinfo%|*}
    cpu_cores=${_cpuinfo##*|}
    # 回退链：cpuinfo 没型号 → SOC → board.platform → hardware
    if [ -z "$cpu_model" ]; then
        cpu_model=${_soc:-${_hw:-}}
    fi
    [ -z "$cpu_model" ] && cpu_model="unknown"
    [ -z "$cpu_cores" ] && cpu_cores="未知"

    # ---------- 各核心频率：直接 read, 无 fork ----------
    freq_info=""
    for _cpu_dir in /sys/devices/system/cpu/cpu[0-9]*/cpufreq; do
        [ -r "$_cpu_dir/scaling_cur_freq" ] || continue
        read -r _freq < "$_cpu_dir/scaling_cur_freq" 2>/dev/null || continue
        [ -n "$_freq" ] || continue
        _core=${_cpu_dir%/cpufreq}; _core=${_core##*/}
        _mhz=$((_freq / 1000))
        _dec=$(( (_freq % 1000) / 100 ))
        freq_info="${freq_info}${_core}: ${_mhz}.${_dec} MHz  "
    done
    [ -z "$freq_info" ] && freq_info="无法获取频率"

    # ---------- 内存信息：一次遍历 /proc/meminfo ----------
    mem_total_kb="" mem_free_kb="" mem_buffers_kb="" mem_cached_kb=""
    mem_avail_kb="" swap_total_kb="" swap_free_kb=""
    while read -r _k _v _rest; do
        case "$_k" in
            MemTotal:)     mem_total_kb=$_v;;
            MemFree:)      mem_free_kb=$_v;;
            Buffers:)      mem_buffers_kb=$_v;;
            Cached:)       mem_cached_kb=$_v;;
            MemAvailable:) mem_avail_kb=$_v;;
            SwapTotal:)    swap_total_kb=$_v;;
            SwapFree:)     swap_free_kb=$_v;;
        esac
    done < /proc/meminfo

    mem_total_kb=${mem_total_kb:-0}
    mem_free_kb=${mem_free_kb:-0}
    mem_buffers_kb=${mem_buffers_kb:-0}
    mem_cached_kb=${mem_cached_kb:-0}
    mem_avail_kb=${mem_avail_kb:-$mem_free_kb}
    swap_total_kb=${swap_total_kb:-0}
    swap_free_kb=${swap_free_kb:-0}

    local mem_used_kb=$((mem_total_kb - mem_avail_kb))
    [ $mem_used_kb -lt 0 ] && mem_used_kb=0
    local mem_percent=$(( (mem_used_kb * 100) / (mem_total_kb ? mem_total_kb : 1) ))
    local swap_used_kb=$((swap_total_kb - swap_free_kb))
    [ $swap_used_kb -lt 0 ] && swap_used_kb=0
    local swap_percent=$(( (swap_used_kb * 100) / (swap_total_kb ? swap_total_kb : 1) ))

    # ---------- 温度传感器探测 ----------
    local thermal_base="/sys/class/thermal"
    local cpu_sensor="" gpu_sensor="" battery_sensor=""
    if [ -d "$thermal_base" ]; then
        for _zone in "$thermal_base"/thermal_zone*; do
            [ -d "$_zone" ] || continue
            [ -r "$_zone/type" ] && [ -r "$_zone/temp" ] || continue
            read -r _sensor_type < "$_zone/type" 2>/dev/null || continue
            case "$_sensor_type" in
                cpu-0-0|cpuss-0|cpu-0-1|cpuss-1|cpu-1-0)
                    [ -z "$cpu_sensor" ] && cpu_sensor="$_zone/temp";;
                gpuss-0|gpuss-1|gpu)
                    [ -z "$gpu_sensor" ] && gpu_sensor="$_zone/temp";;
                battery)
                    [ -z "$battery_sensor" ] && battery_sensor="$_zone/temp";;
            esac
        done
    fi
    [ -z "$battery_sensor" ] && [ -r /sys/class/power_supply/battery/temp ] && \
        battery_sensor=/sys/class/power_supply/battery/temp

    _get_temp() {
        REPLY="N/A"
        local path="$1" raw
        [ -n "$path" ] && [ -r "$path" ] || return
        read -r raw < "$path" 2>/dev/null || return
        [ -z "$raw" ] && return
        if [ "$raw" -gt 1000 ] 2>/dev/null; then raw=$((raw / 1000)); fi
        if [ "$raw" -gt 5 ] && [ "$raw" -lt 120 ] 2>/dev/null; then
            REPLY="${raw}°C"
        fi
    }

    _get_temp "$cpu_sensor";     cpu_temp=$REPLY
    _get_temp "$gpu_sensor";     gpu_temp=$REPLY
    _get_temp "$battery_sensor"; bat_temp=$REPLY

    # ---------- 运行时间 ----------
    uptime_raw=$($_UPTIME 2>/dev/null || echo "无法获取")

    # ---------- 输出 ----------
    cecho -b "系统信息"
    cecho "$CMD_delimiter"
    cecho "主机名: $hostname"
    cecho "系统: Android $osver (SDK $sdkver)  内核: $kernel"
    cecho "制造商: $manuf  型号: $model"
    cecho "CPU: $cpu_model"
    cecho "核心数: $cpu_cores"
    cecho "核心频率:"
    cecho "$freq_info"
    cecho "$CMD_delimiter"
    cecho "内存使用率: ${mem_percent}%  已用: $((mem_used_kb/1024))MB / 总计: $((mem_total_kb/1024))MB"
    # 修正标签：Buffers=缓冲  Cached=缓存
    cecho "  可用: $((mem_avail_kb/1024))MB  缓冲: $((mem_buffers_kb/1024))MB  缓存: $((mem_cached_kb/1024))MB"
    if [ "$swap_total_kb" -gt 0 ]; then
        cecho "Swap使用率: ${swap_percent}%  已用: $((swap_used_kb/1024))MB / 总计: $((swap_total_kb/1024))MB"
    else
        cecho "Swap: 未启用或无"
    fi
    cecho "$CMD_delimiter"
    cecho "CPU温度: $cpu_temp    GPU温度: $gpu_temp    电池温度: $bat_temp"
    cecho "$CMD_delimiter"
    cecho "运行时间及负载: $uptime_raw"
    cecho "$CMD_delimiter"
}