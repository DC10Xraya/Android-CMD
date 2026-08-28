#resource/cmd_dump.bash
cmd_dump() {
    # 显示帮助
    if [[ "$1" == "-h" || "$1" == "--help" ]] || [ $# -lt 1 ]; then
        cecho -b "用法: DUMP <目标路径> [输出路径]"
        cecho "将目标文件夹下的所有内容导出到文本文件"
        cecho "纯文本文件显示路径和内容, 二进制文件仅显示路径"
        cecho "输出路径默认为目标路径下的 DUMP_时间戳.txt"
        cecho "按Ctrl+C可中断导出"
        return 0
    fi

    local target="$1"
    local output="$2"

    # 检查目标目录
    if [ ! -d "$target" ]; then
        err "目标路径不是目录: $target"
        return 1
    fi

    # 转为绝对路径
    local target_abs
    if ! target_abs=$(cd "$target" 2>/dev/null && pwd); then
        err "无法进入目录: $target"
        return 1
    fi

    # 生成默认输出路径
    if [ -z "$output" ]; then
        output="$target_abs/DUMP_$(date +%Y%m%d_%H%M%S).txt"
    else
        # 输出路径转为绝对路径
        local out_dir=$(dirname "$output")
        local out_base=$(basename "$output")
        if mkdir -p "$out_dir" 2>/dev/null; then
            output=$(cd "$out_dir" 2>/dev/null && pwd)/"$out_base"
        else
            err "无法创建输出目录: $out_dir"
            return 1
        fi
    fi

    # 确保输出文件所在目录存在
    local out_parent=$(dirname "$output")
    mkdir -p "$out_parent" 2>/dev/null || {
        err "无法创建输出目录: $out_parent"
        return 1
    }

    local output_abs="$output"   # 用于排除自身
    local interrupted=0
    trap 'interrupted=1' INT

    # ---------- 文本/二进制判断(黑白名单) ----------
    _is_text_file() {
        local f="$1"
        local ext="${f##*.}"
        # 转为小写比较(兼容大小写)
        ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')

        # 1. 黑名单
        case "$ext" in
            png|jpg|jpeg|gif|bmp|ico|tif|tiff|webp|heic|heif|raw|cr2|nef|dng)
                return 1 ;;
            mp3|wav|flac|aac|ogg|opus|m4a|wma)
                return 1 ;;
            mp4|avi|mov|mkv|wmv|flv|swf|webm|m4v|3gp|ts|m2ts|mts|mxf)
                return 1 ;;
            zip|gz|rar|7z|tar|bz2|xz|zst|iso|img|vmdk|vdi|qcow2)
                return 1 ;;
            pdf|doc|docx|xls|xlsx|ppt|pptx|odt|ods|odp)
                return 1 ;;
            exe|dll|so|a|lib|o|bin|dat|db|sqlite|apk|dex|odex|oat|class|jar|war|ear)
                return 1 ;;
            pcap|cap|pcapng|psd|ai|eps|ps|indd|crx|nexe|obj)
                return 1 ;;
        esac

        # 2. 白名单
        case "$ext" in
            txt|sh|bash|md|json|xml|yaml|yml|toml|properties|ini|cfg|conf|log|csv|tsv|tsv)
                return 0 ;;
            c|h|java|py|pl|pm|rb|go|rs|swift|kt|dart|gradle|cmake|makefile|mk|sln|cs|vb|fs|scala|clj|erl|ex|exs)
                return 0 ;;
            html|htm|css|js|jsx|tsx|vue|sass|scss|less|styl|pug|ejs|haml|slim|tmpl|tpl|coffee|litcoffee)
                return 0 ;;
            env|example|sample|gitignore|editorconfig|dockerignore|eslintrc|prettierrc|babelrc|npmrc)
                return 0 ;;
            r|rmd|rnw|tex|sty|cls|bib|bst|asy|gnuplot|scad)
                return 0 ;;
        esac

        # 3. 扩展名未知, 使用 file 命令检测
        if command -v file >/dev/null 2>&1; then
            local mime
            mime=$(file -b --mime-type "$f" 2>/dev/null)
            if [[ -n "$mime" ]]; then
                if [[ "$mime" == text/* ]] || [[ "$mime" == application/json ]] || [[ "$mime" == application/xml ]] || [[ "$mime" == application/javascript ]]; then
                    return 0
                fi
            fi
            # 3.1. 检查 file 输出是否包含 "text" 或 "ASCII" 或 "UTF-8"
            if file -b "$f" 2>/dev/null | grep -qiE 'text|ascii|utf-?8|empty'; then
                return 0
            fi
            return 1
        fi

        # 4. 检测文件头 512 字节内是否包含 NUL
        local head_data
        head_data=$("$_HEAD" -c 512 "$f" 2>/dev/null)
        if [ -z "$head_data" ]; then
            return 0   # 空文件视为文本
        fi
        if echo "$head_data" | od -An -tx1 | tr -s ' ' '\n' | grep -q '^00$' 2>/dev/null; then
            return 1
        fi
        return 0
    }

    # 输出单个文件
    _dump_file() {
        local f="$1"
        if [ -L "$f" ]; then
            # 符号链接：仅显示路径, 不带冒号
            echo "$f"
            echo
            return
        fi
        if [ -f "$f" ] && [ -r "$f" ] && _is_text_file "$f"; then
            # 文本文件：带冒号, 显示内容
            echo "$f:"
            "$_CAT" "$f" 2>/dev/null
            echo
        else
            # 二进制文件或不可读文件：仅显示路径, 不带冒号
            echo "$f"
            echo
        fi
    }

    # 递归遍历目录
    _dump_dir() {
        local dir="$1"
        local exclude="$2"
        shopt -s dotglob nullglob
        local entries=("$dir"/*)
        shopt -u dotglob nullglob

        for entry in "${entries[@]}"; do
            if [ $interrupted -eq 1 ]; then
                return
            fi
            if [ "$entry" = "$exclude" ]; then
                continue
            fi
            if [ -d "$entry" ] && [ ! -L "$entry" ]; then
                _dump_dir "$entry" "$exclude"
            else
                _dump_file "$entry"
            fi
        done
    }

    # ---------- 开始导出 ----------
    {
        _dump_dir "$target_abs" "$output_abs"
    } > "$output"

    trap - INT

    if [ $interrupted -eq 1 ]; then
        err "用户中断, 输出文件可能不完整: $output"
        return 130
    else
        cecho "导出完成: $output"
        return 0
    fi
}