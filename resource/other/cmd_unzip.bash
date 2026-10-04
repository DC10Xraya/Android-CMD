#resource/cmd_unzip.bash
# ---------- UNZIP/解压(支持多种格式) ----------
cmd_unzip() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        cecho -b "用法: UNZIP <压缩文件> [-d 目标目录]"
        cecho "支持格式: zip, 7z, tar, tar.gz, tar.bz2, tar.xz, gz, bz2, xz"
        cecho "示例: UNZIP backup.zip"
        cecho "      UNZIP data.7z -d /sdcard/extract"
        cecho "      UNZIP log.gz                    # 解到当前目录"
        return 0
    fi

    if [ $# -lt 1 ]; then
        err "缺少参数, 使用 UNZIP -h 查看帮助"
        return 1
    fi

    local archive="$1"
    shift
    local dest_dir=""

    while [ $# -gt 0 ]; do
        case "$1" in
            -d)
                if [ $# -lt 2 ]; then err "参数 -d 需要目录路径"; return 1; fi
                dest_dir="$2"; shift 2 ;;
            -*)
                err "未知参数: $1, 使用 UNZIP -h 查看帮助"
                return 1 ;;
            *)
                err "多余参数: $1"
                return 1 ;;
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

    local ret=0

    case "$format" in
        zip)
            if command -v unzip >/dev/null 2>&1; then
                if [ -n "$dest_dir" ]; then
                    unzip -q "$archive" -d "$dest_dir" 2>&1 | while IFS= read -r line; do cecho "$line"; done
                else
                    unzip -q "$archive" 2>&1 | while IFS= read -r line; do cecho "$line"; done
                fi
                ret=${PIPESTATUS[0]}
            elif command -v busybox >/dev/null 2>&1 && busybox --list 2>/dev/null | grep -q '^unzip$'; then
                if [ -n "$dest_dir" ]; then
                    busybox unzip -q "$archive" -d "$dest_dir" 2>&1 | while IFS= read -r line; do cecho "$line"; done
                else
                    busybox unzip -q "$archive" 2>&1 | while IFS= read -r line; do cecho "$line"; done
                fi
                ret=${PIPESTATUS[0]}
            else
                err "未找到 unzip 命令"
                return 1
            fi
            ;;

        7z)
            local z7=""
            if command -v 7z >/dev/null 2>&1; then
                z7="7z"
            elif command -v 7za >/dev/null 2>&1; then
                z7="7za"
            else
                err "未找到 7z 或 7za 命令"
                return 1
            fi
            if [ -n "$dest_dir" ]; then
                "$z7" x "$archive" -y "-o$dest_dir" 2>&1 | while IFS= read -r line; do cecho "$line"; done
            else
                "$z7" x "$archive" -y 2>&1 | while IFS= read -r line; do cecho "$line"; done
            fi
            ret=${PIPESTATUS[0]}
            ;;

        tar)
            if ! command -v tar >/dev/null 2>&1; then
                err "未找到 tar 命令"
                return 1
            fi
            if [ -n "$dest_dir" ]; then
                tar -xf "$archive" -C "$dest_dir" 2>&1 | while IFS= read -r line; do cecho "$line"; done
            else
                tar -xf "$archive" 2>&1 | while IFS= read -r line; do cecho "$line"; done
            fi
            ret=${PIPESTATUS[0]}
            ;;

        tar.gz)
            if ! command -v tar >/dev/null 2>&1; then
                err "未找到 tar 命令"
                return 1
            fi
            if [ -n "$dest_dir" ]; then
                tar -xzf "$archive" -C "$dest_dir" 2>&1 | while IFS= read -r line; do cecho "$line"; done
            else
                tar -xzf "$archive" 2>&1 | while IFS= read -r line; do cecho "$line"; done
            fi
            ret=${PIPESTATUS[0]}
            ;;

        tar.bz2)
            if ! command -v tar >/dev/null 2>&1; then
                err "未找到 tar 命令"
                return 1
            fi
            if [ -n "$dest_dir" ]; then
                tar -xjf "$archive" -C "$dest_dir" 2>&1 | while IFS= read -r line; do cecho "$line"; done
            else
                tar -xjf "$archive" 2>&1 | while IFS= read -r line; do cecho "$line"; done
            fi
            ret=${PIPESTATUS[0]}
            ;;

        tar.xz)
            if ! command -v tar >/dev/null 2>&1; then
                err "未找到 tar 命令"
                return 1
            fi
            if [ -n "$dest_dir" ]; then
                tar -xJf "$archive" -C "$dest_dir" 2>&1 | while IFS= read -r line; do cecho "$line"; done
            else
                tar -xJf "$archive" 2>&1 | while IFS= read -r line; do cecho "$line"; done
            fi
            ret=${PIPESTATUS[0]}
            ;;

        gz|bz2|xz)
            [ -z "$dest_dir" ] && dest_dir="."
            local base=$(basename "$archive")
            local out_name=""
            local decomp=""
            case "$format" in
                gz)  out_name="${base%.gz}";  decomp="gzip" ;;
                bz2) out_name="${base%.bz2}"; decomp="bzip2" ;;
                xz)  out_name="${base%.xz}";  decomp="xz" ;;
            esac
            if [ -z "$out_name" ] || [ "$out_name" = "$base" ]; then
                err "无法推断解压后的文件名"
                return 1
            fi
            if ! command -v "$decomp" >/dev/null 2>&1; then
                err "未找到 $decomp 命令"
                return 1
            fi
            if [ -e "$dest_dir/$out_name" ]; then
                if ! confirm "目标文件 $dest_dir/$out_name 已存在, 覆盖吗?"; then
                    cecho "跳过"
                    return 0
                fi
            fi
            "$decomp" -d -c "$archive" > "$dest_dir/$out_name"
            ret=$?
            ;;

        *)
            err "内部错误: 未知格式"
            return 1
            ;;
    esac

    if [ $ret -eq 0 ]; then
        cecho "解压完成"
    else
        err "解压失败 (退出码: $ret)"
    fi
    return $ret
}