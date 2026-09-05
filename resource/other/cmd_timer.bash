#resource/cmd_timer.bash
cmd_timer() {
        if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -eq 0 ]; then
        err "用法: TIMER [秒数]/[时间戳]"
        cecho -b "示例:"
        cecho "TIMER 60                    # 60秒倒计时"
        cecho "TIMER 2026-07-20 15:30:00   # 到这个时间点的闹钟"
        return 1
    fi

    # 合并所有参数为一个字符串
    local arg="$*"
    local target_ts=0
    local mode="countdown"  # countdown 或 alarm

    # 判断参数类型: 纯数字 -> 倒计时；否则尝试解析为日期时间
    if [[ "$arg" =~ ^[0-9]+$ ]]; then
        # 倒计时模式
        local seconds="$arg"
        if [ "$seconds" -eq 0 ]; then
            err "秒数必须大于0"
            return 1
        fi
        target_ts=$(date +%s)
        target_ts=$((target_ts + seconds))
        cecho "倒计时 ${seconds} 秒, 按 Ctrl+C 取消"
    else
        # 闹钟模式: 尝试解析日期时间
        if ! command -v date >/dev/null 2>&1; then
            err "date 命令不可用,无法解析时间"
            return 1
        fi
        target_ts=$(date -d "$arg" +%s 2>/dev/null)
        if [ $? -ne 0 ] || [ -z "$target_ts" ]; then
            err "无法解析时间格式,请使用 date 命令可识别的格式,例如 \"2026-07-20 15:30:00\""
            return 1
        fi
        local now_ts=$(date +%s)
        if [ "$target_ts" -le "$now_ts" ]; then
            err "闹钟时间必须在未来"
            return 1
        fi
        cecho "闹钟设置为 $arg, 按 Ctrl+C 取消"
        mode="alarm"
    fi

    # ---------- 本地信号处理 ----------
    local cancelled=0
    local old_trap=$(trap -p INT)
    trap 'cancelled=1' INT

    # ---------- 计时循环 ----------
    local last_second=""
    while [ $cancelled -eq 0 ]; do
        local now_ts=$(date +%s)
        local remaining=$((target_ts - now_ts))

        if [ $remaining -le 0 ]; then
            break
        fi

        local days=$((remaining / 86400))
        local hours=$(( (remaining % 86400) / 3600 ))
        local mins=$(( (remaining % 3600) / 60 ))
        local secs=$((remaining % 60))

        local display=""
        if [ $days -gt 0 ]; then
            display="${days}天 ${hours}时 ${mins}分 ${secs}秒"
        elif [ $hours -gt 0 ]; then
            display="${hours}时 ${mins}分 ${secs}秒"
        elif [ $mins -gt 0 ]; then
            display="${mins}分 ${secs}秒"
        else
            display="${secs}秒"
        fi

        if [ "$remaining" != "$last_second" ]; then
            printf "\r\033[K剩余时间: %s" "$display"
            last_second="$remaining"
        fi

        # 精确睡眠到下一秒
        if [ $remaining -gt 0 ]; then
            local now_ms
            if date +%s%N >/dev/null 2>&1; then
                now_ms=$(date +%s%N | cut -b1-13)
            else
                now_ms=$(date +%s)000
            fi
            local current_second=$((now_ms % 1000))
            local sleep_ms=$((1000 - current_second))
            if [ $sleep_ms -gt 0 ]; then
                local sleep_sec=$(echo "scale=3; $sleep_ms / 1000" | bc 2>/dev/null)
                if [ -n "$sleep_sec" ]; then
                    sleep "$sleep_sec" 2>/dev/null || true
                else
                    sleep 1
                fi
            fi
        fi
    done

    printf "\r\033[K\n"

    # ---------- 恢复原来的 INT 陷阱 ----------
    eval "$old_trap" 2>/dev/null

    # ---------- 处理退出 ----------
    if [ $cancelled -eq 1 ]; then
        cecho "计时已取消"
        return 130
    fi

    # 正常结束
    echo ""
    for i in {1..46}; do
        err "---------------!!!时间到!!!---------------"
    done

    return 0
}