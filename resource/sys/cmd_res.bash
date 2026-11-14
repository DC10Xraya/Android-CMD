#resource/cmd_res.bash
cmd_res() {
    local width="未知"
    local height="未知"
    local dpi="未知"

    # 优先使用 wm 命令获取
    if command -v wm >/dev/null 2>&1; then
        local size_output=$(wm size 2>/dev/null)
        if [ -n "$size_output" ]; then
            local size=$(echo "$size_output" | awk '{print $NF}')
            if [[ "$size" =~ ^([0-9]+)x([0-9]+)$ ]]; then
                width="${BASH_REMATCH[1]}"
                height="${BASH_REMATCH[2]}"
            fi
        fi
        local density_output=$(wm density 2>/dev/null)
        if [ -n "$density_output" ]; then
            dpi=$(echo "$density_output" | awk '{print $NF}')
            [ -n "$dpi" ] && [ "$dpi" != "Physical" ] || dpi="未知"
        fi
    fi

    # 回退到 getprop
    if [ "$width" = "未知" ] || [ "$height" = "未知" ]; then
        local prop_size=$(getprop ro.display.size 2>/dev/null)
        if [ -n "$prop_size" ]; then
            width=$(echo "$prop_size" | cut -d'x' -f1)
            height=$(echo "$prop_size" | cut -d'x' -f2)
        else
            local w=$(getprop ro.sf.lcd_width 2>/dev/null)
            local h=$(getprop ro.sf.lcd_height 2>/dev/null)
            [ -n "$w" ] && width="$w"
            [ -n "$h" ] && height="$h"
        fi
    fi

    if [ "$dpi" = "未知" ]; then
        local dpi_prop=$(getprop ro.sf.lcd_density 2>/dev/null)
        [ -n "$dpi_prop" ] && dpi="$dpi_prop"
    fi

    # 最后的 fallback：/sys
    if [ "$width" = "未知" ] || [ "$height" = "未知" ]; then
        if [ -r "/sys/class/graphics/fb0/virtual_size" ]; then
            local fb_size=$($_CAT /sys/class/graphics/fb0/virtual_size 2>/dev/null)
            if [[ "$fb_size" =~ ^([0-9]+),([0-9]+)$ ]]; then
                width="${BASH_REMATCH[1]}"
                height="${BASH_REMATCH[2]}"
            fi
        fi
    fi

    cecho "屏幕分辨率: ${width} x ${height}"
    cecho "屏幕 DPI:    ${dpi}"
}