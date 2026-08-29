#resource/cmd_zipdiff.bash
cmd_zipdiff() {
    # ---------- 参数解析 ----------
    local output_file=""
    local show_unchanged=1 show_modified=1 show_added=1 show_deleted=1
    local old_file="" new_file=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f)
                output_file="$2"
                shift 2
                ;;
            -0) show_unchanged=0; shift ;;
            -1) show_modified=0; shift ;;
            -2) show_added=0; shift ;;
            -3) show_deleted=0; shift ;;
            -h|--help)
                cecho -b "用法: ZIPDIFF <源文件> <新文件> [选项]"
                cecho "选项:"
                cecho "  -f <输出文件>   将结果输出到文件(无颜色)"
                cecho "  -0              不输出不变的文件"
                cecho "  -1              不输出修改的文件"
                cecho "  -2              不输出新增的文件"
                cecho "  -3              不输出删除的文件"
                return 0
                ;;
            -*)
                err "未知选项: $1"
                return 1
                ;;
            *)
                if [ -z "$old_file" ]; then
                    old_file="$1"
                elif [ -z "$new_file" ]; then
                    new_file="$1"
                else
                    err "多余的参数: $1"
                    return 1
                fi
                shift
                ;;
        esac
    done

    if [ -z "$old_file" ] || [ -z "$new_file" ]; then
        err "需要指定源文件和新文件"
        return 1
    fi

    if [ ! -f "$old_file" ]; then
        err "源文件不存在: $old_file"
        return 1
    fi
    if [ ! -f "$new_file" ]; then
        err "新文件不存在: $new_file"
        return 1
    fi

    # ---------- 必要工具 ----------
    local UNZIP_CMD=""
    local SHA256SUM_CMD=""
    if command -v unzip >/dev/null 2>&1; then
        UNZIP_CMD="unzip"
    elif command -v busybox >/dev/null 2>&1 && busybox --list 2>/dev/null | grep -q unzip; then
        UNZIP_CMD="busybox unzip"
    else
        err "未找到 unzip 命令(请安装 unzip 或 busybox)"
        return 127
    fi

    if command -v sha256sum >/dev/null 2>&1; then
        SHA256SUM_CMD="sha256sum"
    elif command -v busybox >/dev/null 2>&1 && busybox --list 2>/dev/null | grep -q sha256sum; then
        SHA256SUM_CMD="busybox sha256sum"
    else
        err "未找到 sha256sum 命令(请安装 coreutils 或 busybox)"
        return 127
    fi

    # ---------- 中断处理 ----------
    local interrupted=0
    local tmp_dir=""
    trap 'interrupted=1' INT

    cleanup() {
        if [ -n "$tmp_dir" ] && [ -d "$tmp_dir" ]; then
            rm -rf "$tmp_dir" 2>/dev/null
        fi
    }

    # ---------- 整体 SHA256 ----------
    local old_hash="$($SHA256SUM_CMD "$old_file" | awk '{print $1}')"
    local new_hash="$($SHA256SUM_CMD "$new_file" | awk '{print $1}')"
    if [ "$old_hash" = "$new_hash" ]; then
        if [ -n "$output_file" ]; then
            echo "两个ZIP文件完全相同(SHA256一致)" > "$output_file"
        else
            cecho -c 92 "两个ZIP文件完全相同(SHA256一致)"
        fi
        trap - INT
        return 0
    fi

    # ---------- 解压到临时目录 ----------
    if ! tmp_dir=$(mktemp -d -p "$TMP_DIR" zipdiff_XXXXXX 2>/dev/null); then
        err "无法创建临时目录"
        trap - INT
        return 1
    fi
    local old_dir="$tmp_dir/old"
    local new_dir="$tmp_dir/new"
    mkdir -p "$old_dir" "$new_dir" || { cleanup; err "无法创建子目录"; trap - INT; return 1; }

    if [ $interrupted -eq 0 ]; then
        if ! $UNZIP_CMD -q "$old_file" -d "$old_dir" 2>/dev/null; then
            cleanup; err "解压源文件失败"; trap - INT; return 1
        fi
    else
        cleanup; trap - INT; return 130
    fi

    if [ $interrupted -eq 0 ]; then
        if ! $UNZIP_CMD -q "$new_file" -d "$new_dir" 2>/dev/null; then
            cleanup; err "解压新文件失败"; trap - INT; return 1
        fi
    else
        cleanup; trap - INT; return 130
    fi

    # ---------- 生成文件列表 ----------
    if [ $interrupted -eq 0 ]; then
        cd "$old_dir" || { cleanup; err "无法进入目录"; trap - INT; return 1; }
        find . -type f | sed 's/^\.\///' | sort > "$tmp_dir/old_files.txt"
        cd "$new_dir" || { cleanup; err "无法进入目录"; trap - INT; return 1; }
        find . -type f | sed 's/^\.\///' | sort > "$tmp_dir/new_files.txt"
        cd - >/dev/null
    else
        cleanup; trap - INT; return 130
    fi

    if [ $interrupted -eq 1 ]; then
        cleanup; trap - INT; return 130
    fi

    # ---------- 分类 ----------
    comm -23 "$tmp_dir/old_files.txt" "$tmp_dir/new_files.txt" > "$tmp_dir/only_old.txt"
    comm -13 "$tmp_dir/old_files.txt" "$tmp_dir/new_files.txt" > "$tmp_dir/only_new.txt"
    comm -12 "$tmp_dir/old_files.txt" "$tmp_dir/new_files.txt" > "$tmp_dir/common.txt"

    > "$tmp_dir/modified.txt"
    > "$tmp_dir/unchanged.txt"
    while IFS= read -r file; do
        if [ $interrupted -eq 1 ]; then break; fi
        old_f="$old_dir/$file"
        new_f="$new_dir/$file"
        h1="$($SHA256SUM_CMD "$old_f" | awk '{print $1}')"
        h2="$($SHA256SUM_CMD "$new_f" | awk '{print $1}')"
        if [ "$h1" = "$h2" ]; then
            echo "$file" >> "$tmp_dir/unchanged.txt"
        else
            echo "$file" >> "$tmp_dir/modified.txt"
        fi
    done < "$tmp_dir/common.txt"

    if [ $interrupted -eq 1 ]; then
        cleanup; trap - INT; return 130
    fi

    # ---------- 输出 ----------
    # 辅助函数: 输出分类标题(亮绿背景)和文件列表(普通)
    _print_category() {
        local label="$1"
        local listfile="$2"
        local show_flag="$3"
        local file_mode="$4"   # 1: 输出到文件, 0: 终端

        if [ $show_flag -eq 0 ] || [ ! -s "$listfile" ]; then
            return
        fi

        if [ "$file_mode" -eq 1 ]; then
            echo "$label" >> "$output_file"
            echo "==============================" >> "$output_file"
            while IFS= read -r f; do
                echo "$f" >> "$output_file"
            done < "$listfile"
        else
            cecho -cb 42 "$label"
            cecho -cb 42 "=============================="
            while IFS= read -r f; do
                cecho "$f"
            done < "$listfile"
        fi
    }

    # --- 输出两个文件路径(普通颜色, 无背景) ---
    if [ -n "$output_file" ]; then
        echo "$old_file" > "$output_file"
        echo "$new_file" >> "$output_file"
        echo "" >> "$output_file"
    else
        cecho "$old_file"
        cecho "$new_file"
        echo ""   # 空行
    fi

    # --- 输出四个分类(标题和分隔线亮绿背景, 文件列表普通) ---
    if [ -n "$output_file" ]; then
        _print_category "新增的文件:" "$tmp_dir/only_new.txt" $show_added 1
        _print_category "删除的文件:" "$tmp_dir/only_old.txt" $show_deleted 1
        _print_category "修改的文件:" "$tmp_dir/modified.txt" $show_modified 1
        _print_category "不变的文件:" "$tmp_dir/unchanged.txt" $show_unchanged 1
    else
        _print_category "新增的文件:" "$tmp_dir/only_new.txt" $show_added 0
        _print_category "删除的文件:" "$tmp_dir/only_old.txt" $show_deleted 0
        _print_category "修改的文件:" "$tmp_dir/modified.txt" $show_modified 0
        _print_category "不变的文件:" "$tmp_dir/unchanged.txt" $show_unchanged 0
    fi

    # ---------- 清理 ----------
    cleanup
    trap - INT

    if [ -n "$output_file" ]; then
        cecho "结果已保存到: $output_file"
    fi
    return 0
}