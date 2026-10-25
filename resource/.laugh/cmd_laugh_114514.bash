#/resource/cmd_laugh_114514.bash
cmd_laugh_114514() {
    if ! confirm "进入这个隐藏命令吗(可能使你无法退出,造成的影响与作者无关,内容仅供娱乐)?"; then
        return
    fi
    if ! confirm "确认?(你已经被警告过了)"; then
        return
    fi
    trap 'cecho -c 36 "[System]:@$USERNAME bro我们还什么都没干呢"; return 130' INT TERM QUIT
    # 就是不退出,你气不气?
    cecho "正在呼叫野兽先辈写命令提示符..."
    sleep 3
    cecho -c 36 "[System]:@$USERNAME 给你一次机会, 你来执行"
    sleep 0.67
    cecho -c 36 "[System]$PROMPT_SYMBOL sh \"csp by 114514.sh\""
    if ! confirm "确认要执行此脚本吗?(请确认脚本内不含危险代码!)"; then
        cecho -c 36  "[System]$USERNAME 给你机会你不中用啊😡"
        return 0
    fi
    cecho "执行脚本: csp by 114514.sh"
    trap 'cecho "脚本被用户中断"; return 130' INT TERM QUIT
    sleep 0.5
    cmd_cls -n
    printf "\033[32m---------------CSP Running-----------------\033[0m\n"
    sleep 0.1
    cecho "野兽先辈的命令臭死符 [版本:114514.1919810]"
    cecho "Copyright (c) 1919 野兽先辈"
    cecho -i -c 93 "臭死了,臭死了"
    cecho "使用 HELP 或 /? 不能查看命令列表(Ctrl+C退不出)"
    cecho "若参数包含空格, 用大声喊叫包裹即可"
    echo ""
    echo ""
    cecho -c 33 "<野兽先辈/???>:嗯哼哼哼!啊啊啊啊啊啊!啊啊啊啊啊啊啊哈哈呃!哼!哼!"
    sleep 2
    cecho -c 36  "[System]:WTFFFFF"
    sleep 1
    err "脚本以退出码 114514 挂起"
    echo -e "\033[31m--------------CMD ERROR:臭死了--------------\033[0m"
    echo "[进程组发生沼气爆炸 (error 114514) - 按回车也关不闭]"
    trap 'err "脚本终止失败 (错误码 114)"' INT TERM QUIT
    while true; do
        sleep 114514
    done
}