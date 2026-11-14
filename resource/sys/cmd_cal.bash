#resource/cmd_cal.bash
cmd_cal() {
    # -h/--help
    if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -eq 0 ]; then
        err "用法: CAL [模式/年份] [月份]"
        cecho "用法:"
        cecho "  CAL 0              # 显示本月日历"
        cecho "  CAL 1              # 显示本年度日历"
        cecho "  CAL [年份]         # 显示指定年份的全年日历"
        cecho "  CAL [年份] [月份]  # 显示指定年月的日历"
        cecho "  CAL -h / --help    # 显示此帮助"
        return 0
    fi

    local year month display_mode

    # 处理参数
    if [ $# -eq 1 ]; then
        # 只有一个参数
        if [ "$1" = "0" ]; then
            # 模式0: 本月日历
            year=$(date +%Y 2>/dev/null)
            month=$(date +%m 2>/dev/null)
            display_mode="month"
        elif [ "$1" = "1" ]; then
            # 模式1: 本年度日历
            year=$(date +%Y 2>/dev/null)
            display_mode="year"
        elif echo "$1" | grep -qE '^[0-9]{4}$'; then
            # 只有年份: 显示该年全年日历
            year="$1"
            display_mode="year"
        else
            err "无效参数: $1"
            return 1
        fi
    elif [ $# -eq 2 ]; then
        # 两个参数: 年份和月份
        if echo "$1" | grep -qE '^[0-9]{4}$' && echo "$2" | grep -qE '^[0-9]{1,2}$'; then
            year="$1"
            month="$2"                          # 保留原值, 不补零
            # 强制十进制转换, 避免前导零被解释为八进制
            month=$((10#$month))
            if [ "$month" -lt 1 ] || [ "$month" -gt 12 ] 2>/dev/null; then
                err "月份应在 1-12 之间"
                return 1
            fi
            display_mode="month"
        else
            err "年份应为4位数字,月份应为1-12"
            return 1
        fi
    else
        err "参数过多用法: CAL [模式/年份] [月份]"
        return 1
    fi

    # ---------- 根据显示模式执行 ----------
    if [ "$display_mode" = "month" ]; then
        # 显示单月日历
        _display_month_calendar "$year" "$month"
    elif [ "$display_mode" = "year" ]; then
        # 显示全年日历
        _display_year_calendar "$year"
    fi
}

# ---------- 显示单月日历的内部函数（修改：直接使用内置实现） ----------
_display_month_calendar() {
    local year="$1"
    local month="$2"
    month=$((10#$month))          # 去除前导零
    _get_month_calendar_text "$year" "$month"
}

# ---------- 获取单月日历文本(统一格式,支持高亮今日) 修改：数值比较 ----------
_get_month_calendar_text() {
    local year="$1"
    local month="$2"
    month=$((10#$month))          # 转为纯数字

    # 获取今天的日期（转为数字）
    local today_year today_month today_day
    today_year=$(date +%Y 2>/dev/null)
    today_month=$(date +%m 2>/dev/null)
    today_month=$((10#$today_month))
    today_day=$(date +%d 2>/dev/null)
    today_day=$((10#$today_day))

    # 月份名称（中文）
    local month_names=("一月" "二月" "三月" "四月" "五月" "六月"
                       "七月" "八月" "九月" "十月" "十一月" "十二月")
    local month_index=$((month - 1))
    local month_name="${month_names[$month_index]}"

    # 计算当月天数
    local last_day
    # 优先用 date 命令（注意月份补零）
    last_day=$(date -d "${year}-$(printf "%02d" $month)-01 +1 month -1 day" +%d 2>/dev/null)
    if [ -z "$last_day" ] || [ $? -ne 0 ]; then
        # 回退到手工计算
        case $month in
            1|3|5|7|8|10|12) last_day=31 ;;
            4|6|9|11)        last_day=30 ;;
            2)
                if [ $((year % 4)) -eq 0 ] && { [ $((year % 100)) -ne 0 ] || [ $((year % 400)) -eq 0 ]; }; then
                    last_day=29
                else
                    last_day=28
                fi
                ;;
        esac
    fi

    # 计算当月第一天是星期几（0=周日）
    local first_weekday
    first_weekday=$(date -d "${year}-$(printf "%02d" $month)-01" +%w 2>/dev/null)
    if [ -z "$first_weekday" ] || [ $? -ne 0 ]; then
        # 蔡勒公式（备用）
        local y=$((year % 100)) m=$month c=$((year / 100))
        if [ $m -le 2 ]; then
            m=$((m + 12))
            y=$((y - 1))
        fi
        first_weekday=$(( (y + y/4 + c/4 - 2*c + 26*(m+1)/10 + 1 - 1) % 7 ))
        first_weekday=$(( (first_weekday + 7) % 7 ))
    fi

    # 输出标题（居中对齐，宽度20）
    local title="$month_name $year"
    local title_length=${#title}
    local padding=$(( (20 - title_length) / 2 ))
    printf "%${padding}s%s%$((20 - title_length - padding))s\n" "" "$title" ""

    # 输出星期头
    echo "日 一 二 三 四 五 六"

    # 生成日期行
    local day=1
    local current_col=0

    # 第一行缩进
    for ((i=0; i<first_weekday; i++)); do
        printf "   "
        current_col=$((current_col + 1))
    done

    # 打印日期
    for ((day=1; day<=last_day; day++)); do
        # 判断是否为今天（使用数字比较）
        if [ "$year" -eq "$today_year" ] && [ "$month" -eq "$today_month" ] && [ "$day" -eq "$today_day" ]; then
            printf "\033[7m%2d\033[0m " "$day"
        else
            printf "%2d " "$day"
        fi

        current_col=$((current_col + 1))
        if [ $current_col -eq 7 ]; then
            printf "\n"
            current_col=0
        fi
    done

    # 补末尾换行
    if [ $current_col -ne 0 ]; then
        printf "\n"
    fi
}

# ---------- 获取格式化日历文本(用于并排显示) ----------
_get_formatted_month_calendar() {
    local year="$1"
    local month="$2"

    # 获取原始日历文本
    local calendar_text
    calendar_text=$(_get_month_calendar_text "$year" "$month")

    # 转换为数组
    local IFS=$'\n'
    local lines=($calendar_text)
    unset IFS

    # 确保有8行输出(2行标题 + 最多6行日期)
    local result=()
    local line_count=${#lines[@]}

    for ((i=0; i<8; i++)); do
        if [ $i -lt $line_count ]; then
            # 去除行尾空格,然后左对齐,宽度20
            local line="${lines[i]}"
            line=$(echo "$line" | sed 's/[[:space:]]*$//')
            printf "%-20s" "$line"
        else
            # 补空行
            printf "%-20s" ""
        fi
        result[$i]="$(printf "%-20s" "${lines[i]:-}")"
    done

    # 输出所有行
    for ((i=0; i<8; i++)); do
        printf "%-20s" "${result[i]}"
        if [ $i -lt 7 ]; then
            echo ""
        fi
    done
}
# ---------- 并排显示两个月 ----------
_display_two_months_side_by_side() {
    local year="$1"
    local month1="$2"
    local month2="$3"

    # 获取两个月的日历文本
    local cal1 cal2
    cal1=$(_get_month_calendar_text "$year" "$month1")
    cal2=$(_get_month_calendar_text "$year" "$month2")

    # 转换为数组
    local IFS=$'\n'
    local lines1=($cal1)
    local lines2=($cal2)
    unset IFS

    # 确保两个数组都有8行
    local max_lines=8

    # 并排显示
    for ((i=0; i<max_lines; i++)); do
        local line1="${lines1[i]}"
        local line2="${lines2[i]}"

        # 清理行尾空格
        line1=$(echo "${line1:-}" | sed 's/[[:space:]]*$//')
        line2=$(echo "${line2:-}" | sed 's/[[:space:]]*$//')

        # 格式化输出,左对齐,每列宽度20
        printf "%-20s    %-20s\n" "$line1" "$line2"
    done
}

# ---------- 显示全年日历的内部函数 ----------
_display_year_calendar() {
    local year="$1"

    cecho "══════════════════════════════════════"
    cecho "         $year 年 日历"
    cecho "══════════════════════════════════════"

    # 分6次显示,每次并排显示两个月
    echo ""
    cecho "───────── 1月 和 2月 ─────────"
    _display_two_months_side_by_side "$year" "01" "02"

    echo ""
    cecho "───────── 3月 和 4月 ─────────"
    _display_two_months_side_by_side "$year" "03" "04"

    echo ""
    cecho "───────── 5月 和 6月 ─────────"
    _display_two_months_side_by_side "$year" "05" "06"

    echo ""
    cecho "───────── 7月 和 8月 ─────────"
    _display_two_months_side_by_side "$year" "07" "08"

    echo ""
    cecho "───────── 9月 和 10月 ────────"
    _display_two_months_side_by_side "$year" "09" "10"

    echo ""
    cecho "──────── 11月 和 12月 ────────"
    _display_two_months_side_by_side "$year" "11" "12"
}