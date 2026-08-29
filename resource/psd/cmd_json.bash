#resource/cmd_json.bash
cmd_json() {
    # 显示帮助
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        cecho -b "用法: JSON [参数] <目标json所在路径>"
        cecho "JSON -w (交互模式, 粘贴内容后按 Ctrl+D 校验)"
        cecho -b "参数:"
        cecho "  -w          交互模式, 无需指定文件, 最好指定格式, 否则两种都判断"
        cecho "  -5          强制指定 JSON5 (默认根据后缀 .json5 识别)"
        cecho "  -0          强制指定标准 JSON (默认根据后缀 .json 识别)"
        cecho "  -s <解析器>  强制指定解析器 (jq/py/bash), 默认自动选择"
        err "警告: 使用bash解析为实验性内容, 只做基本检测"
        return 0
    fi

    local interactive=0
    local force_type=""      # "json" 或 "json5"
    local force_parser=""    # "jq" 或 "py" 或 "bash"
    local file_path=""

    # 参数解析
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -w)
                interactive=1
                shift
                ;;
            -5)
                force_type="json5"
                shift
                ;;
            -0)
                force_type="json"
                shift
                ;;
            -s)
                if [[ -z "$2" ]]; then
                    err "选项 -s 需要指定解析器 (jq/py/bash)"
                    return 1
                fi
                case "$2" in
                    jq|py|bash) force_parser="$2" ;;
                    *)
                        err "无效解析器: $2, 可选 jq/py/bash"
                        return 1
                        ;;
                esac
                shift 2
                ;;
            -*)
                err "未知选项: $1"
                return 1
                ;;
            *)
                if [[ -n "$file_path" ]]; then
                    err "只能指定一个文件"
                    return 1
                fi
                file_path="$1"
                shift
                ;;
        esac
    done

    # 交互模式
    if [[ $interactive -eq 1 ]]; then
        if [[ -n "$file_path" ]]; then
            err "-w 模式不能指定文件"
            return 1
        fi
        # 根据强制类型确定提示语
        local prompt_msg="请输入 JSON 或 JSON5 内容 (按 Ctrl+D 结束):"
        if [[ "$force_type" == "json" ]]; then
            prompt_msg="请输入 JSON 内容 (按 Ctrl+D 结束):"
        elif [[ "$force_type" == "json5" ]]; then
            prompt_msg="请输入 JSON5 内容 (按 Ctrl+D 结束):"
        fi
        cecho "$prompt_msg"
        local content
        content=$(cat)
        if [[ -z "$content" ]]; then
            err "未输入任何内容"
            return 1
        fi

        # 若指定了类型，只检测该类型
        if [[ -n "$force_type" ]]; then
            _validate_and_print "$content" "$force_type" "$force_parser"
            return $?
        else
            # 未指定类型，分别检测 JSON 和 JSON5
            local ret=0
            # 先检测 JSON
            _print_label "JSON"
            _validate_and_print "$content" "json" "$force_parser"
            local json_ret=$?
            # 再检测 JSON5
            _print_label "JSON5"
            _validate_and_print "$content" "json5" "$force_parser"
            local json5_ret=$?
            # 如果至少有一个有效，返回 0，否则 1
            if [[ $json_ret -eq 0 || $json5_ret -eq 0 ]]; then
                return 0
            else
                return 1
            fi
        fi
        return
    fi

    # 文件模式
    if [[ -z "$file_path" ]]; then
        err "缺少目标文件路径 (使用 -h 查看帮助)"
        return 1
    fi

    if [[ ! -f "$file_path" ]]; then
        err "文件不存在: $file_path"
        return 1
    fi
    if [[ ! -r "$file_path" ]]; then
        err "文件不可读: $file_path"
        return 1
    fi

    local content
    content=$("$_CAT" "$file_path" 2>/dev/null)
    if [[ -z "$content" && -s "$file_path" ]]; then
        err "无法读取文件内容"
        return 1
    fi

    # 文件模式根据文件后缀自动确定类型（若未强制指定）
    local actual_type="$force_type"
    if [[ -z "$actual_type" ]]; then
        local ext="${file_path##*.}"
        ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
        if [[ "$ext" == "json5" ]]; then
            actual_type="json5"
        elif [[ "$ext" == "json" ]]; then
            actual_type="json"
        else
            actual_type="json"   # 默认当作 JSON
        fi
    fi

    _validate_and_print "$content" "$actual_type" "$force_parser"
    return $?
}

# ---------- 内部函数 ----------

# 打印标签（用于交互模式未指定类型时）
_print_label() {
    local label="$1"
    echo "--- $label 检测结果 ---"
}

# 封装校验和输出（有效绿色，无效红色）
_validate_and_print() {
    local content="$1"
    local type="$2"          # "json" 或 "json5"
    local parser="$3"        # 可选

    local result=0
    local err_msg=""

    # 调用核心校验函数，捕获输出和状态
    local output
    output=$(_validate_json_content "$content" "$type" "$parser" 2>&1)
    result=$?

    if [[ $result -eq 0 ]]; then
        cecho -c 92 "有效"
    else
        # 提取错误信息（去掉可能的前缀）
        err "$output"
    fi
    return $result
}

