#resource/cmd_zip.bash
# ---------- ZIP/压缩(支持多种格式和压缩率) ----------
cmd_zip() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        cecho -b "用法: ZIP <输出文件> <源文件/目录...> [-f 格式] [-l 级别]"
        cecho "  格式: zip, 7z, tar, tar.gz, tar.bz2, tar.xz, gz, bz2, xz"
        cecho "        (默认根据输出扩展名自动判断)"
        cecho "  级别: 0-9 (默认 6)"
        cecho "示例: ZIP backup.zip /sdcard/DCIM"
        cecho "      ZIP data.7z /data/local -f 7z -l 9"
        cecho "      ZIP out.tar.gz dir1 dir2 -l 9"
        return 0
    fi

    if [ $# -lt 1 ]; then
        err "缺少参数, 使用 ZIP -h 查看帮助"
        return 1
    fi

    local output="$1"
    shift
    local sources=()
    local format=""
    local level="6"

    while [ $# -gt 0 ]; do
        case "$1" in
            -f)
                if [ $# -lt 2 ]; then err "参数 -f 需要格式名"; return 1; fi
                format="$2"; shift 2 ;;
            -l)
                if [ $# -lt 2 ]; then err "参数 -l 需要级别(0-9)"; return 1; fi
                level="$2"; shift 2 ;;
            -*)
                err "未知参数: $1, 使用 ZIP -h 查看帮助"
                return 1 ;;
            *)
                sources+=("$1"); shift ;;
        esac
    done

    if [ ${#sources[@]} -eq 0 ]; then
        err "至少指定一个源文件/目录"
        return 1
    fi

    if ! [[ "$level" =~ ^[0-9]$ ]]; then
        err "压缩级别必须是 0-9 之间的整数"
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

    local ret=0

    case "$format" in
        zip)
            if command -v zip >/dev/null 2>&1; then
                zip -r "-$level" "$output" "${sources[@]}" 2>&1 | while IFS= read -r line; do cecho "$line"; done
                ret=${PIPESTATUS[0]}
            elif command -v busybox >/dev/null 2>&1 && busybox --list 2>/dev/null | grep -q '^zip$'; then
                busybox zip -r "-$level" "$output" "${sources[@]}" 2>&1 | while IFS= read -r line; do cecho "$line"; done
                ret=${PIPESTATUS[0]}
            else
                err "未找到 zip 命令"
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
                err "未找到 7z 或 7za 命令 (请安装 p7zip)"
                return 1
            fi
            "$z7" a -t7z "-mx=$level" "$output" "${sources[@]}" 2>&1 | while IFS= read -r line; do cecho "$line"; done
            ret=${PIPESTATUS[0]}
            ;;

        tar)
            if ! command -v tar >/dev/null 2>&1; then
                err "未找到 tar 命令"
                return 1
            fi
            tar -cf "$output" "${sources[@]}" 2>&1 | while IFS= read -r line; do cecho "$line"; done
            ret=${PIPESTATUS[0]}
            ;;

        tar.gz)
            if ! command -v tar >/dev/null 2>&1; then
                err "未找到 tar 命令"
                return 1
            fi
            GZIP="-$level" tar -czf "$output" "${sources[@]}" 2>&1 | while IFS= read -r line; do cecho "$line"; done
            ret=${PIPESTATUS[0]}
            ;;

        tar.bz2)
            if ! command -v tar >/dev/null 2>&1; then
                err "未找到 tar 命令"
                return 1
            fi
            BZIP2="-$level" tar -cjf "$output" "${sources[@]}" 2>&1 | while IFS= read -r line; do cecho "$line"; done
            ret=${PIPESTATUS[0]}
            ;;

        tar.xz)
            if ! command -v tar >/dev/null 2>&1; then
                err "未找到 tar 命令"
                return 1
            fi
            XZ_OPT="-$level" tar -cJf "$output" "${sources[@]}" 2>&1 | while IFS= read -r line; do cecho "$line"; done
            ret=${PIPESTATUS[0]}
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
                gz)
                    if ! command -v gzip >/dev/null 2>&1; then err "未找到 gzip 命令"; return 1; fi
                    gzip "-$level" -c "$src" > "$output"
                    ret=$?
                    ;;
                bz2)
                    if ! command -v bzip2 >/dev/null 2>&1; then err "未找到 bzip2 命令"; return 1; fi
                    bzip2 "-$level" -c "$src" > "$output"
                    ret=$?
                    ;;
                xz)
                    if ! command -v xz >/dev/null 2>&1; then err "未找到 xz 命令"; return 1; fi
                    xz "-$level" -c "$src" > "$output"
                    ret=$?
                    ;;
            esac
            ;;

        *)
            err "不支持的格式: $format"
            return 1
            ;;
    esac

    if [ $ret -eq 0 ]; then
        cecho "压缩完成"
    else
        err "压缩失败 (退出码: $ret)"
    fi
    return $ret
}