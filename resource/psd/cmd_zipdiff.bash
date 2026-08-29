#resource/cmd_zipdiff.bash
cmd_zipdiff() {
    # ---------- 参数解析 ----------
    local output_file=""
    local show_unchanged=1 show_modified=1 show_added=1 show_deleted=1 show_moved=1   # 新增移动显示开关
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
            -4|-m) show_moved=0; shift ;;          # 新增选项：不输出移动的文件
            -h|--help)
                cecho -b "用法: ZIPDIFF <源文件> <新文件> [选项]"
                cecho "选项:"
                cecho "  -f <输出文件>   将结果输出到文件(无颜色)"
                cecho "  -0              不输出不变的文件"
                cecho "  -1              不输出修改的文件"
                cecho "  -2              不输出新增的文件"
                cecho "  -3              不输出删除的文件"
                cecho "  -4|-m           不输出移动的文件"
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

    # ...（原有的参数检查和工具检查保持不变）...

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
    # ...（原有整体比较逻辑不变）...

    # ---------- 解压到临时目录 ----------
    # ...（原有解压逻辑不变）...

    # ---------- 生成文件列表 ----------
    # ...（原有生成 old_files.txt, new_files.txt 及分类逻辑不变）...

    # ---------- 计算 common 中的修改/未变更 ----------
    # ...（原有 modified.txt / unchanged.txt 生成逻辑不变）...

    # ===== 新增：检测移动文件 =====
    # 1. 为 only_old 建立哈希 -> 路径映射（只保留最后一个，若重复则覆盖）
    declare -A old_hash_to_path
    while IFS= read -r file; do
        hash="$($SHA256SUM_CMD "$old_dir/$file" | awk '{print $1}')"
        old_hash_to_path["$hash"]="$file"
    done < "$tmp_dir/only_old.txt"

    # 2. 遍历 only_new，寻找匹配的哈希
    > "$tmp_dir/moved.txt"
    > "$tmp_dir/moved_old_paths.txt"
    > "$tmp_dir/moved_new_paths.txt"
    while IFS= read -r file; do
        hash="$($SHA256SUM_CMD "$new_dir/$file" | awk '{print $1}')"
        if [[ -n "${old_hash_to_path[$hash]}" ]]; then
            old_path="${old_hash_to_path[$hash]}"
            echo "$old_path -> $file" >> "$tmp_dir/moved.txt"
            echo "$old_path" >> "$tmp_dir/moved_old_paths.txt"
            echo "$file" >> "$tmp_dir/moved_new_paths.txt"
            # 移除已配对的哈希，避免同一旧文件匹配多个新文件
            unset 'old_hash_to_path[$hash]'
        fi
    done < "$tmp_dir/only_new.txt"

    # 3. 从 only_old 和 only_new 中剔除已移动的路径，得到真正的删除/新增
    if [ -s "$tmp_dir/moved_old_paths.txt" ]; then
        # 使用 grep -v -F -f 过滤
        grep -v -F -f "$tmp_dir/moved_old_paths.txt" "$tmp_dir/only_old.txt" > "$tmp_dir/only_old_real.txt" 2>/dev/null
        grep -v -F -f "$tmp_dir/moved_new_paths.txt" "$tmp_dir/only_new.txt" > "$tmp_dir/only_new_real.txt" 2>/dev/null
        mv "$tmp_dir/only_old_real.txt" "$tmp_dir/only_old.txt" 2>/dev/null
        mv "$tmp_dir/only_new_real.txt" "$tmp_dir/only_new.txt" 2>/dev/null
    fi
    # 若没有移动，则 only_old/only_new 保持不变

    # ===== 新增结束 =====

    # ---------- 输出 ----------
    _print_category() {
        local label="$1"
        local listfile="$2"
        local show_flag="$3"
        local file_mode="$4"

        if [ $show_flag -eq 0 ] || [ ! -s "$listfile" ]; then
            return
        fi

        if [ "$file_mode" -eq 1 ]; then
            echo "$label" >> "$output_file"
            echo "==============================" >> "$output_file"
            while IFS= read -r line; do
                echo "$line" >> "$output_file"
            done < "$listfile"
        else
            cecho -cb 42 "$label"
            cecho -cb 42 "=============================="
            while IFS= read -r line; do
                cecho "$line"
            done < "$listfile"
        fi
    }

    # --- 输出两个文件路径 ---
    if [ -n "$output_file" ]; then
        echo "$old_file" > "$output_file"
        echo "$new_file" >> "$output_file"
        echo "" >> "$output_file"
    else
        cecho "$old_file"
        cecho "$new_file"
        echo ""
    fi

    # --- 输出分类 ---
    if [ -n "$output_file" ]; then
        _print_category "移动的文件:" "$tmp_dir/moved.txt" $show_moved 1
        _print_category "新增的文件:" "$tmp_dir/only_new.txt" $show_added 1
        _print_category "删除的文件:" "$tmp_dir/only_old.txt" $show_deleted 1
        _print_category "修改的文件:" "$tmp_dir/modified.txt" $show_modified 1
        _print_category "不变的文件:" "$tmp_dir/unchanged.txt" $show_unchanged 1
    else
        _print_category "移动的文件:" "$tmp_dir/moved.txt" $show_moved 0
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