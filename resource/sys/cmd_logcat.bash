# resource/cmd_logcat.bash
cmd_logcat() {
    # 显示帮助(仅当 -h 或 --help)
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        err "此汉化帮助可能和您的系统选项不同, 仅供参考, 更多信息请使用c logcat --help"
        cecho -b -c 93 "默认启用彩色输出(-v color), 若要禁用, 请指定其他 -v 格式"
        cecho -b "用法: logcat [选项]... [过滤器]..."
        echo ""
        echo ""
        cecho -b -c 36 "通用选项："
        cecho "  -b <缓冲区>, --buffer=<缓冲区>"
        cecho "      指定环形缓冲区: main, system, radio, events, crash, default, all"
        cecho "  -c, --clear             清空日志并退出"
        cecho "  -d                      转储日志后退出(不阻塞)"
        cecho "  -L, --last              显示上次重启前的日志(pstore)"
        cecho "  --pid=<PID>             仅显示指定PID的日志"
        cecho "  --wrap                  休眠2小时或缓冲区将满时唤醒"
        echo ""
        cecho -b -c 36 "格式化选项："
        cecho "  -v, --format=<格式>     设置日志格式"
        cecho "      常用格式: color, brief, long, threadtime, time, raw, tag, process, thread"
        cecho "  -D, --dividers          缓冲区之间打印分隔线"
        cecho "  -B, --binary            二进制输出(会覆盖 -v)"
        cecho "  --proto                 protobuffer输出(会覆盖 -v)"
        echo ""
        cecho -b -c 36 "输出文件："
        cecho "  -f, --file=<文件>       写入文件"
        cecho "  -r, --rotate-kbytes=<KB>  每N KB轮转(需 -f)"
        cecho "  -n, --rotate-count=<N>  最大轮转文件数(默认4)"
        cecho "  --id=<标识>             文件签名变化时清除关联文件"
        echo ""
        cecho -b -c 36 "Logd控制(发送控制消息, 随后退出)："
        cecho "  -g, --buffer-size       获取缓冲区大小"
        cecho "  -G, --buffer-size=<大小>  设置缓冲区大小(可带K/M)"
        cecho "  -p, --prune             获取修剪规则"
        cecho "  -P, --prune='规则列表'  设置修剪规则"
        cecho "  -S, --statistics        输出统计信息"
        echo ""
        cecho -b -c 36 "过滤选项："
        cecho "  -s                      静默(默认过滤器 '*:S')"
        cecho "  -e, --regex=<正则>      仅匹配正则的行"
        cecho "  -m, --max-count=<N>     打印N行后退出"
        cecho "  --print                 配合 --regex 打印所有行但只计数匹配行"
        cecho "  -t <行数>               最近N行(隐含 -d)"
        cecho "  -T <行数>               最近N行(不隐含 -d)"
        cecho "  -t <时间>               自指定时间起(隐含 -d)"
        cecho "      时间格式: MM-DD hh:mm:ss.mmm 或 YYYY-MM-DD hh:mm:ss.mmm"
        cecho "  -T <时间>               同上但不隐含 -d"
        cecho "  --uid=<UID列表>         仅显示指定UID的日志"
        echo ""
        cecho -b -c 36 "过滤器规格(FILTERSPEC)："
        cecho "  形式为 <标签>[:优先级], 标签为日志组件(* 表示所有), 优先级："
        cecho "    V    详细(默认)"
        cecho "    D    调试(默认给 *)"
        cecho "    I    信息"
        cecho "    W    警告"
        cecho "    E    错误"
        cecho "    F    致命"
        cecho "    S    静默(禁止输出)"
        cecho "  * 单独表示 *:D, <标签> 单独表示 <标签>:V"
        cecho "  若命令行无 * 过滤器或 -s, 默认过滤器为 *:V"
        cecho "  示例: *:S MyTag 仅显示 MyTag, MyTag:S 屏蔽 MyTag"
        echo ""
        cecho -b -c 36 "格式详细说明(FORMAT)："
        cecho "  单一格式动词："
        cecho "    brief      显示优先级、标签和PID"
        cecho "    long       显示所有元数据, 消息间空行"
        cecho "    process    仅显示PID"
        cecho "    raw        仅显示原始消息"
        cecho "    tag        显示优先级和标签"
        cecho "    thread     显示优先级、PID和TID"
        cecho "    threadtime 显示日期、时间、优先级、标签、PID和TID(默认)"
        cecho "    time       显示日期、时间、优先级、标签和PID"
        cecho "  副词修饰符(可组合)："
        cecho "    color       不同优先级以不同颜色显示"
        cecho "    descriptive 显示事件描述"
        cecho "    epoch       时间显示为Unix秒"
        cecho "    monotonic   时间显示为自启动秒数"
        cecho "    printable   确保二进制内容转义"
        cecho "    uid         显示UID"
        cecho "    usec        微秒精度"
        cecho "    UTC         显示UTC时间"
        cecho "    year        显示年份"
        cecho "    zone        显示本地时区"
        echo ""
        cecho -c 93 "示例："
        cecho "  logcat -v threadtime -s MyTag"
        cecho "  logcat -b main -t 50"
        return 0
    fi

    # 自动添加 -v color(如果用户未指定 -v、-B、--binary、--proto)
    local has_format=0 has_binary=0
    local args=("$@")
    for i in "${!args[@]}"; do
        case "${args[$i]}" in
            -v|--format) has_format=1 ;;
            -B|--binary|--proto) has_binary=1 ;;
        esac
    done

    # 若未指定格式, 插入 -v color
    if [[ $has_format -eq 0 && $has_binary -eq 0 ]]; then
        set -- -v color "$@"
    fi

    # ----- 信号处理 -----
    local old_trap=$(trap -p INT)
    local child_pid=""
    local interrupted=0

    trap '
        interrupted=1
        if [ -n "$child_pid" ] && kill -0 "$child_pid" 2>/dev/null; then
            kill -TERM "$child_pid" 2>/dev/null
            local waited=0
            while kill -0 "$child_pid" 2>/dev/null && [ $waited -lt 3 ]; do
                sleep 0.1
                waited=$((waited + 1))
            done
            kill -KILL "$child_pid" 2>/dev/null
            wait "$child_pid" 2>/dev/null
        fi
        echo ""
        return 130
    ' INT

    # 后台运行 logcat(此时 $@ 已包含 -v color)
    logcat "$@" &
    child_pid=$!
    wait "$child_pid"
    local exit_code=$?

    # 恢复原 trap
    eval "$old_trap" 2>/dev/null || trap - INT

    return $exit_code
}