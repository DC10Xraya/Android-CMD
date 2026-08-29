#resource/cmd_hack2.bash
cmd_hack2() {
    local target="$*"
    if [[ -z "$target" ]]; then
        err "用法: HACK2 <目标>"
        return 1
    fi

    local temp=""
    # ASCII 可打印字符
    local charset=" !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_\`abcdefghijklmnopqrstuvwxyz{|}~"
    local len=${#charset}

    # 捕获 Ctrl+C
    local old_trap=$(trap -p INT)
    local interrupted=0
    trap 'interrupted=1' INT

    for (( i=0; i<${#target}; i++ )); do
        if (( interrupted )); then break; fi
        local ch="${target:$i:1}"

        # 二分查找（字符集已按 ASCII 有序）
        local lo=0 hi=$((len - 1))
        while (( lo <= hi )); do
            if (( interrupted )); then break; fi
            local mid=$(( (lo + hi) / 2 ))
            local try="${charset:$mid:1}"
            printf "%s%s\n" "$temp" "$try"
            sleep 0.01   # 可调整速度，甚至设为 0.001

            if [[ "$try" == "$ch" ]]; then
                temp+="$ch"
                break
            elif [[ "$try" < "$ch" ]]; then
                lo=$((mid + 1))
            else
                hi=$((mid - 1))
            fi
        done

        if (( interrupted )); then break; fi
    done
    echo ""

    eval "$old_trap" 2>/dev/null
    if (( interrupted )); then
        cecho "<中断>"
        return 130
    fi
    return 0
}