cmd_stat() {
        if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -eq 0 ]; then
        cecho -b "用法: STAT <文件>"
        return 0
    fi

    local file="$*"

    # 先判链接，再判存在
    local file_type
    if [[ -L "$file" ]]; then
        file_type="符号链接"
    elif [[ ! -e "$file" ]]; then
        err "文件不存在: $file"
        return 1
    elif [[ -f "$file" ]]; then
        file_type="常规文件"
    elif [[ -d "$file" ]]; then
        file_type="目录"
    elif [[ -b "$file" ]]; then
        file_type="块设备"
    elif [[ -c "$file" ]]; then
        file_type="字符设备"
    elif [[ -p "$file" ]]; then
        file_type="管道"
    elif [[ -S "$file" ]]; then
        file_type="套接字"
    else
        file_type="未知"
    fi

    # 系统 stat
    if command -v stat >/dev/null 2>&1 && stat -c '%a' -- "$file" >/dev/null 2>&1; then
        cecho "文件名: $file"
        cecho "类型: $file_type"
        local size_bytes
        size_bytes=$(stat -c '%s' -- "$file")
        local size_hr
        size_hr=$(numfmt --to=iec "$size_bytes" 2>/dev/null || echo "${size_bytes} 字节")
        cecho "大小: $size_hr ($size_bytes 字节)"
        cecho "权限: $(stat -c '%A' -- "$file") ($(stat -c '%a' -- "$file"))"
        cecho "所有者: $(stat -c '%U:%G' -- "$file")"
        cecho "Inode: $(stat -c '%i' -- "$file")"
        cecho "链接数: $(stat -c '%h' -- "$file")"
        cecho "修改时间: $(stat -c '%y' -- "$file" | cut -d'.' -f1)"
        cecho "访问时间: $(stat -c '%x' -- "$file" | cut -d'.' -f1)"
        cecho "改变时间: $(stat -c '%z' -- "$file" | cut -d'.' -f1)"
        return 0
    fi

    # 回退：ls
    local ls_out
    ls_out=$(ls -lid --time-style=+%Y-%m-%d_%H:%M:%S -- "$file" 2>/dev/null)
    if [[ -z "$ls_out" ]]; then
        err "无法使用 ls 读取文件信息"
        return 1
    fi

    local inode perms links owner group size mtime
    read -r inode perms links owner group size mtime _ <<< "$ls_out"

    # 八进制权限
    local perm_chars="${perms:1}"
    local u=0 g=0 o=0 extra=0
    [[ ${perm_chars:0:1} == r ]] && u=$((u+4))
    [[ ${perm_chars:1:1} == w ]] && u=$((u+2))
    [[ ${perm_chars:2:1} == [xs] ]] && u=$((u+1))
    [[ ${perm_chars:2:1} == s ]] && extra=$((extra+4))
    [[ ${perm_chars:3:1} == r ]] && g=$((g+4))
    [[ ${perm_chars:4:1} == w ]] && g=$((g+2))
    [[ ${perm_chars:5:1} == [xs] ]] && g=$((g+1))
    [[ ${perm_chars:5:1} == s ]] && extra=$((extra+2))
    [[ ${perm_chars:6:1} == r ]] && o=$((o+4))
    [[ ${perm_chars:7:1} == w ]] && o=$((o+2))
    [[ ${perm_chars:8:1} == [xt] ]] && o=$((o+1))
    [[ ${perm_chars:8:1} == t ]] && extra=$((extra+1))
    local octal_perm
    if (( extra )); then
        octal_perm=$(printf "%o%o%o%o" $extra $u $g $o)
    else
        octal_perm=$(printf "%o%o%o" $u $g $o)
    fi

    # 时间字段只取 $6
    local atime_str ctime_str
    atime_str=$(ls -lud --time-style=+%Y-%m-%d_%H:%M:%S -- "$file" 2>/dev/null | awk '{print $6}')
    ctime_str=$(ls -lcd --time-style=+%Y-%m-%d_%H:%M:%S -- "$file" 2>/dev/null | awk '{print $6}')
    [[ -z "$atime_str" ]] && atime_str="未知"
    [[ -z "$ctime_str" ]] && ctime_str="未知"

    local size_hr
    size_hr=$(numfmt --to=iec "$size" 2>/dev/null || echo "${size} 字节")

    cecho "文件名: $file"
    cecho "类型: $file_type"
    cecho "大小: $size_hr ($size 字节)"
    cecho "权限: $perms ($octal_perm)"
    cecho "所有者: $owner:$group"
    cecho "Inode: $inode"
    cecho "链接数: $links"
    cecho "修改时间: $mtime"
    cecho "访问时间: $atime_str"
    cecho "改变时间: $ctime_str"
}