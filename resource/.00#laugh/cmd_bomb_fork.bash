cmd_bomb_fork() {
    # 保存旧的 INT 陷阱
    local old_trap=$(trap -p INT)
    local bomb_interrupted=0

    # 设置新的 INT 陷阱：标记中断并立即返回
    trap 'bomb_interrupted=1; return 130' INT

    if ! confirm "你想进入这个炸弹吗?这很危险,真的执行后将会卡死你的系统,输入N退出"; then
        [ $bomb_interrupted -eq 1 ] && return 130
        return
    fi
    [ $bomb_interrupted -eq 1 ] && return 130

    if ! confirm "确认?(你已经被警告过了)"; then
        [ $bomb_interrupted -eq 1 ] && return 130
        return
    fi
    [ $bomb_interrupted -eq 1 ] && return 130
    echo ""
    cecho "$CMD_delimiter"
    err "警告: 此命令将耗尽系统所有进程资源, 请慎重考虑!"
    err "如果你想通了,按 Ctrl+C 可随时退出(倒计时期间同样有效)"
    echo ""
    echo ""
    sleep 2

    # ---------- 四个确认询问 ----------
    if ! confirm "此命令会瞬间耗尽系统所有进程资源, 导致手机完全无响应、屏幕卡死, 你必须按照方法强制重启(可能丢失未保存数据) 你确定要执行吗?"; then
        [ $bomb_interrupted -eq 1 ] && return 130
        return
    fi
    [ $bomb_interrupted -eq 1 ] && return 130

    if ! confirm "\n本命令仅供娱乐测试, 作者不承担任何设备损坏或数据丢失的责任\n你已阅读并同意吗?"; then
        [ $bomb_interrupted -eq 1 ] && return 130
        return
    fi
    [ $bomb_interrupted -eq 1 ] && return 130

    if ! confirm "\n每个厂商的系统强制重启方法不一, 若执行后系统死机, 你已知晓恢复方法吗?\n(!!!提示:强制重启之后进入系统修复,一定要选择重启,绝对不要选择清除分区或格式化分区[相当于恢复出厂设置]!!!)"; then
        [ $bomb_interrupted -eq 1 ] && return 130
        return
    fi
    [ $bomb_interrupted -eq 1 ] && return 130
    echo ""
    cecho "$CMD_delimiter"
    err "![引爆须知/非常重要]!"
    err "如果你真的想引爆这个炸弹,请进入该函数(resource/.00#laugh/!危险!/cmd_bomb_fork.bash)的对应位置,将86行的注释(开头的#)移除"
    err "(即使你不想引爆,若继续往下执行,也必须查看是否安全)"
    err "(如果你这么做了即代表你已经同意作者不承担任何设备损坏或数据丢失的责任!!!)"
    if ! confirm "确认阅读了吗?"; then
        [ $bomb_interrupted -eq 1 ] && return 130
        return
    fi
    [ $bomb_interrupted -eq 1 ] && return 130
    echo ""
    err "$CMD_delimiter"
    err "$CMD_delimiter"
    err "$CMD_delimiter"
    if ! confirm "最后确认: 你真的要引爆这颗炸弹吗?"; then
        [ $bomb_interrupted -eq 1 ] && return 130
        cecho "已取消, 永远不要再尝试了"
        eval "$old_trap" 2>/dev/null || trap - INT
        return
    fi
    [ $bomb_interrupted -eq 1 ] && return 130

    err "引爆倒计时:30秒[!!!Ctrl+C还有机会!!!]"
    for ((i=30; i>=1; i--)); do
        if [ $i -gt 10 ]; then
            echo "///剩余 $i 秒///"
        else
            err "///////// $i /////////"
        fi
        sleep 1
        if [ $bomb_interrupted -eq 1 ]; then
            echo ""
            err "已取消"
            eval "$old_trap" 2>/dev/null || trap - INT
            return 130
        fi
    done

    err "////////////////// !起爆! //////////////////"
    #sh -c ':(){ :|:& };:'
    #如果你真的想要,移除上面的注释,你已经被警告过了
    sleep 5
    cecho "如果输出这条,说明炸弹还处于注释状态,没有引爆"
    cecho "如果你真的想引爆这个炸弹,请进入该函数(resource/.00#laugh/!危险!/cmd_bomb_fork.bash)的对应位置,将86行的注释(开头的#)移除"
    err "(如果你这么做了即代表你已经同意作者不承担任何设备损坏或数据丢失的责任!!!)"
    echo ""
    return 0
    # ---------- 恢复陷阱 ----------
    eval "$old_trap" 2>/dev/null || trap - INT
}