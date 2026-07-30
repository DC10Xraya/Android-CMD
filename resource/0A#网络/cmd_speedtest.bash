#resource/cmd_speedtest.bash
# ---------- 网络测速(修复权限问题) ----------
cmd_speedtest() {
    local url="https://speed.cloudflare.com/__down?bytes=10000000"
    local timeout_sec=""

    while [ $# -gt 0 ]; do
        case "$1" in
            -u|--url)   url="$2"; shift 2 ;;
            -t|--timeout) timeout_sec="$2"; shift 2 ;;
            -h|--help)
                cecho "用法: SPEEDTEST [-u <URL>] [-t <超时秒>]"
                cecho "  -u  指定测速文件URL (默认: $url)"
                cecho "  -t  超时时间 (秒, 默认无超时)"
                return 0
                ;;
            *) shift ;;
        esac
    done

    # 选择下载工具
    local downloader=""
    local download_cmd=""
    if command -v curl >/dev/null 2>&1; then
        downloader="curl"
        download_cmd="curl -L -o \"\$tmpfile\" --connect-timeout 5"
        [ -n "$timeout_sec" ] && download_cmd="$download_cmd --max-time $timeout_sec"
        download_cmd="$download_cmd \"$url\" 2>/dev/null"
    elif command -v wget >/dev/null 2>&1; then
        downloader="wget"
        download_cmd="wget -q -O \"\$tmpfile\" --tries=1"
        [ -n "$timeout_sec" ] && download_cmd="$download_cmd --timeout=$timeout_sec"
        download_cmd="$download_cmd \"$url\" 2>/dev/null"
    else
        err "未找到 curl 或 wget, 无法测速"
        return 1
    fi

    # 临时文件目录(确保可写)
    local tmp_base="${TMP_DIR:-/storage/emulated/0/tmp}"
    mkdir -p "$tmp_base" 2>/dev/null || { err "无法创建临时目录"; return 1; }
    local tmpfile=$(mktemp -p "$tmp_base" "speedtest_XXXXXX" 2>/dev/null)
    [ -z "$tmpfile" ] && tmpfile="$tmp_base/speedtest_$$.tmp"
    touch "$tmpfile" 2>/dev/null || { err "无法创建临时文件"; return 1; }

    # 信号处理
    local old_trap=$(trap -p INT)
    local interrupted=0
    trap 'interrupted=1; rm -f "$tmpfile" 2>/dev/null; return 130' INT

    cecho "开始网络测速..."
    [ -n "$timeout_sec" ] && cecho "超时限制: ${timeout_sec}s"
    cecho "URL: $url"
    cecho "使用工具: $downloader"
    echo ""

    local start_time=$(date +%s%N 2>/dev/null || date +%s)
    eval "$download_cmd"
    local exit_code=$?
    local end_time=$(date +%s%N 2>/dev/null || date +%s)

    if [ $interrupted -eq 1 ]; then
        rm -f "$tmpfile" 2>/dev/null
        eval "$old_trap" 2>/dev/null || trap - INT
        return 130
    fi

    # 错误判断
    if [ $exit_code -ne 0 ]; then
        rm -f "$tmpfile" 2>/dev/null
        if [ -n "$timeout_sec" ]; then
            if [ "$downloader" = "curl" ] && [ $exit_code -eq 28 ]; then
                err "下载超时"
                eval "$old_trap" 2>/dev/null || trap - INT
                return 1
            elif [ "$downloader" = "wget" ] && [ $exit_code -eq 4 -o $exit_code -eq 8 ]; then
                err "下载超时"
                eval "$old_trap" 2>/dev/null || trap - INT
                return 1
            fi
        fi
        err "下载失败(退出码: $exit_code)"
        eval "$old_trap" 2>/dev/null || trap - INT
        return 1
    fi

    # 检查文件
    if [ ! -f "$tmpfile" ] || [ ! -s "$tmpfile" ]; then
        rm -f "$tmpfile" 2>/dev/null
        err "下载文件为空或不存在"
        eval "$old_trap" 2>/dev/null || trap - INT
        return 1
    fi

    # 计算速度
    local actual_size=$(stat -c%s "$tmpfile" 2>/dev/null || wc -c < "$tmpfile" 2>/dev/null)
    rm -f "$tmpfile" 2>/dev/null

    local elapsed_sec
    if [[ "$start_time" =~ ^[0-9]+$ ]] && [[ "$end_time" =~ ^[0-9]+$ ]]; then
        elapsed_sec=$(( (end_time - start_time) / 1000000000 ))
        [ "$elapsed_sec" -eq 0 ] && elapsed_sec=1
    else
        elapsed_sec=$((end_time - start_time))
        [ "$elapsed_sec" -eq 0 ] && elapsed_sec=1
    fi

    local speed_mbps=$(echo "scale=2; ($actual_size / 1048576) / $elapsed_sec" | bc 2>/dev/null)
    [ -z "$speed_mbps" ] && speed_mbps=0

    local icon="🔴"
    if (( $(echo "$speed_mbps > 5" | bc -l) )); then
        icon="🟢"
    elif (( $(echo "$speed_mbps > 2" | bc -l) )); then
        icon="🟡"
    fi

    cecho "----------------------------------------"
    cecho "下载文件大小: $(numfmt --to=iec "$actual_size" 2>/dev/null || echo "${actual_size} 字节")"
    cecho "耗时: ${elapsed_sec} 秒"
    cecho "平均速度: ${speed_mbps} MB/s  $icon"
    cecho "----------------------------------------"

    eval "$old_trap" 2>/dev/null || trap - INT
    return 0
}
