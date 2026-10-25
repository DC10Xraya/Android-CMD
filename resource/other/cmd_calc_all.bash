cmd_calc_all() {
    err "请使用具体命令: awkc, bc"
    return 1
}

cmd_awkc() {
    # 帮助信息
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        cecho "用法:"
        cecho "  AWKC     #进入交互模式(输入 AWKC / EXIT / Ctrl+D 退出, Ctrl+C 取消当前输入/计算)"
        cecho "  AWKC [-s 输出精度] <表达式>   #单次计算"
        cecho "  AWKC -h|--help                #显示此帮助"
        return 0
    fi

    if [ $# -eq 0 ]; then
        cecho "(AWKC/EXIT/Ctrl+D 退出, Ctrl+C 取消当前输入/计算)"
        local scale=""
        local _calc_interrupted=0
        local old_int_trap
        old_int_trap=$(trap -p INT)
        trap '_calc_interrupted=1' INT

        # 交互模式
        while true; do
            _calc_interrupted=0
            printf "\033[96m[AWKC]>>> \033[0m"
            read -r input
            local read_ret=$?
            if [ $read_ret -ne 0 ]; then
                if [ "$_calc_interrupted" -eq 1 ]; then
                    # Ctrl+C: 取消当前输入
                    echo ""
                    continue
                else
                    # Ctrl+D (EOF): 退出
                    echo ""
                    break
                fi
            fi
            [ -z "$input" ] && continue

            parse_line "$input"
            if [ ${#PARSED_ARGS[@]} -eq 0 ]; then
                continue
            fi

            local lower="${PARSED_ARGS[0],,}"
            if [ "$lower" = "awkc" ] || [ "$lower" = "exit" ]; then
                echo ""
                break
            fi

            local expr=""
            local tokens=("${PARSED_ARGS[@]}")
            local i=0
            local skip=0
            while [ $i -lt ${#tokens[@]} ]; do
                if [ "${tokens[$i]}" = "-s" ] && [ $((i+1)) -lt ${#tokens[@]} ] && [[ "${tokens[$((i+1))]}" =~ ^[0-9]+$ ]]; then
                    local ns="${tokens[$((i+1))]}"
                    if [[ "$ns" =~ ^0*([1-9][0-9]{0,6})$ ]]; then
                        local n=$((10#${BASH_REMATCH[1]}))
                        if [ "$n" != "$scale" ]; then
                            cecho "输出精度: $n"
                            scale="$n"
                        fi
                    else
                        err "输出精度范围 1-9999999"
                        skip=1
                    fi
                    i=$((i+2))
                else
                    expr="$expr ${tokens[$i]}"
                    i=$((i+1))
                fi
            done
            expr="${expr#"${expr%%[![:space:]]*}"}"

            if [ $skip -eq 0 ] && [ -n "$expr" ]; then
                _calc_interrupted=0
                _awkc_compute "$expr" "$scale"
            fi
        done

        if [ -n "$old_int_trap" ]; then
            eval "$old_int_trap"
        else
            trap - INT
        fi
        return 0
    fi

    # ---------- 单次执行 ----------
    local scale=""
    local expression=""
    local args=("$@")
    local i=0
    while [ $i -lt ${#args[@]} ]; do
        if [ "${args[$i]}" = "-s" ] && [ $((i+1)) -lt ${#args[@]} ] && [[ "${args[$((i+1))]}" =~ ^[0-9]+$ ]]; then
            local ns="${args[$((i+1))]}"
            if [[ "$ns" =~ ^0*([1-9][0-9]{0,6})$ ]]; then
                scale=$((10#${BASH_REMATCH[1]}))
            else
                err "输出精度范围 1-9999999"
                return 1
            fi
            i=$((i+2))
        else
            expression="$expression ${args[$i]}"
            i=$((i+1))
        fi
    done
    expression="${expression#"${expression%%[![:space:]]*}"}"

    if [ -z "$expression" ]; then
        err "用法: AWKC [-s 输出精度] <表达式>  或 AWKC -h 查看帮助"
        return 1
    fi

    local _calc_interrupted=0
    local old_int_trap
    old_int_trap=$(trap -p INT)
    trap '_calc_interrupted=1' INT
    _awkc_compute "$expression" "$scale"
    local rc=$?
    if [ -n "$old_int_trap" ]; then
        eval "$old_int_trap"
    else
        trap - INT
    fi
    return $rc
}

# AWKC 计算辅助函数
_awkc_compute() {
    local expr="$1"
    local scale="$2"

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

    expr=$(echo "$expr" | sed -E 's/\^/**/g')
    expr=$(echo "$expr" | sed -E 's/√\(/sqrt(/g; s/√([0-9.]+)/sqrt(\1)/g')
    expr=$(echo "$expr" | sed -E 's/\b([0-9]+)!/fact(\1)/g')

    local result
    if result=$(echo | awk -v scale="$scale" '
        BEGIN {
            pi = 3.141592653589793;
            e  = 2.718281828459045;
        }
        function tan(x)    { return sin(x)/cos(x); }
        function asin(x)   { return atan2(x, sqrt(1 - x*x)); }
        function acos(x)   { return atan2(sqrt(1 - x*x), x); }
        function log10(x)  { return log(x)/log(10); }
        function log2(x)   { return log(x)/log(2); }
        function abs(x)    { return x < 0 ? -x : x; }
        function floor(x)  { return x < 0 ? (x%1 ? int(x)-1 : int(x)) : int(x); }
        function ceil(x)   { return -floor(-x); }
        function round(x)  { return int(x + 0.5 - (x<0)); }
        function fact(n)   { if (n<=1) return 1; return n*fact(n-1); }
        function sind(x)   { return sin(x*pi/180); }
        function cosd(x)   { return cos(x*pi/180); }
        function tand(x)   { return tan(x*pi/180); }
        function asind(x)  { return asin(x)*180/pi; }
        function acosd(x)  { return acos(x)*180/pi; }
        function atand(x)  { return atan2(x,1)*180/pi; }
        function atan2d(y,x){ return atan2(y,x)*180/pi; }
        function stripzeros(s,   n) {
            if (index(s, ".") == 0) return s
            n = length(s)
            while (n > 1 && substr(s, n, 1) == "0") n--
            if (substr(s, n, 1) == ".") n--
            return substr(s, 1, n)
        }
        {
            __v = '"$expr"'
            if (scale == "") {
                print __v
            } else {
                print stripzeros(sprintf("%.*f", scale + 0, __v))
            }
        }
    ' 2>&1); then
        cecho "$result"
    else
        # 被 Ctrl+C 中断: 静默返回
        if [ "${_calc_interrupted:-0}" -eq 1 ]; then
            return 130
        fi
        if echo "$result" | grep -qi "division by zero"; then
            err "计算错误: 除数不能为零"
        else
            err "计算错误,请检查表达式(支持 + - * / % ^ sqrt sin cos tan log fact 等)"
        fi
        return 1
    fi
}

cmd_bc() {
    # 帮助信息
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        cecho "用法:"
        cecho "  BC        #进入交互模式(输入 BC / EXIT / Ctrl+D 退出, Ctrl+C 取消当前输入/计算)"
        cecho "  BC [-s 精度] <表达式>   #单次计算"
        cecho "  BC -h|--help            #显示此帮助"
        return 0
    fi

    if [ $# -eq 0 ]; then
        cecho "(BC/EXIT/Ctrl+D 退出, Ctrl+C 取消当前输入/计算)"
        local scale=20
        cecho "当前精度: $scale"

        local _calc_interrupted=0
        local old_int_trap
        old_int_trap=$(trap -p INT)
        trap '_calc_interrupted=1' INT

        while true; do
            _calc_interrupted=0
            printf "\033[92m[BC]>>> \033[0m"
            read -r input
            local read_ret=$?
            if [ $read_ret -ne 0 ]; then
                if [ "$_calc_interrupted" -eq 1 ]; then
                    # Ctrl+C: 取消当前输入
                    echo ""
                    continue
                else
                    # Ctrl+D (EOF): 退出
                    echo ""
                    break
                fi
            fi
            [ -z "$input" ] && continue

            parse_line "$input"
            if [ ${#PARSED_ARGS[@]} -eq 0 ]; then
                continue
            fi

            local lower="${PARSED_ARGS[0],,}"
            if [ "$lower" = "bc" ] || [ "$lower" = "exit" ]; then
                echo ""
                break
            fi

            local new_scale="$scale"
            local expr=""
            local tokens=("${PARSED_ARGS[@]}")
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
            expr="${expr#"${expr%%[![:space:]]*}"}"

            if [ $skip -eq 0 ] && [ -n "$expr" ]; then
                _calc_interrupted=0
                _bc_compute "$expr" "$scale"
            fi
        done

        if [ -n "$old_int_trap" ]; then
            eval "$old_int_trap"
        else
            trap - INT
        fi
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
    expression="${expression#"${expression%%[![:space:]]*}"}"

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

    local _calc_interrupted=0
    local old_int_trap
    old_int_trap=$(trap -p INT)
    trap '_calc_interrupted=1' INT
    _bc_compute "$expression" "$scale" "prefix"
    local rc=$?
    if [ -n "$old_int_trap" ]; then
        eval "$old_int_trap"
    else
        trap - INT
    fi
    return $rc
}

_bc_compute() {
    local expr="$1"
    local scale="$2"
    local prefix_mode="$3"

    # 预处理
    expr=$(echo "$expr" | sed 's/\*\*/^/g')
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

    local tempfile=""
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

    # 后台运行 bc, 让上层 trap 和 _calc_interrupted 标志处理 Ctrl+C
    bc -l <<< "$bc_script" > "$tempfile" 2>&1 &
    local bc_pid=$!

    wait $bc_pid
    local wait_ret=$?

    # 被 Ctrl+C 中断
    if [ "${_calc_interrupted:-0}" -eq 1 ]; then
        kill -KILL $bc_pid 2>/dev/null
        wait $bc_pid 2>/dev/null
        rm -f "$tempfile"
        return 130
    fi

    if [ $wait_ret -ne 0 ]; then
        err "计算被中断或出错"
        rm -f "$tempfile"
        return 1
    fi

    local result
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