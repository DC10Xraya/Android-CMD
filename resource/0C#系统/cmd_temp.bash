#resource/cmd_temp.bash
cmd_temp() {
    local thermal_base="/sys/class/thermal"
    cecho -b "温度传感器"
    cecho "$CMD_delimiter"
    
    local sensor_found=0
    declare -A trip_map
    
    # ---- 关键词白名单(只显示包含这些关键词的传感器) ----
    local keywords="cpu|gpu|battery|shell|frame|back|therm"   # 可根据需要增减
    
    # ---- 1. 遍历所有 thermal_zone ----
    if [ -d "$thermal_base" ]; then
        for zone in "$thermal_base"/thermal_zone*; do
            [ -d "$zone" ] || continue
            local type_file="$zone/type"
            local temp_file="$zone/temp"
            [ -r "$type_file" ] && [ -r "$temp_file" ] || continue
            
            local sensor_type=$($_CAT "$type_file" 2>/dev/null | tr -d '\n\r')
            local temp_raw=$($_CAT "$temp_file" 2>/dev/null | tr -d '\n\r')
            [ -z "$sensor_type" ] && sensor_type="unknown"
            [ -z "$temp_raw" ] && continue
            
            # ---- 只显示匹配关键词的传感器 ----
            if echo "$sensor_type" | grep -Eiq "$keywords"; then
                sensor_found=1
                # 温度转换
                local temp_c
                if [ "$temp_raw" -gt 1000 ] 2>/dev/null; then
                    temp_c=$((temp_raw / 1000))
                else
                    temp_c="$temp_raw"
                fi
                
                local display="${temp_c}°C"
                if [ "$temp_c" -eq 0 ] || [ "$temp_c" -gt 130 ] || [ "$temp_c" -lt -80 ]; then
                    display="${temp_c}°C (不准确)"
                fi
                cecho "  $sensor_type: $display"
            fi
            
            # ---- 收集温度墙(依然全量, 不受过滤影响) ----
            for trip_file in "$zone"/trip_point_*_temp; do
                [ -r "$trip_file" ] || continue
                local trip_raw=$($_CAT "$trip_file" 2>/dev/null | tr -d '\n\r')
                [ -z "$trip_raw" ] && continue
                
                local trip_c
                if [ "$trip_raw" -gt 1000 ] 2>/dev/null; then
                    trip_c=$((trip_raw / 1000))
                else
                    trip_c="$trip_raw"
                fi
                
                local trip_base=$(basename "$trip_file" "_temp")
                local type_file2="$zone/${trip_base}_type"
                local trip_type="passive"
                [ -r "$type_file2" ] && trip_type=$($_CAT "$type_file2" 2>/dev/null | tr -d '\n\r')
                
                local risk_level=0
                case "$trip_type" in
                    critical) risk_level=3 ;;
                    hot)      risk_level=2 ;;
                    passive)  risk_level=1 ;;
                esac
                
                local existing_risk=${trip_map["$trip_c"]}
                if [ -z "$existing_risk" ] || [ $risk_level -gt $existing_risk ]; then
                    trip_map["$trip_c"]=$risk_level
                fi
            done
        done
    fi
    
    # ---- 备用路径(同样过滤) ----
    if [ $sensor_found -eq 0 ]; then
        for path in "/sys/devices/virtual/thermal/thermal_zone0/temp" \
                     "/sys/class/hwmon/hwmon0/temp1_input" \
                     "/sys/devices/system/cpu/cpu0/cpufreq/cpu_temp" \
                     "/sys/class/power_supply/battery/temp"; do
            [ -r "$path" ] || continue
            local raw=$($_CAT "$path" 2>/dev/null | tr -d '\n\r')
            [ -z "$raw" ] && continue
            local name=$(basename "$(dirname "$path")")
            # 如果路径名不在关键词中, 跳过(但备用路径通常含cpu/battery)
            if echo "$name" | grep -Eiq "$keywords"; then
                sensor_found=1
                local temp_c
                if [ "$raw" -gt 1000 ] 2>/dev/null; then
                    temp_c=$((raw / 1000))
                else
                    temp_c="$raw"
                fi
                local display="${temp_c}°C"
                if [ "$temp_c" -eq 0 ] || [ "$temp_c" -gt 130 ] || [ "$temp_c" -lt -80 ]; then
                    display="${temp_c}°C (不准确)"
                fi
                cecho "  $name: $display"
            fi
            break
        done
    fi
    
    if [ $sensor_found -eq 0 ]; then
        cecho "未找到匹配的温度传感器(关键词: $keywords)"
    fi
    
    # ---- 2. 温度墙(去重排序) ----
    echo ""
    cecho -b "温度墙阈值(去重)"
    cecho "$CMD_delimiter"
    if [ ${#trip_map[@]} -gt 0 ]; then
        local sorted_temps=$(printf '%s\n' "${!trip_map[@]}" | sort -n)
        for temp in $sorted_temps; do
            local risk_level=${trip_map["$temp"]}
            local type_label="passive"
            [ $risk_level -ge 2 ] && type_label="hot"
            [ $risk_level -ge 3 ] && type_label="critical"
            cecho "  ${temp}°C [$type_label]"
        done
    else
        cecho "未找到温度墙信息"
    fi
    
    # ---- 3. 温控状态 ----
    echo ""
    cecho -b "温控状态"
    cecho "$CMD_delimiter"
    local cooling_active=0
    local cooling_severe=0
    if [ -d "$thermal_base/cooling_device0" ]; then
        for cooling in "$thermal_base"/cooling_device*; do
            [ -d "$cooling" ] || continue
            local cur_file="$cooling/cur_state"
            [ -r "$cur_file" ] || continue
            local cur=$($_CAT "$cur_file" 2>/dev/null | tr -d '\n\r')
            [ -z "$cur" ] || [ "$cur" -eq 0 ] 2>/dev/null && continue
            cooling_active=1
            local max_file="$cooling/max_state"
            if [ -r "$max_file" ]; then
                local max=$($_CAT "$max_file" 2>/dev/null | tr -d '\n\r')
                if [[ "$max" =~ ^[0-9]+$ ]] && [ "$max" -gt 0 ] 2>/dev/null; then
                    [ "$cur" -gt "$((max / 2))" ] && cooling_severe=1
                fi
            fi
            break
        done
    fi
    
    if [ $cooling_severe -eq 1 ]; then
        cecho "严重温控(冷却设备已过半强度)"
    elif [ $cooling_active -eq 1 ]; then
        cecho "温控中(冷却设备已启动)"
    else
        cecho "正常(无冷却设备运行)"
    fi
    cecho "$CMD_delimiter"
}