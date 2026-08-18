#resource/cmd_crc32.bash
cmd_crc32() {
    if [[ $# -eq 0 ]] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
        cecho "用法: CRC32 <文件>"
        cecho "计算文件的 CRC32 校验和 (输出十六进制, 8位大写)"
        return 0
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

    local crc_output
    crc_output=$(cksum "$file" 2>&1)
    if [[ $? -ne 0 ]]; then
        err "cksum 执行失败: $crc_output"
        return 1
    fi

    local crc_dec=$(echo "$crc_output" | awk '{print $1}')
    if [[ -z "$crc_dec" ]]; then
        err "CRC 提取失败"
        return 1
    fi

    # 直接 printf 输出，不带颜色，避免 cecho 干扰
    printf "%08X  %s\n" "$crc_dec" "$file"
    return 0
}