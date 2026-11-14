#/resource/cmd_laugh_100.bash
cmd_laugh_100() {
    cecho "[在这里只需要按Ctrl+C就会退出该命令:D]"
    cecho "$CMD_delimiter"
    sleep 0.2
    #第100个开发版本彩蛋
    local old_trap=$(trap -p INT)
    trap 'break' INT

    local spin=('|' '/' '-' '\')
    local colors=(31 32 33 34 35 36 37)
    local i=0 c=0

    while true; do
        printf "\r[ %c ] \033[%dmThe 100th dev build version!!! (Build Time: 2026-07-20)\033[0m" \
               "${spin[i]}" "${colors[c]}"
        i=$(( (i+1) % 4 ))
        c=$(( (c+1) % 7 ))
        sleep 0.3
    done

    printf "\n"
    # 恢复原来的 INT 处理
    eval "$old_trap" 2>/dev/null || true
}