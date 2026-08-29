#resource/cmd_awkc.bash
# ---------- AWKC 基于awk的计算器 ----------
cmd_awkc() {
    # 帮助信息
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        cecho "用法:"
        cecho "  AWKC     #进入交互模式(输入 AWKC 或 EXIT 退出)"
        cecho "  AWKC <表达式>           #单次计算"
        cecho "  AWKC -h <OR> --help    #显示此帮助"
        return 0
    fi

    if [ $# -eq 0 ]; then
    cecho "(AWKC/EXIT 退出)"
        # 交互模式
        while true; do
            printf "\033[96m[AWKC]>>> \033[0m"
            read -r input
            [ -z "$input" ] && continue
            local lower=$(echo "$input" | tr '[:upper:]' '[:lower:]')
            if [ "$lower" = "awkc" ] || [ "$lower" = "exit" ]; then
                echo ""
                break
            fi
            _awkc_compute "$input"
        done
        return
    fi

    # 单次执行
    local expression="$*"
    _awkc_compute "$expression"
}

# AWKC 计算辅助函数
_awkc_compute() {
    local expr="$1"

    # 预处理: 特殊符号、连续运算符、小数点检查、除以零检查
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

    # 指数、根号、阶乘
    expr=$(echo "$expr" | sed -E 's/\^/**/g')
    expr=$(echo "$expr" | sed -E 's/√\(/sqrt(/g; s/√([0-9.]+)/sqrt(\1)/g')
    expr=$(echo "$expr" | sed -E 's/\b([0-9]+)!/fact(\1)/g')

    local result
    if result=$(echo | awk '
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
        { print '"$expr"' }
    ' 2>&1); then
        cecho "$result"
    else
        if echo "$result" | grep -qi "division by zero"; then
            err "计算错误: 除数不能为零"
        else
            err "计算错误,请检查表达式(支持 + - * / % ^ sqrt sin cos tan log fact 等)"
        fi
    fi
}