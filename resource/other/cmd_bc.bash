#resource/cmd_bc.bash
# ---------- BC 任意精度计算器 ----------
cmd_bc() {
    # 帮助信息
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        cecho "用法:"
        cecho "  BC        #进入交互模式(输入 BC 或 EXIT 退出)"
        cecho "  BC [-s 精度] <表达式>   #单次计算"
        cecho "  BC -h <OR> --help     #显示此帮助"
        cecho "  #默认精度为20, -s可放在表达式前或后, 精度范围1-10000"
        return 0
    fi

    if [ $# -eq 0 ]; then
        cecho "(BC/EXIT退出, 按Ctrl+C停止正在进行的运算)"
        # 交互模式
        local scale=20
        cecho "当前精度: $scale"

        # 忽略 INT 信号, 防止退出循环(但计算中会被 _bc_compute 内部 trap 覆盖)
        trap '' INT

        while true; do
            printf "\033[92m[BC]>>> \033[0m"
            read -r input
            [ -z "$input" ] && continue
            local lower=$(echo "$input" | tr '[:upper:]' '[:lower:]')
            if [ "$lower" = "bc" ] || [ "$lower" = "exit" ]; then
                echo ""
                break
            fi

            local new_scale="$scale"
            local expr=""
            local tokens=($input)
            local i=0
            local skip=0
            while [ $i -lt ${#tokens[@]} ]; do
                if [ "${tokens[$i]}" = "-s" ] && [ $((i+1)) -lt ${#tokens[@]} ] && [[ "${tokens[$((i+1))]}" =~ ^[0-9]+$ ]]; then
                    new_scale="${tokens[$((i+1))]}"
                    if [ "$new_scale" -ge 1 ] && [ "$new_scale" -le 10000 ] 2>/dev/null; then
                        if [ "$new_scale" != "$scale" ]; then
                            cecho "新精度: $new_scale"
                            scale="$new_scale"
                        fi
                    else
                        err "精度必须在 1-10000 之间"
                        skip=1
                    fi
                    i=$((i+2))
                else
                    expr="$expr ${tokens[$i]}"
                    i=$((i+1))
                fi
            done
            expr=$(echo "$expr" | sed 's/^[[:space:]]*//')

            if [ $skip -eq 0 ] && [ -n "$expr" ]; then
                _bc_compute "$expr" "$scale"
            fi
        done

        # 恢复默认信号处理
        trap - INT
        return 0
    fi

    # ---------- 单次执行(带参数) ----------
    local scale=20
    local expression=""
    local args=("$@")
    local i=0
    local new_scale=""
    while [ $i -lt ${#args[@]} ]; do
        if [ "${args[$i]}" = "-s" ] && [ $((i+1)) -lt ${#args[@]} ] && [[ "${args[$((i+1))]}" =~ ^[0-9]+$ ]]; then
            new_scale="${args[$((i+1))]}"
            i=$((i+2))
        else
            expression="$expression ${args[$i]}"
            i=$((i+1))
        fi
    done
    expression=$(echo "$expression" | sed 's/^[[:space:]]*//')

    if [ -n "$new_scale" ]; then
        if [ "$new_scale" -ge 1 ] && [ "$new_scale" -le 10000 ] 2>/dev/null; then
            scale="$new_scale"
        else
            err "精度必须在 1-10000 之间"
            return 1
        fi
    fi

    if [ -z "$expression" ]; then
        err "用法: BC [-s 精度] <表达式>  或 BC -h 查看帮助"
        return 1
    fi

    cecho "精度: $scale"
    _bc_compute "$expression" "$scale" "prefix"
}
_bc_compute() {
    local expr="$1"
    local scale="$2"
    local prefix_mode="$3"

    # 预处理
    expr=$(echo "$expr" | sed 's/π/pi/g; s/÷/\//g; s/×/*/g; s/·/*/g')
    while [[ "$expr" =~ (\+\+|\+\-|\-\+|\-\-) ]]; do
        expr=$(echo "$expr" | sed -E 's/\+\+/+/g; s/\+-/-/g; s/-\+/-/g; s/--/+/g')
    done
    if echo "$expr" | grep -qE '[0-9]+\.[0-9]+\.[0-9]+'; then
        err "表达式错误: 数字中包含多个小数点"
        return 1
    fi
    if echo "$expr" | grep -qE '/0([^0-9.]|$)'; then
        err "表达式错误: 除数不能为零"
        return 1
    fi

    expr=$(echo "$expr" | sed -E 's/√\(/sqrt(/g; s/√([0-9.]+)/sqrt(\1)/g')
    expr=$(echo "$expr" | sed -E 's/([0-9]+)!/fact(\1)/g')
    expr=$(echo "$expr" | sed -E 's/\be\b/e(1)/g')

    local bc_script="
        define fact(n) {
            auto i, r;
            r = 1;
            for (i = 1; i <= n; i++) {
                r *= i;
            }
            return r;
        }
        define sin(x) { return s(x); }
        define cos(x) { return c(x); }
        define tan(x) { return s(x)/c(x); }
        define asin(x) { return a(x/sqrt(1-x*x)); }
        define acos(x) { return a(sqrt(1-x*x)/x); }
        define atan(x) { return a(x); }
        define atan2(y,x) { return a(y/x); }
        define log(x) { return l(x); }
        define ln(x) { return l(x); }
        define log10(x) { return l(x)/l(10); }
        define exp(x) { return e(x); }
        scale = $scale;
        pi = 4 * a(1);
        $expr
    "

    # ---------- 使用后台执行 + trap 支持中断 ----------
    local result=""
    local bc_pid=""
    local tempfile=""
    # 使用 TMP_DIR 创建临时文件
    if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ] && [ -w "$TMP_DIR" ]; then
        tempfile=$(mktemp -p "$TMP_DIR" 2>/dev/null) || {
            tempfile="$TMP_DIR/bc_$$_$(date +%s%N)_$RANDOM"
            touch "$tempfile" 2>/dev/null || {
                err "无法创建临时文件"
                return 1
            }
        }
    else
        tempfile=$(mktemp 2>/dev/null) || {
            err "无法创建临时文件"
            return 1
        }
    fi

    {
        bc -l <<< "$bc_script" > "$tempfile" 2>&1
    } &
    bc_pid=$!

    local old_trap=$(trap -p INT)
    trap 'kill -INT $bc_pid 2>/dev/null; wait $bc_pid 2>/dev/null; rm -f "$tempfile"; return 1' INT

    wait $bc_pid
    local wait_ret=$?
    eval "$old_trap" 2>/dev/null

    if [ $wait_ret -ne 0 ]; then
        err "计算被中断或出错"
        rm -f "$tempfile"
        return 1
    fi

    result=$(cat "$tempfile" 2>/dev/null)
    rm -f "$tempfile"

    if [ -z "$result" ]; then
        err "计算错误(无输出)"
        return 1
    fi

    if echo "$result" | grep -qi "divide by zero\|Math error: divide by 0"; then
        err "计算错误: 除数不能为零"
        return 1
    elif echo "$result" | grep -qi "Parse error\|syntax error"; then
        err "表达式解析错误"
        return 1
    fi

    result=$(echo "$result" | sed ':a; /\\$/ { N; s/\\\n//; ta }' 2>/dev/null || echo "$result")
    if [ "$prefix_mode" = "prefix" ]; then
        cecho "结果: $result"
    else
        cecho "$result"
    fi
    return 0
}