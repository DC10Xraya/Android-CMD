#resource/cmd_codewc.bash
cmd_codewc() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        cecho -b "用法: CODECWC [选项] [文件...]"
        cecho "统计纯文本编程语言的有效行数、单词数和字符数"
        cecho -b "选项:"
        cecho "  -l              只显示行数"
        cecho "  -w              只显示单词数"
        cecho "  -c              只显示字符数"
        cecho "  -t <语言>       指定语言类型 (见下)"
        cecho "  -h, --help      显示此帮助"
        cecho "无文件时从标准输入读取(仅当标准输入不是终端)"
        cecho -b "支持的语言和注释规则："
        cecho "  shell, python, yaml, make, conf:  # 单行"
        cecho -i "  python 额外支持 \"\"\" 块注释"
        cecho "  C/C++/Java/JS/Go/Rust:   // 单行, /* */ 块"
        cecho "  html, xml:               <!-- --> 块"
        cecho "  lua, sql:                -- 单行"
        cecho "  none:                    不做任何处理"
        return 0
    fi

    local show_lines=0 show_words=0 show_chars=0
    local lang="auto"
    local files=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -l) show_lines=1; shift ;;
            -w) show_words=1; shift ;;
            -c) show_chars=1; shift ;;
            -t) lang="$2"; shift 2 ;;
            --) shift; break ;;
            -*)
                err "未知选项: $1"
                return 1
                ;;
            *) files+=("$1"); shift ;;
        esac
    done

    if [ $show_lines -eq 0 ] && [ $show_words -eq 0 ] && [ $show_chars -eq 0 ]; then
        show_lines=1; show_words=1; show_chars=1
    fi

    if [ ${#files[@]} -eq 0 ]; then
        if [ -t 0 ]; then
            cmd_codewc -h
            return 0
        else
            files=("-")
        fi
    fi

    get_lang_by_ext() {
        case "${1,,}" in
            sh|bash|zsh|ksh|fish) echo "shell" ;;
            py) echo "python" ;;
            c|cpp|cc|cxx|h|hpp|java|js|go|rs) echo "cstyle" ;;
            html|htm) echo "html" ;;
            xml) echo "xml" ;;
            lua) echo "lua" ;;
            sql) echo "sql" ;;
            yaml|yml) echo "yaml" ;;
            make|mk) echo "make" ;;
            conf|cfg) echo "conf" ;;
            *) echo "none" ;;
        esac
    }

    build_awk_script() {
        local lang="$1"
        local single=""
        local begin=""
        local end=""
        case "$lang" in
            shell|yaml|make|conf)
                single="#" ;;
            python)
                single="#"
                begin="\x22\x22\x22"
                end="\x22\x22\x22"
                ;;
            cstyle)
                single="//"
                begin="/\\*"
                end="\\*/"
                ;;
            html|xml)
                begin="<!--"
                end="-->"
                ;;
            lua|sql)
                single="--"
                ;;
            none) ;;
        esac

        awk_prog='
        BEGIN {
            single = "'"$single"'"
            begin = "'"$begin"'"
            end = "'"$end"'"
            in_block = 0
            total_lines = 0
            total_words = 0
            total_chars = 0
        }
        {
            line = $0
            processed = ""
            # 特殊处理 shebang: 以 #! 开头则直接保留, 不处理任何注释
            if (line ~ /^#!/) {
                processed = line
            } else {
                if (in_block) {
                    if (end != "" && index(line, end) > 0) {
                        split(line, parts, end)
                        line = parts[2]
                        in_block = 0
                    } else {
                        line = ""
                    }
                }
                while (line != "") {
                    if (single != "" && index(line, single) > 0) {
                        pos = index(line, single)
                        processed = processed substr(line, 1, pos-1)
                        line = ""
                        break
                    }
                    if (begin != "" && index(line, begin) > 0) {
                        pos = index(line, begin)
                        processed = processed substr(line, 1, pos-1)
                        line = substr(line, pos + length(begin))
                        in_block = 1
                        if (end != "" && index(line, end) > 0) {
                            split(line, parts, end)
                            line = parts[2]
                            in_block = 0
                        } else {
                            line = ""
                        }
                        continue
                    }
                    processed = processed line
                    line = ""
                }
            }
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", processed)
            if (processed != "") {
                total_lines++
                n = split(processed, words, /[[:space:]]+/)
                total_words += n
                total_chars += length(processed)
            }
        }
        END {
            print total_lines, total_words, total_chars
        }'
        echo "$awk_prog"
    }

    process_file() {
        local file="$1"
        local lang_used="$2"
        local script="$(build_awk_script "$lang_used")"
        if [ "$file" = "-" ]; then
            awk "$script" /dev/stdin
        else
            awk "$script" "$file"
        fi
    }

    local -a results=()
    local -a names=()
    local total_l=0 total_w=0 total_c=0

    for file in "${files[@]}"; do
        local lang_used="$lang"
        if [ "$lang_used" = "auto" ]; then
            if [ "$file" != "-" ]; then
                lang_used=$(get_lang_by_ext "${file##*.}")
            else
                lang_used="none"
            fi
        fi
        local stats
        if [ "$file" = "-" ]; then
            stats=$(process_file - "$lang_used")
        else
            if [ ! -f "$file" ]; then
                err "文件不存在: $file"
                continue
            fi
            stats=$(process_file "$file" "$lang_used")
        fi
        read l w c <<< "$stats"
        results+=("$l $w $c")
        names+=("$file")
        total_l=$((total_l + l))
        total_w=$((total_w + w))
        total_c=$((total_c + c))
    done

    for i in "${!results[@]}"; do
        read l w c <<< "${results[i]}"
        cecho "文件: ${names[i]}"
        local out="  "
        [ $show_lines -eq 1 ] && out="${out}有效行数: $l   "
        [ $show_words -eq 1 ] && out="${out}有效单词数: $w   "
        [ $show_chars -eq 1 ] && out="${out}有效字符数: $c"
        cecho "$out"
    done

    if [ ${#results[@]} -gt 1 ]; then
        cecho "文件: total"
        local out="  "
        [ $show_lines -eq 1 ] && out="${out}有效行数: $total_l   "
        [ $show_words -eq 1 ] && out="${out}有效单词数: $total_w   "
        [ $show_chars -eq 1 ] && out="${out}有效字符数: $total_c"
        cecho "$out"
    fi
}