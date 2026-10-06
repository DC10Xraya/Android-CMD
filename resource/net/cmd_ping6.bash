cmd_ping6() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -eq 0 ]; then
        cecho -b "用法: PING6 [-n] [-nf/-inf] [-f] [-w] [-W] [-i] [-s] [-I] [-t] [-b] [-B] [-S] [-r] [-L] [-D] [-Dp] [-v] [-q] [-V] <域名/IP>"
        cecho "参数说明: "
        cecho "-n 次数          指定发送的次数(正整数,默认4)"
        cecho "-nf/-inf         无限制发送(不限制包数)"
        cecho "-f               洪水模式(尝试真实洪水, 失败则模拟)"
        cecho "-w 总超时(s)     整个过程的总时间限制(正数)"
        cecho "-W 单包超时(s)   每个包的超时时间(正整数,默认1)"
        cecho "-i 间隔(s)       成功收到回复后等待的间隔时间(支持浮点数,最小0.2秒,默认0.5)"
        cecho "-s 包大小(字节)  发送的数据包大小(1-65507,默认56)"
        cecho "-I 接口/IP       指定源接口或源IP地址"
        cecho "-t TTL           设置 IP 生存时间 (1-255)"
        cecho "-b               允许 ping 广播地址"
        cecho "-B               不改变探测包的源地址"
        cecho "-S 缓冲区        设置发送缓冲区大小(字节)"
        cecho "-r               绕过路由表直接发送到本地接口"
        cecho "-L               抑制组播回环"
        cecho "-D               显示 Unix 时间戳"
        cecho "-Dp [格式]       显示人性化时间戳(格式可省略, 默认 HH:mm:ss)"
        cecho "占位符: YYYY=年  YY=两位年  MM=月  DD=日"
        cecho "       HH=24时  hh=12时  mm=分  ss=秒"
        cecho "       AA=星期全称  aa=星期缩写"
        cecho "       同时支持系统 date 格式"
        cecho "-v               直接显示系统的原始输出"
        cecho "-q               不显示每次回复, 只输出统计信息"
        cecho "-V               显示 PING 函数版本和底层 ping 版本"
        return 0
    fi

    # ---- 过滤参数 ----
    local -a args=()
     local a
     for a in "$@"; do
        case "$a" in
            -4) err "未知参数: -4"; return 1 ;;
            -6) err "未知参数: -6"; return 1 ;;
            *)  args+=("$a") ;;
         esac
    done

    cmd_ping -6 "${args[@]}"
}