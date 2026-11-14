cmd_calc() {
    # 显示帮助
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        cecho "用法:"
        cecho "  CALC                  #进入交互模式 (输入 CALC 或 EXIT 退出)"
        cecho "  CALC <表达式>         #单次整数计算"
        cecho "  CALC -h / --help      #显示此帮助"
        cecho "示例: CALC 2+3*4"
        cecho "      CALC (10+5)/3"
        return 0
    fi

    # 交互模式: 无参数
    if [ $# -eq 0 ]; then
        cecho "(CALC/EXIT 退出)"
        while true; do
            printf "\033[93m[CALC]>>> \033[0m"
            read -r expr
            [ -z "$expr" ] && continue
            local lower=$(echo "$expr" | tr '[:upper:]' '[:lower:]')
            if [ "$lower" = "calc" ] || [ "$lower" = "exit" ]; then
                echo ""
                break
            fi
            local result
            if result="$(eval "echo \$(( $expr ))" 2>/dev/null)"; then
                if [ -z "$result" ]; then
                    err "表达式无效"
                else
                    cecho "$result"
                fi
            else
                err "计算错误: 表达式无效 (仅支持整数四则运算、括号、取模等)"
            fi
        done
        return 0
    fi

    # 单次计算
    local expr="$*"
    local result
    if result="$(eval "echo \$(( $expr ))" 2>/dev/null)"; then
        if [ -z "$result" ]; then
            err "表达式无效"
            return 1
        fi
        cecho "$result"
    else
        err "计算错误: 表达式无效 (仅支持整数四则运算、括号、取模等)"
        return 1
    fi
}