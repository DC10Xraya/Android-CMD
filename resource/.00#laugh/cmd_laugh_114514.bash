#/resource/cmd_laugh_114514.bash
cmd_laugh_114514() {
    if ! confirm "进入这个隐藏命令吗(可能使你无法退出,造成的影响与作者无关,内容仅供娱乐)?"; then
        return
    fi
    if ! confirm "确认?(你已经被警告过了)"; then
        return
    fi
    # 就是不退出,你气不气?
    cmd_cls_no_title
    cecho "$CMD_delimiter"
    cecho "野兽先辈的命令臭死符 [版本:114514.1919810]"
    cecho "Copyright (c) 1919 野兽先辈"
    cecho "使用 HELP 或 /? 不能查看命令列表(Ctrl+C退不出)"
    echo ""
    echo ""
    echo -e "\033[33m<野兽先辈/???>:嗯哼哼哼!啊啊啊啊啊啊!啊啊啊啊啊啊啊哈哈呃!哼!哼!~\033[0m"
    sleep 2
    echo -e "\033[31m--------------CMD ERROR:臭死了--------------\033[0m"
    echo "[进程未结束 (error stink) - 按回车也关不闭]"
    trap 'echo -e "[进程结束未出错 (stopping error stink) - Ctrl+C也关不闭]\n\033[36m[System]:检测到沼气爆炸,预计污染半径114514km,放弃一切关闭尝试,立即删除.sh文件\033[0m"; sleep 0.5' INT TERM QUIT
    while true; do
        sleep 1145141919810
    done
}