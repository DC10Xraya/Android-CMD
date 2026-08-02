#/resource/cmd_laugh_command_not_found.bash
cmd_laugh_command_not_found() {
    # 如果传入了参数，检查是否为 "not found"
    if [ $# -gt 0 ]; then
        # 必须恰好两个参数：not 和 found
        if [ $# -eq 2 ] && [ "$1" = "not" ] && [ "$2" = "found" ]; then
            # 参数匹配，继续执行彩蛋
            :
        else
            # 参数不匹配，输出错误（与原 command 分支行为一致）
            err "未知命令 \"command\"，请使用 HELP 或 /? 来查看命令列表"
            return 1
        fi
    fi

    local line_count_laugh=$(wc -l < "$0")
    if ! confirm "command not found?(如不想影响你的工作,请输入N)"; then
        return
    fi
    if ! confirm "确认?(可能使你无法退出,造成的影响与作者无关,你已经被警告过了)"; then
        return
    fi
    cmd_cls_no_title
    sleep 0.1
    cecho "command not found?"
    sleep 1
    cecho "command not found!"
    sleep 0.8
    err "command not found!!!"
    sleep 0.2
    echo -e "\033[36m[System]:@$USERNAME You will play egg\033[0m"
    sleep 0.8
    trap 'echo -e "\n$0: line $line_count_laugh: cmd_exit9: command not found]"; sleep 0.5' INT TERM QUIT
    while true; do
        yes "bash: command not found: command not found!!!!!!"
    done
}