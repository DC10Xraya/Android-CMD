#resource/cmd_unzip.bash
# ---------- UNZIP/解压(支持多种格式) ----------
cmd_unzip() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -lt 2 ]; then
        err "用法: UNZIP <压缩文件> [-d 目标目录]"
        cecho "支持格式: zip, 7z, tar, tar.gz, tar.bz2, tar.xz, gz, bz2, xz"
        cecho "示例: UNZIP backup.zip"
        cecho "      UNZIP data.7z -d /sdcard/extract"
        return 1
    fi

    local archive="$1"
    shift
    local dest_dir=""

    while [ $# -gt 0 ]; do
        case "$1" in
            -d) dest_dir="$2"; shift 2 ;;
            *) err "未知参数: $1"; return 1 ;;
        esac
    done

    if [ ! -f "$archive" ]; then
        err "文件不存在: $archive"
        return 1
    fi

    if [ -n "$dest_dir" ]; then
        mkdir -p "$dest_dir" 2>/dev/null || { err "无法创建目录: $dest_dir"; return 1; }
    fi

    # 自动识别格式
    local format=""
    case "$archive" in
        *.zip) format="zip" ;;
        *.7z)  format="7z" ;;
        *.tar) format="tar" ;;
        *.tar.gz|*.tgz) format="tar.gz" ;;
        *.tar.bz2|*.tbz2) format="tar.bz2" ;;
        *.tar.xz|*.txz) format="tar.xz" ;;
        *.gz)  format="gz" ;;
        *.bz2) format="bz2" ;;
        *.xz)  format="xz" ;;
        *) err "无法识别压缩格式, 请检查扩展名"; return 1 ;;
    esac

    cecho "识别格式: $format"

    local cmd=""
    case "$format" in
        zip)
            if command -v unzip >/dev/null 2>&1; then
                cmd="unzip -q \"$archive\""
                [ -n "$dest_dir" ] && cmd="$cmd -d \"$dest_dir\""
            elif command -v busybox >/dev/null 2>&1 && busybox --list 2>/dev/null | grep -q unzip; then
                cmd="busybox unzip -q \"$archive\""
                [ -n "$dest_dir" ] && cmd="$cmd -d \"$dest_dir\""
            else
                err "未找到 unzip 命令"
                return 1
            fi
            ;;
        7z)
            if command -v 7z >/dev/null 2>&1; then
                cmd="7z x \"$archive\" -y"
                [ -n "$dest_dir" ] && cmd="$cmd -o\"$dest_dir\""
            elif command -v 7za >/dev/null 2>&1; then
                cmd="7za x \"$archive\" -y"
                [ -n "$dest_dir" ] && cmd="$cmd -o\"$dest_dir\""
            else
                err "未找到 7z 或 7za 命令"
                return 1
            fi
            ;;
        tar|tar.gz|tar.bz2|tar.xz)
            if ! command -v tar >/dev/null 2>&1; then
                err "未找到 tar 命令"
                return 1
            fi
            local tar_opts=""
            case "$format" in
                tar)      tar_opts="-xf" ;;
                tar.gz)   tar_opts="-xzf" ;;
                tar.bz2)  tar_opts="-xjf" ;;
                tar.xz)   tar_opts="-xJf" ;;
            esac
            cmd="tar $tar_opts \"$archive\""
            [ -n "$dest_dir" ] && cmd="$cmd -C \"$dest_dir\""
            ;;
        gz|bz2|xz)
            if [ -z "$dest_dir" ]; then
                dest_dir="."
            fi
            local base=$(basename "$archive")
            local out_name=""
            case "$format" in
                gz)  out_name="${base%.gz}"; cmd="gzip -d -c \"$archive\" > \"$dest_dir/$out_name\"" ;;
                bz2) out_name="${base%.bz2}"; cmd="bzip2 -d -c \"$archive\" > \"$dest_dir/$out_name\"" ;;
                xz)  out_name="${base%.xz}"; cmd="xz -d -c \"$archive\" > \"$dest_dir/$out_name\"" ;;
            esac
            if [ -f "$dest_dir/$out_name" ]; then
                confirm "目标文件 $dest_dir/$out_name 已存在, 覆盖吗?" || { cecho "跳过"; return 0; }
            fi
            ;;
        *)
            err "内部错误: 未知格式"
            return 1
            ;;
    esac

    eval "$cmd" 2>&1 | while IFS= read -r line; do cecho "$line"; done
    local ret=$?
    [ $ret -eq 0 ] && cecho "解压完成" || err "解压失败 (退出码: $ret)"
    return $ret
}