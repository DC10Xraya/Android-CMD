# resource/cmd_stat.bash
# ---------- STAT 显示文件信息 ----------
cmd_stat() {
    # 无参数
    if [ $# -eq 0 ]; then
        err "$USAGE_HINT"
        return 0
    fi
    # -h/--help
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        err "用法: STAT <文件>"
        return 0
    fi

    local file="$*"
    if [[ ! -e "$file" ]]; then
        err "文件不存在: $file"
        return 1
    fi

    local file_type="未知"
    if [[ -f "$file" ]]; then
        file_type="常规文件"
    elif [[ -d "$file" ]]; then
        file_type="目录"
    elif [[ -L "$file" ]]; then
        file_type="符号链接"
    elif [[ -b "$file" ]]; then
        file_type="块设备"
    elif [[ -c "$file" ]]; then
        file_type="字符设备"
    elif [[ -p "$file" ]]; then
        file_type="管道"
    elif [[ -S "$file" ]]; then
        file_type="套接字"
    fi

    # 尝试使用系统 stat
    if command -v stat >/dev/null 2>&1 && stat -c '%a' "$file" >/dev/null 2>&1; then
        cecho "文件名: $(stat -c '%n' "$file")"
        cecho "类型: $file_type"
        local size_bytes=$(stat -c '%s' "$file")
        local size_hr=$(numfmt --to=iec "$size_bytes" 2>/dev/null || echo "${size_bytes} 字节")
        cecho "大小: $size_hr ($size_bytes 字节)"
        cecho "权限: $(stat -c '%A' "$file") ($(stat -c '%a' "$file"))"
        cecho "所有者: $(stat -c '%U:%G' "$file")"
        cecho "Inode: $(stat -c '%i' "$file")"
        cecho "链接数: $(stat -c '%h' "$file")"
        cecho "修改时间: $(stat -c '%y' "$file" | cut -d'.' -f1 | sed 's/ /  /')"
        cecho "访问时间: $(stat -c '%x' "$file" | cut -d'.' -f1 | sed 's/ /  /')"
        cecho "改变时间: $(stat -c '%z' "$file" | cut -d'.' -f1 | sed 's/ /  /')"
        return 0
    fi

    # 回退：使用 ls -li
    local inode perms owner group size mtime atime ctime
    local ls_out
    ls_out=$(ls -li --time-style=+%Y-%m-%d_%H:%M:%S "$file" 2>/dev/null)
    if [[ -z "$ls_out" ]]; then
        err "无法使用 ls 读取文件信息"
        return 1
    fi

    read -r inode perms _ owner group size mtime _ <<< "$ls_out" 2>/dev/null
    local perm_chars="${perms:1}"
    local user_perm="${perm_chars:0:3}"
    local group_perm="${perm_chars:3:3}"
    local other_perm="${perm_chars:6:3}"
    local u_val=0 g_val=0 o_val=0
    [[ ${user_perm:0:1} == 'r' ]] && u_val=$((u_val+4))
    [[ ${user_perm:1:1} == 'w' ]] && u_val=$((u_val+2))
    [[ ${user_perm:2:1} == 'x' ]] && u_val=$((u_val+1))
    [[ ${group_perm:0:1} == 'r' ]] && g_val=$((g_val+4))
    [[ ${group_perm:1:1} == 'w' ]] && g_val=$((g_val+2))
    [[ ${group_perm:2:1} == 'x' ]] && g_val=$((g_val+1))
    [[ ${other_perm:0:1} == 'r' ]] && o_val=$((o_val+4))
    [[ ${other_perm:1:1} == 'w' ]] && o_val=$((o_val+2))
    [[ ${other_perm:2:1} == 'x' ]] && o_val=$((o_val+1))
    local octal_perm=$(printf "%o%o%o" $u_val $g_val $o_val)

    local atime_str=$(ls -lu --time-style=+%Y-%m-%d_%H:%M:%S "$file" 2>/dev/null | awk '{print $6, $7}')
    local ctime_str=$(ls -lc --time-style=+%Y-%m-%d_%H:%M:%S "$file" 2>/dev/null | awk '{print $6, $7}')
    [[ -z "$atime_str" ]] && atime_str="未知"
    [[ -z "$ctime_str" ]] && ctime_str="未知"

    local size_hr=$(numfmt --to=iec "$size" 2>/dev/null || echo "${size} 字节")

    cecho "文件名: $file"
    cecho "类型: $file_type"
    cecho "大小: $size_hr ($size 字节)"
    cecho "权限: $perms ($octal_perm)"
    cecho "所有者: $owner:$group"
    cecho "Inode: $inode"
    cecho "链接数: (未知,ls 输出可能缺此项)"
    cecho "修改时间: $mtime"
    cecho "访问时间: $atime_str"
    cecho "改变时间: $ctime_str"
}