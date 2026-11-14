#resource/cmd_temp.bash
cmd_temp() {
    local thermal_base="/sys/class/thermal"
    cecho -b "温度传感器"
    cecho "$CMD_delimiter"

    local sensor_found=0
    declare -A trip_map

    # 内建关键词匹配
    _kw_match() {
        case "${1,,}" in
            *cpu*|*gpu*|*battery*|*shell*|*frame*|*back*|*therm*) return 0 ;;
        esac
        return 1
    }
    # 内建读一行
    _read_one() { IFS= read -r "$2" < "$1" 2>/dev/null; }

    local zone type_file temp_file sensor_type temp_raw
    if [ -d "$thermal_base" ]; then
        for zone in "$thermal_base"/thermal_zone*; do
            [ -d "$zone" ] || continue
            type_file="$zone/type"; temp_file="$zone/temp"
            [ -r "$type_file" ] && [ -r "$temp_file" ] || continue

            _read_one "$type_file" sensor_type
            _read_one "$temp_file" temp_raw
            [ -z "$sensor_type" ] && sensor_type="unknown"
            [ -z "$temp_raw" ] && continue

            if _kw_match "$sensor_type"; then
                sensor_found=1
                local temp_c
                (( temp_raw > 1000 )) 2>/dev/null && temp_c=$((temp_raw/1000)) || temp_c=$temp_raw
                local display="${temp_c}°C"
                (( temp_c == 0 || temp_c > 130 || temp_c < -80 )) 2>/dev/null && display="${temp_c}°C (不准确)"
                cecho "  $sensor_type: $display"
            fi

            local trip_file trip_raw trip_c trip_base trip_type trip_risk
            for trip_file in "$zone"/trip_point_*_temp; do
                [ -r "$trip_file" ] || continue
                _read_one "$trip_file" trip_raw
                [ -z "$trip_raw" ] && continue

                (( trip_raw > 1000 )) 2>/dev/null && trip_c=$((trip_raw/1000)) || trip_c=$trip_raw

                trip_base="${trip_file##*/}"; trip_base="${trip_base%_temp}"
                trip_type="passive"
                [ -r "$zone/${trip_base}_type" ] && _read_one "$zone/${trip_base}_type" trip_type

                case "$trip_type" in
                    critical) trip_risk=3 ;;
                    hot)      trip_risk=2 ;;
                    passive)  trip_risk=1 ;;
                    *)        trip_risk=0 ;;
                esac
                local ex=${trip_map["$trip_c"]}
                { [ -z "$ex" ] || [ "$trip_risk" -gt "$ex" ]; } && trip_map["$trip_c"]=$trip_risk
            done
        done
    fi

    # 备用路径
    if [ $sensor_found -eq 0 ]; then
        local path raw name temp_c display
        for path in \
            /sys/devices/virtual/thermal/thermal_zone0/temp \
            /sys/class/hwmon/hwmon0/temp1_input \
            /sys/devices/system/cpu/cpu0/cpufreq/cpu_temp \
            /sys/class/power_supply/battery/temp; do
            [ -r "$path" ] || continue
            _read_one "$path" raw
            [ -z "$raw" ] && continue
            local tmp="${path%/*}"; name="${tmp##*/}"
            if _kw_match "$name"; then
                sensor_found=1
                (( raw > 1000 )) 2>/dev/null && temp_c=$((raw/1000)) || temp_c=$raw
                display="${temp_c}°C"
                (( temp_c == 0 || temp_c > 130 || temp_c < -80 )) 2>/dev/null && display="${temp_c}°C (不准确)"
                cecho "  $name: $display"
            fi
            break
        done
    fi
    [ $sensor_found -eq 0 ] && cecho "未找到匹配的温度传感器"

    # 温度墙: 内建插入排序
    echo ""
    cecho -b "温度墙阈值(去重)"
    cecho "$CMD_delimiter"
    if [ ${#trip_map[@]} -gt 0 ]; then
        local -a temps=("${!trip_map[@]}")
        local n=${#temps[@]} i j key
        for ((i=1; i<n; i++)); do
            key=${temps[i]}; j=$((i-1))
            while [ $j -ge 0 ] && [ "${temps[j]}" -gt "$key" ] 2>/dev/null; do
                temps[j+1]=${temps[j]}; j=$((j-1))
            done
            temps[j+1]=$key
        done
        local t label
        for t in "${temps[@]}"; do
            local r=${trip_map["$t"]}
            label="passive"; [ "$r" -ge 2 ] && label="hot"; [ "$r" -ge 3 ] && label="critical"
            cecho "  ${t}°C [$label]"
        done
    else
        cecho "未找到温度墙信息"
    fi

    # 温控状态
    echo ""
    cecho -b "温控状态"
    cecho "$CMD_delimiter"
    local cooling_active=0 cooling_severe=0
    if [ -d "$thermal_base/cooling_device0" ]; then
        local cooling cur max cur_file max_file
        for cooling in "$thermal_base"/cooling_device*; do
            [ -d "$cooling" ] || continue
            cur_file="$cooling/cur_state"; [ -r "$cur_file" ] || continue
            _read_one "$cur_file" cur
            [ -z "$cur" ] || [ "$cur" -eq 0 ] 2>/dev/null && continue
            cooling_active=1
            max_file="$cooling/max_state"
            if [ -r "$max_file" ]; then
                _read_one "$max_file" max
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