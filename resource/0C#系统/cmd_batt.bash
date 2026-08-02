#resource/cmd_batt.bash
# ---------- BATT 读取电池信息 ----------
cmd_batt() {
    local batt_dir="/sys/class/power_supply/battery"
    if [ ! -d "$batt_dir" ]; then
        err "电池信息目录不存在: $batt_dir"
        return 1
    fi

    local capacity="未知"
    local temp="未知"
    local voltage="未知"
    local status="未知"

    # 电量
    if [ -r "$batt_dir/capacity" ]; then
        capacity=$($_CAT "$batt_dir/capacity" 2>/dev/null | tr -d '\n\r')
        [ -n "$capacity" ] && capacity="${capacity}%"
    fi

    # 温度 (单位 0.1°C)
    if [ -r "$batt_dir/temp" ]; then
        local temp_raw=$($_CAT "$batt_dir/temp" 2>/dev/null | tr -d '\n\r')
        if [ -n "$temp_raw" ]; then
            # 若温度值大于1000,可能是已乘以10的数值,否则直接显示
            if [ "$temp_raw" -gt 1000 ] 2>/dev/null; then
                temp=$(echo "scale=1; $temp_raw / 10" | bc 2>/dev/null || echo "$temp_raw")
                temp="${temp}°C"
            else
                temp="${temp_raw}°C"
            fi
        fi
    fi

    # 电压 (微伏)
    if [ -r "$batt_dir/voltage_now" ]; then
        local volt_raw=$($_CAT "$batt_dir/voltage_now" 2>/dev/null | tr -d '\n\r')
        if [ -n "$volt_raw" ]; then
            # 若大于1000000 可能是微伏,转换为伏特
            if [ "$volt_raw" -gt 1000000 ] 2>/dev/null; then
                voltage=$(echo "scale=2; $volt_raw / 1000000" | bc 2>/dev/null || echo "$volt_raw")
                voltage="${voltage}V"
            else
                voltage="${volt_raw}V"
            fi
        fi
    fi

    # 状态
    if [ -r "$batt_dir/status" ]; then
        status=$($_CAT "$batt_dir/status" 2>/dev/null | tr -d '\n\r')
        [ -z "$status" ] && status="未知"
    fi

    # 输出
    cecho "电池电量:    $capacity"
    cecho "电池温度:    $temp"
    cecho "电池电压:    $voltage"
    cecho "充电状态:    $status"
}