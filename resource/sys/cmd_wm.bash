#resource/cmd_wm.bash
cmd_wm() {
    # 如果有参数, 直接透传给系统 wm(不解析)
    if [ $# -gt 0 ]; then
        if command -v wm >/dev/null 2>&1; then
            wm "$@"
        else
            err "系统未找到 WM 命令, 无法执行子命令"
            return 1
        fi
        return $?
    fi

    # 无参数：显示所有可用信息
    if command -v wm >/dev/null 2>&1; then
        # 获取各项信息
        local size_info=$(wm size 2>/dev/null)
        local density_info=$(wm density 2>/dev/null)
        local overscan_info=$(wm overscan 2>/dev/null)

        # 显示
        if [ -n "$size_info" ]; then
            cecho -c 36 "Physical Size:  ${size_info#*: }"
        else
            cecho -c 31 "Physical Size:  无法获取"
        fi

        if [ -n "$density_info" ]; then
            cecho -c 36 "Physical Density: ${density_info#*: }"
        else
            cecho -c 31 "Physical Density: 无法获取"
        fi

        if [ -n "$overscan_info" ]; then
            cecho -c 36 "Overscan:       ${overscan_info#*: }"
        else
            cecho -c 31 "Overscan:       无法获取"
        fi

        # 额外信息(通过 getprop 补充)
        local display_id=$(getprop ro.display.id 2>/dev/null)
        [ -n "$display_id" ] && cecho -c 36 "Display ID:     $display_id"

        local layer_stack=$(getprop debug.sf.layer_stack 2>/dev/null)
        [ -n "$layer_stack" ] && cecho -c 36 "Layer Stack:    $layer_stack"

        # 检查是否支持旋转等
        local rotation=$(getprop persist.demo.hdmirotation 2>/dev/null)
        [ -n "$rotation" ] && cecho -c 36 "HDMI Rotation:  $rotation"

        # 再尝试获取当前分辨率和 dpi(可能 override)
        local curr_size=$(getprop ro.display.size 2>/dev/null)
        [ -n "$curr_size" ] && cecho -c 36 "Current Size:   $curr_size"

        local curr_dpi=$(getprop ro.sf.lcd_density 2>/dev/null)
        [ -n "$curr_dpi" ] && cecho -c 36 "Current DPI:    $curr_dpi"

    else
        err "未找到WM命令, 请使用RES"
    fi
}