#resource/cmd_base64.bash
cmd_base64() {
    local decode=0 file_mode=0 input=""
    local base64_cmd=""
    local args=()   # 收集非选项参数

    # 优先查找 base64 命令
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

    # 解析选项, 收集非选项参数到 args 数组
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

    # 字符串模式下, 合并所有参数为一个字符串(保留空格)
    if [[ $file_mode -eq 0 ]]; then
        if [[ ${#args[@]} -eq 0 ]]; then
            err "用法: BASE64/B64 [-d] <字符串>/[-d] -f <文件>"
            return 1
        fi
        input="${args[*]}"   # 空格分隔所有参数
    fi

    # 检查输入
    if [[ -z "$input" ]]; then
        err "用法: BASE64/B64 [-d] <字符串>/[-d] -f <文件>"
        return 1
    fi

    local opts=""
    [[ $decode -eq 1 ]] && opts="-d"

    # 临时文件用于字符串模式
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

    # 执行命令
    if [[ "$base64_cmd" == "openssl base64" ]]; then
        if [[ $decode -eq 1 ]]; then
            openssl base64 -d < "$input" 2>&1 | cecho
        else
            openssl base64 -e < "$input" 2>&1 | cecho
        fi
        local ret=${PIPESTATUS[0]}
    else
        $base64_cmd $opts < "$input" 2>&1 | cecho
        local ret=${PIPESTATUS[0]}
    fi

    [[ -n "$tmp_file" ]] && rm -f "$tmp_file"

    if [[ $ret -ne 0 ]]; then
        err "Base64 操作失败(错误码 $ret)"
        return $ret
    fi
    return 0
}