#resource/cmd_batt.bash
# ---------- BATT 读取电池信息 ----------
cmd_batt() {
    local batt_dir="/sys/class/power_supply/battery"
    if [ ! -d "$batt_dir" ]; then
        err "电池信息目录不存在: $batt_dir"
        return 1
    fi

    # 读取通用属性函数（自动去除换行）
    _read_attr() {
        local file="$1"
        local default="${2:-未知}"
        if [ -r "$file" ]; then
            local val=$($_CAT "$file" 2>/dev/null | tr -d '\n\r')
            echo "${val:-$default}"
        else
            echo "$default"
        fi
    }

    # 基本属性
    local capacity=$(_read_attr "$batt_dir/capacity" "未知")
    [ "$capacity" != "未知" ] && capacity="${capacity}%"

    # 温度 (单位 0.1°C 或 1°C 自适应)
    local temp_raw=$(_read_attr "$batt_dir/temp" "")
    local temp="未知"
    if [ -n "$temp_raw" ]; then
        if [ "$temp_raw" -gt 1000 ] 2>/dev/null; then
            temp=$(echo "scale=1; $temp_raw / 10" | bc 2>/dev/null || echo "$temp_raw")
        else
            temp="$temp_raw"
        fi
        temp="${temp}°C"
    fi

    # 电压 (微伏 → 伏特)
    local volt_raw=$(_read_attr "$batt_dir/voltage_now" "")
    local voltage="未知"
    if [ -n "$volt_raw" ]; then
        if [ "$volt_raw" -gt 1000000 ] 2>/dev/null; then
            voltage=$(echo "scale=2; $volt_raw / 1000000" | bc 2>/dev/null || echo "$volt_raw")
        else
            voltage="$volt_raw"
        fi
        voltage="${voltage}V"
    fi

    # 电流 (微安 → 安培)
    local curr_raw=$(_read_attr "$batt_dir/current_now" "")
    local current="未知"
    if [ -n "$curr_raw" ]; then
        if [ "$curr_raw" -gt 1000000 ] 2>/dev/null; then
            current=$(echo "scale=2; $curr_raw / 1000000" | bc 2>/dev/null || echo "$curr_raw")
        else
            current="$curr_raw"
        fi
        current="${current}A"
    fi

    # 状态、健康、技术、循环次数
    local status=$(_read_attr "$batt_dir/status" "未知")
    local health=$(_read_attr "$batt_dir/health" "未知")
    local tech=$(_read_attr "$batt_dir/technology" "未知")
    local cycle=$(_read_attr "$batt_dir/cycle_count" "未知")

    # 输出（对齐格式）
    cecho -b "--- 电池信息 ---"
    cecho "电量:        $capacity"
    cecho "温度:        $temp"
    cecho "电压:        $voltage"
    cecho "电流:        $current"
    cecho "状态:        $status"
    cecho "健康:        $health"
    cecho "技术:        $tech"
    cecho "循环次数:    $cycle"
    cecho "----------------"
}