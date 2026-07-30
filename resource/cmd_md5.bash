#resource/cmd_md5.bash
cmd_md5() {
    if [[ $# -eq 0 ]]; then
        err "用法: MD5 <文件>"
        return 1
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

    if [[ "$md5_cmd" == "openssl md5" ]]; then
        openssl md5 "$file" 2>&1 | cecho
    else
        $md5_cmd "$file" 2>&1 | cecho
    fi
    local ret=${PIPESTATUS[0]}
    [[ $ret -ne 0 ]] && err "MD5 计算失败(错误码 $ret)"
    return $ret
}