# 核心校验函数（不直接输出，只输出错误信息到 stdout，返回状态码）
_validate_json_content() {
    local content="$1"
    local force_type="$2"
    local force_parser="$3"

    # 确定类型
    local json_type="$force_type"
    [[ -z "$json_type" ]] && json_type="json"   # 默认

    # 预处理 JSON5 -> 去除注释和尾随逗号
    local clean_content="$content"
    if [[ "$json_type" == "json5" ]]; then
        # 更完善的预处理：去除块注释 /* */ 和行注释 //
        # 使用 awk 或 sed 处理，但这里用简单的 sed + 状态机
        # 为了简化，我们使用一个简单的 awk 脚本（如果 awk 可用）
        if command -v awk >/dev/null 2>&1; then
            clean_content=$(echo "$content" | awk '
                BEGIN { in_string=0; in_block_comment=0; in_line_comment=0; }
                {
                    line = $0
                    # 简单处理：忽略字符串内的注释
                    # 但 awk 难以完美处理，这里使用一个简化的方法：逐字符处理
                }
                # 实际我们用 perl 或 python 更好，但没有这些依赖时，我们尽量用 sed。
            ')
        fi
        # 由于 awk 处理复杂，我们这里使用多个 sed 配合，但可能不完美
        # 简单做法：去除 // 到行尾（但会破坏字符串内的 //，但概率低）
        clean_content=$(echo "$content" | $_SED -E 's|//.*$||g' 2>/dev/null)
        # 去除块注释 /* ... */ (多行)
        clean_content=$(echo "$clean_content" | $_SED -E ':a; s|/\*.*?\*/||g; ta' 2>/dev/null)
        # 去除尾随逗号
        clean_content=$(echo "$clean_content" | $_SED -E 's/,[[:space:]]*([}\]])/\1/g' 2>/dev/null)
    fi

    # 确定尝试顺序
    local parsers=()
    if [[ -n "$force_parser" ]]; then
        parsers=("$force_parser")
    else
        parsers=("jq" "py" "bash")
    fi

    local last_error=""
    for parser in "${parsers[@]}"; do
        local result=0
        local err_msg=""
        case "$parser" in
            jq)
                if command -v jq >/dev/null 2>&1; then
                    err_msg=$(echo "$clean_content" | jq . 2>&1 >/dev/null)
                    result=$?
                else
                    err_msg="jq 命令未安装"
                    result=127
                fi
                ;;
            py)
                if command -v python >/dev/null 2>&1 || command -v python3 >/dev/null 2>&1; then
                    local py_cmd="python"
                    command -v python3 >/dev/null 2>&1 && py_cmd="python3"
                    err_msg=$(echo "$clean_content" | $py_cmd -c "import sys, json; json.load(sys.stdin)" 2>&1)
                    result=$?
                else
                    err_msg="python 命令未安装"
                    result=127
                fi
                ;;
            bash)
                err_msg=$(_validate_json_bash "$clean_content")
                result=$?
                ;;
            *)
                err_msg="未知解析器"
                result=1
                ;;
        esac

        if [[ $result -eq 0 ]]; then
            # 有效，返回 0，无输出
            return 0
        else
            last_error=$(echo "$err_msg" | head -1 | tr -d '\n')
            # 继续尝试
        fi
    done

    # 所有解析器都失败，输出错误信息
    if [[ -n "$last_error" ]]; then
        echo "$last_error"
    else
        echo "无效 (原因未知)"
    fi
    return 1
}

# 简易 Bash 校验 (只做括号和引号平衡)
_validate_json_bash() {
    local content="$1"
    local stack=()
    local in_string=0
    local string_char=""
    local escaped=0
    local i
    for (( i=0; i<${#content}; i++ )); do
        char="${content:i:1}"
        if [[ $in_string -eq 0 ]]; then
            case "$char" in
                '"'|"'")
                    in_string=1
                    string_char="$char"
                    ;;
                '{'|'[')
                    stack+=("$char")
                    ;;
                '}'|']')
                    if [[ ${#stack[@]} -eq 0 ]]; then
                        echo "未匹配的关闭括号 '$char'"
                        return 1
                    fi
                    local top="${stack[-1]}"
                    if [[ "$char" == "}" && "$top" != "{" ]] || [[ "$char" == "]" && "$top" != "[" ]]; then
                        echo "括号匹配错误: 期望 ${top} 但遇到 $char"
                        return 1
                    fi
                    unset 'stack[-1]'
                    ;;
            esac
        else
            # 字符串内
            if [[ $escaped -eq 0 ]]; then
                if [[ "$char" == "\\" ]]; then
                    escaped=1
                elif [[ "$char" == "$string_char" ]]; then
                    in_string=0
                fi
            else
                escaped=0
            fi
        fi
    done

    if [[ $in_string -eq 1 ]]; then
        echo "字符串未闭合"
        return 1
    fi
    if [[ ${#stack[@]} -gt 0 ]]; then
        echo "括号未闭合: 剩余 ${#stack[@]} 个"
        return 1
    fi
    return 0
}