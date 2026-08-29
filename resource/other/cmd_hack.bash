#resource/cmd_hack.bash
cmd_hack() {
    local target="$*"
    if [[ -z "$target" ]]; then
        err "用法: HACK <目标>"
        return 1
    fi

    local temp=""
    local charset=" 0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!\"#$%&'()*+,-./:;<=>?@[\]^_\`{|}~"

    # 本地 trap 捕获 Ctrl+C
    local old_trap=$(trap -p INT)
    local interrupted=0
    trap 'interrupted=1' INT

    for (( i=0; i<${#target}; i++ )); do
        if [ $interrupted -eq 1 ]; then break; fi
        local ch="${target:$i:1}"
        for (( j=0; j<${#charset}; j++ )); do
            if [ $interrupted -eq 1 ]; then break; fi
            local try="${charset:$j:1}"
            printf "%s%s\n" "$temp" "$try"
            sleep 0.01
            if [[ "$try" == "$ch" ]]; then
                temp+="$ch"
                break
            fi
        done
    done
    echo ""

    eval "$old_trap" 2>/dev/null
    if [ $interrupted -eq 1 ]; then
        cecho "<中断>"
        return 130
    fi
    return 0
}