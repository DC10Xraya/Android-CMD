#resource/cmd_md5.bash
cmd_md5() {
    if [[ $# -eq 0 ]] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
        cecho "用法: MD5 <文件>"
        cecho "计算文件的 MD5 哈希 (输出 32 位十六进制)"
        err "警告: MD5 已不安全，仅用于非安全场景 (如快速去重)"
        return 0
    fi

    local file="$1"
    if [[ ! -f "$file" ]]; then
        err "文件不存在: $file"
        return 1
    fi

    local md5_cmd=""
    if command -v md5sum >/dev/null 2>&1; then
        md5_cmd="md5sum"
    elif command -v busybox >/dev/null 2>&1 && busybox --list 2>/dev/null | grep -q md5sum; then
        md5_cmd="busybox md5sum"
    elif command -v openssl >/dev/null 2>&1; then
        md5_cmd="openssl md5"
    else
        err "未找到 md5sum 或 openssl 命令"
        return 1
    fi

    local hash=""
    if [[ "$md5_cmd" == "openssl md5" ]]; then
        hash=$(openssl md5 "$file" 2>&1)
        if [[ $? -ne 0 ]]; then
            err "openssl 执行失败: $hash"
            return 1
        fi
        hash=$(echo "$hash" | awk '{print $NF}')
    else
        hash=$($md5_cmd "$file" 2>&1)
        if [[ $? -ne 0 ]]; then
            err "$md5_cmd 执行失败: $hash"
            return 1
        fi
        hash=$(echo "$hash" | awk '{print $1}')
    fi

    if [[ -z "$hash" ]]; then
        err "MD5 提取失败"
        return 1
    fi

    cecho "$hash"
    return 0
}