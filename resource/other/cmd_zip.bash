#resource/cmd_zip.bash
# ---------- ZIP/压缩(支持多种格式和压缩率) ----------
cmd_zip() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -lt 1 ]; then
        err "用法: ZIP <输出文件> <源文件/目录...> [-f 格式] [-l 级别]"
        cecho "  格式: zip, 7z, tar, tar.gz, tar.bz2, tar.xz (默认根据扩展名自动判断)"
        cecho "  级别: 0-9 (默认 6)"
        cecho "示例: ZIP backup.zip /sdcard/DCIM"
        cecho "      ZIP data.7z /data/local -f 7z -l 9"
        return 1
    fi

    local output="$1"
    shift
    local sources=()
    local format=""
    local level="6"

    while [ $# -gt 0 ]; do
        case "$1" in
            -f) format="$2"; shift 2 ;;
            -l) level="$2"; shift 2 ;;
            *) sources+=("$1"); shift ;;
        esac
    done

    if [ ${#sources[@]} -eq 0 ]; then
        err "至少指定一个源文件/目录"
        return 1
    fi

    # 自动检测格式
    if [ -z "$format" ]; then
        case "$output" in
            *.zip) format="zip" ;;
            *.7z)  format="7z" ;;
            *.tar) format="tar" ;;
            *.tar.gz|*.tgz) format="tar.gz" ;;
            *.tar.bz2|*.tbz2) format="tar.bz2" ;;
            *.tar.xz|*.txz) format="tar.xz" ;;
            *.gz)  format="gz" ;;
            *.bz2) format="bz2" ;;
            *.xz)  format="xz" ;;
            *) err "无法从扩展名判断格式, 请使用 -f 指定"; return 1 ;;
        esac
    fi

    cecho "压缩格式: $format, 级别: $level"
    cecho "输出文件: $output"

    local cmd=""
    case "$format" in
        zip)
            if command -v zip >/dev/null 2>&1; then
                cmd="zip -r -$level \"$output\""
            elif command -v busybox >/dev/null 2>&1 && busybox --list 2>/dev/null | grep -q zip; then
                cmd="busybox zip -r -$level \"$output\""
            else
                err "未找到 zip 命令"
                return 1
            fi
            for src in "${sources[@]}"; do
                cmd="$cmd \"$src\""
            done
            ;;
        7z)
            if command -v 7z >/dev/null 2>&1; then
                cmd="7z a -t7z -mx=$level \"$output\""
            elif command -v 7za >/dev/null 2>&1; then
                cmd="7za a -t7z -mx=$level \"$output\""
            else
                err "未找到 7z 或 7za 命令 (请安装 p7zip)"
                return 1
            fi
            for src in "${sources[@]}"; do
                cmd="$cmd \"$src\""
            done
            ;;
        tar|tar.gz|tar.bz2|tar.xz)
            if ! command -v tar >/dev/null 2>&1; then
                err "未找到 tar 命令"
                return 1
            fi
            local tar_opts=""
            case "$format" in
                tar)      tar_opts="-cf" ;;
                tar.gz)   tar_opts="-czf"; export GZIP="-$level" ;;
                tar.bz2)  tar_opts="-cjf"; export BZIP2="-$level" ;;
                tar.xz)   tar_opts="-cJf"; export XZ_OPT="-$level" ;;
            esac
            cmd="tar $tar_opts \"$output\""
            for src in "${sources[@]}"; do
                cmd="$cmd \"$src\""
            done
            ;;
        gz|bz2|xz)
            if [ ${#sources[@]} -ne 1 ]; then
                err "$format 格式只能压缩单个文件"
                return 1
            fi
            local src="${sources[0]}"
            if [ ! -f "$src" ]; then
                err "源文件不存在: $src"
                return 1
            fi
            case "$format" in
                gz)  cmd="gzip -$level -c \"$src\" > \"$output\"" ;;
                bz2) cmd="bzip2 -$level -c \"$src\" > \"$output\"" ;;
                xz)  cmd="xz -$level -c \"$src\" > \"$output\"" ;;
            esac
            ;;
        *)
            err "不支持的格式: $format"
            return 1
            ;;
    esac

    eval "$cmd" 2>&1 | while IFS= read -r line; do cecho "$line"; done
    local ret=$?
    unset GZIP BZIP2 XZ_OPT 2>/dev/null
    [ $ret -eq 0 ] && cecho "压缩完成" || err "压缩失败 (退出码: $ret)"
    return $ret
}