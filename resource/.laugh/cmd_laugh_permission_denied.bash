#/resource/cmd_laugh_permission_denied.bash
cmd_laugh_permission_denied() {
    # 参数检查
    if [ $# -gt 0 ]; then
        if [ "$1" = "denied" ]; then
            :
        else
            err "permission: 命令未找到"
            return 1
        fi
    fi

    # 两次确认
    if ! confirm "Permission denied?(如不想影响你的工作,请输入N)"; then
        return
    fi
    if ! confirm "确认?(可能使你无法退出,造成的影响与作者无关,你已经被警告过了)"; then
        return
    fi

    local script_path="$0"
    local line_num="?"
    local func_start=$(grep -n '^_kill_process_tree_force()' "$script_path" 2>/dev/null | head -1 | cut -d: -f1)
    if [ -n "$func_start" ]; then
        local target_line=$(sed -n "${func_start},/^}/p" "$script_path" 2>/dev/null | \
                            grep -n 'kill -KILL "\$pid" 2>/dev/null' | head -1 | cut -d: -f1)
        if [ -n "$target_line" ]; then
            line_num=$((func_start + target_line - 1))
        fi
    fi

    trap "
        echo -e \"\n$script_path: line $line_num: _kill_process_tree_force: Permission denied\"
        sleep 0.1
    " INT TERM QUIT

    sleep 0.1
    return 0
}