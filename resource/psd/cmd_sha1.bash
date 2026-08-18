# ---------- SHA1 函数 ----------
cmd_sha1() {
    # 显示帮助
    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        cecho -b "用法: SHA1 [选项]"
        cecho "  -f <文件>    计算文件的 SHA1 哈希"
        cecho "  -d <字符串>  计算字符串的 SHA1 哈希"
        cecho "  -h, --help   显示此帮助"
        err "警告: SHA1 已不安全, 仅用于非安全场景"
        return 0
    fi

    local mode=""
    local data=""
    while [ $# -gt 0 ]; do
        case "$1" in
            -f)
                if [ -z "$2" ]; then
                    err "缺少文件参数"
                    return 1
                fi
                mode="file"
                data="$2"
                shift 2
                ;;
            -d)
                if [ -z "$2" ]; then
                    err "缺少字符串参数"
                    return 1
                fi
                mode="string"
                data="$2"
                shift 2
                ;;
            *)
                err "未知选项: $1, 使用 SHA1 -h 查看帮助"
                return 1
                ;;
        esac
    done

    if [ -z "$mode" ] || [ -z "$data" ]; then
        err "缺少参数, 使用 SHA1 -h 查看帮助"
        return 1
    fi

    # 检测可用的 SHA1 命令
    local cmd_sha=""
    if command -v sha1sum >/dev/null 2>&1; then
        cmd_sha="sha1sum"
    elif command -v busybox >/dev/null 2>&1 && busybox --list 2>/dev/null | grep -q sha1sum; then
        cmd_sha="busybox sha1sum"
    elif command -v openssl >/dev/null 2>&1; then
        cmd_sha="openssl dgst -sha1"
    else
        err "未找到可用的 SHA1 计算工具 (sha1sum, busybox, openssl)"
        return 1
    fi

    local hash=""
    if [ "$mode" = "file" ]; then
        if [ ! -f "$data" ]; then
            err "文件不存在: $data"
            return 1
        fi
        if [[ "$cmd_sha" == openssl* ]]; then
            hash=$($cmd_sha "$data" 2>/dev/null | awk '{print $NF}')
        else
            hash=$($cmd_sha "$data" 2>/dev/null | awk '{print $1}')
        fi
    else
        # 字符串模式（注意 -n 避免换行）
        if [[ "$cmd_sha" == openssl* ]]; then
            hash=$(printf "%s" "$data" | $cmd_sha 2>/dev/null | awk '{print $NF}')
        else
            hash=$(printf "%s" "$data" | $cmd_sha 2>/dev/null | awk '{print $1}')
        fi
    fi

    if [ -n "$hash" ]; then
        cecho "$hash"
    else
        err "计算 SHA1 失败"
        return 1
    fi
}