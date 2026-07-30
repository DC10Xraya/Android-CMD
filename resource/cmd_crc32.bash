#resource/cmd_crc32.bash
cmd_crc32() {
    if [[ $# -eq 0 ]]; then
        err "用法: CRC32 <文件>"
        return 1
    fi
    local file="$1"
    if [[ ! -f "$file" ]]; then
        err "文件不存在: $file"
        return 1
    fi
    if ! command -v cksum >/dev/null 2>&1; then
        err "未找到 cksum 命令"
        return 1
    fi
    cksum "$file" 2>&1 | cecho
    local ret=${PIPESTATUS[0]}
    [[ $ret -ne 0 ]] && err "CRC 计算失败(错误码 $ret)"
    return $ret
}