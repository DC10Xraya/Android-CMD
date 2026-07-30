#resource/cmd_sha1.bash
cmd_sha1() {
    if [[ $# -eq 0 ]]; then
        err "用法: SHA1 <文件>"
        return 1
    fi
    local file="$1"
    if [[ ! -f "$file" ]]; then
        err "文件不存在: $file"
        return 1
    fi
    local sha_cmd=""
    if command -v sha1sum >/dev/null 2>&1; then
        sha_cmd="sha1sum"
    elif command -v busybox >/dev/null 2>&1 && busybox --list 2>/dev/null | grep -q sha1sum; then
        sha_cmd="busybox sha1sum"
    elif command -v openssl >/dev/null 2>&1; then
        sha_cmd="openssl sha1"
    else
        err "未找到 sha1sum 或 openssl 命令"
        return 1
    fi

    if [[ "$sha_cmd" == "openssl sha1" ]]; then
        openssl sha1 "$file" 2>&1 | cecho
    else
        $sha_cmd "$file" 2>&1 | cecho
    fi
    local ret=${PIPESTATUS[0]}
    [[ $ret -ne 0 ]] && err "SHA1 计算失败(错误码 $ret)"
    return $ret
}