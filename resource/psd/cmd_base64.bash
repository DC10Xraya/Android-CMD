#resource/cmd_base64.bash
cmd_base64() {
    # 显示帮助
    if [[ $# -eq 0 ]] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
        cecho "用法: BASE64/B64 [-d] <字符串> / [-d] -f <文件>"
        cecho "  -d, --decode  解码 (Base64 → 原始数据)"
        cecho "  -f, --file    从文件读取 (默认从参数读取字符串)"
        cecho "  -h, --help    显示此帮助"
        return 0
    fi

    local decode=0 file_mode=0 input=""
    local base64_cmd=""
    local args=()

    if command -v base64 >/dev/null 2>&1; then
        base64_cmd="base64"
    elif command -v openssl >/dev/null 2>&1; then
        base64_cmd="openssl base64"
    elif command -v busybox >/dev/null 2>&1 && busybox --list 2>/dev/null | grep -q base64; then
        base64_cmd="busybox base64"
    else
        err "未找到 base64 命令(请安装 busybox、coreutils 或 openssl)"
        return 1
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--decode) decode=1; shift ;;
            -f|--file)   file_mode=1; input="$2"; shift 2 ;;
            --) shift; break ;;
            -*)
                err "未知选项: $1"
                return 1
                ;;
            *)
                args+=("$1")
                shift
                ;;
        esac
    done

    if [[ $file_mode -eq 0 ]]; then
        if [[ ${#args[@]} -eq 0 ]]; then
            err "用法: BASE64/B64 [-d] <字符串>/[-d] -f <文件>"
            return 1
        fi
        input="${args[*]}"
    fi

    if [[ -z "$input" ]]; then
        err "用法: BASE64/B64 [-d] <字符串>/[-d] -f <文件>"
        return 1
    fi

    local tmp_file=""
    if [[ $file_mode -eq 0 ]]; then
        tmp_file=$(mktemp 2>/dev/null)
        if [[ -z "$tmp_file" ]] || [[ ! -f "$tmp_file" ]]; then
            err "无法创建临时文件"
            return 1
        fi
        printf '%s' "$input" > "$tmp_file"
        input="$tmp_file"
    elif [[ ! -f "$input" ]]; then
        err "文件不存在: $input"
        return 1
    fi

    # 统一使用 cat 直接输出，避免管道被截断
    local ret=0
    if [[ "$base64_cmd" == "openssl base64" ]]; then
        if [[ $decode -eq 1 ]]; then
            openssl base64 -d < "$input" 2>/dev/null | cat
            ret=${PIPESTATUS[0]}
        else
            openssl base64 -e < "$input" 2>/dev/null | cat
            ret=${PIPESTATUS[0]}
        fi
    else
        if [[ $decode -eq 1 ]]; then
            $base64_cmd -d < "$input" 2>/dev/null | cat
            ret=${PIPESTATUS[0]}
        else
            $base64_cmd < "$input" 2>/dev/null | cat
            ret=${PIPESTATUS[0]}
        fi
    fi

    [[ -n "$tmp_file" ]] && rm -f "$tmp_file"

    if [[ $ret -ne 0 ]]; then
        err "Base64 操作失败(错误码 $ret)"
        return $ret
    fi
    return 0
}