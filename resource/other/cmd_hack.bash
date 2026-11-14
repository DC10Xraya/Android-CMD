#resource/cmd_hack.bash
cmd_hack() {
    local target=""
    local sleep_time=0.01
    local sleep_default=1
    local custom_charset=""
    local show_time=0
    local verbose=0

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
ccat << "EOF"
//cecho -b "用法: HACK [-h] [-t] [-s 秒数] [-c 字符集] [-v] <目标>"
//cecho -b "参数:"
  -t            记录时间
  -s <秒数>     设置间隔睡眠时间(默认0.01s)
  -c <字符集>   自定义搜索的字符串范围
  -v            原地动态显示结果
  -h/--help     显示此帮助
EOF
return 0
;;
            -t) show_time=1; shift ;;
            -s)
                if [[ -z "$2" || ! "$2" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
                    err "用法: HACK [-h] [-t] [-s 秒数] [-c 字符集] [-v] <目标>"
                    return 1
                fi
                sleep_time="$2"; sleep_default=0; shift 2 ;;
            -c)
                if [[ -z "$2" ]]; then
                    err "用法: HACK [-h] [-t] [-s 秒数] [-c 字符集] [-v] <目标>"
                    return 1
                fi
                custom_charset="$2"; shift 2 ;;
            -v) verbose=1; shift ;;
            --) shift; break ;;
            -*)
                err "未知选项: $1"
                return 1 ;;
            *) break ;;
        esac
    done
    target="$*"

    if [[ -z "$target" ]]; then
        err "用法: HACK [-h] [-t] [-s 秒数] [-c 字符集] [-v] <目标>"
        return 1
    fi

    local temp=""
    local charset
    if [[ -n "$custom_charset" ]]; then
        charset="$custom_charset"
    else
        charset=" 0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!\"#$%&'()*+,-./:;<=>?@[\]^_\`{|}~"
    fi
    if [[ -z "$charset" ]]; then
        err "字符集不能为空"
        return 1
    fi

    local do_sleep=0
    if awk "BEGIN{exit !($sleep_time > 0)}"; then
        do_sleep=1
    fi

    local old_trap=$(trap -p INT)
    local interrupted=0
    trap 'interrupted=1' INT

    local attempts=0
    local start_time=0
    if (( show_time )); then
        start_time=$(date +%s.%N)
    fi

    for (( i=0; i<${#target}; i++ )); do
        if (( interrupted )); then break; fi
        local ch="${target:$i:1}"
        for (( j=0; j<${#charset}; j++ )); do
            if (( interrupted )); then break; fi
            local try="${charset:$j:1}"
            ((attempts++))
            if (( verbose )); then
                printf '\r\033[32m%s\033[31m%s\033[0m\033[K' "$temp" "$try"
            else
                printf "%s%s\n" "$temp" "$try"
            fi
            if (( do_sleep )); then
                sleep "$sleep_time"
            fi
            if [[ "$try" == "$ch" ]]; then
                temp+="$ch"
                if (( verbose )); then
                    printf '\r\033[32m%s\033[0m\033[K' "$temp"
                fi
                break
            fi
        done
    done

    if (( verbose )); then
        printf '\033[0m\n'
    else
        cecho ""
    fi

    if (( show_time )); then
        local end_time=$(date +%s.%N)
        local elapsed_s=$(awk "BEGIN{printf \"%.3f\", $end_time - $start_time}")
        if (( sleep_default )); then
            cecho "实际耗时: ${elapsed_s} 秒"
            cecho "尝试次数: ${attempts}"
            cecho "睡眠间隔: ${sleep_time} 秒(默认)"
        else
            cecho "实际耗时: ${elapsed_s} 秒"
            cecho "尝试次数: ${attempts}"
            cecho "睡眠间隔: ${sleep_time} 秒"
        fi
    fi

    eval "$old_trap" 2>/dev/null
    if (( interrupted )); then
        cecho "<中断>"
        return 130
    fi
    return 0
}