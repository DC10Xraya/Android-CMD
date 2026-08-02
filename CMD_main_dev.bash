#!/bin/bash
# Android CMD(VER: ⤸)
CMD_VER="Releases 0.04(dev 0.178)"
# MIT License
# Copyright (c) 2026 DC10Xray
# https://github.com/DC10Xraya/Android-CMD

# ---------运行前检查---------
err() { printf "\033[31m%s\033[0m\n" "$*" >&2; } # 错误样式
CMD_RUNNING_Err_title="----------------CMD ERROR----------------"
CMD_Target="要求:必须由 bash 4.0+ 执行,且支持数组特性"

#bash 
if [ -z "$BASH_VERSION" ]; then
    err "$CMD_RUNNING_Err_title"
    err "请使用 bash 执行!"
    err "$CMD_Target"
    exit 64
fi
if ! (arr=(1 2); (( ${#arr[@]} == 2 ))) 2>/dev/null; then
    err "$CMD_RUNNING_Err_title"
    err "当前 bash 版本过低(4.0-)或功能不完整(不支持数组)"
    err "$CMD_Target"
    exit 70
fi

#必须工具
MISSING=""
for cmd in awk grep sed cat cut head tail; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        MISSING="$MISSING $cmd"
    fi
done
if [ -n "$MISSING" ]; then
    err "$CMD_RUNNING_Err_title"
    err "缺少以下核心命令: $MISSING"
    err "请安装对应的软件包"
    exit 127
fi

#BC
if ! command -v bc >/dev/null 2>&1; then
    err "$CMD_RUNNING_Err_title"
    err "需要BC计算器支持但未检测到BC命令存在"
    err "请安装BC或确保 busybox 包含BC命令"
    exit 127
fi

#防止重复执行
if [ -n "${System_by_DC10XRAY_MIT2026_CMD_ACTIVE}" ]; then
    sleep 0.2
    err "$CMD_RUNNING_Err_title"
    err "脚本已经在此会话活跃运行(检测到活跃变量),请新建一个会话"
    exit 69
fi
export System_by_DC10XRAY_MIT2026_CMD_ACTIVE=1

echo -e "\033[32m---------------CMD Running---------------\033[0m"
# -------正式运行:工具检测与初始化 -------
init_tools() {
    if command -v busybox >/dev/null 2>&1; then
        _AWK="busybox awk"; _CAT="busybox cat"; _CUT="busybox cut"
        _DATE="busybox date"; _GREP="busybox grep"; _HEAD="busybox head"
        _HOSTNAME="busybox hostname"; _IFCONFIG="busybox ifconfig"
        _IP="busybox ip"; _LS="busybox ls"; _MKDIR="busybox mkdir"
        _MV="busybox mv"; _CP="busybox cp"; _RM="busybox rm"
        _RMDIR="busybox rmdir"; _NETSTAT="busybox netstat"
        _PS="busybox ps"; _PING="busybox ping"; _UPTIME="busybox uptime"
        _WHOAMI="busybox whoami"; _FREE="busybox free"; _DF="busybox df"
        _UNAME="busybox uname"; _SED="busybox sed"; _FIND="busybox find"
        _SORT="busybox sort"; _TAIL="busybox tail"; _STAT="busybox stat"
        _WGET="busybox wget"; _CURL="busybox curl"
    else
        _AWK="awk"; _CAT="cat"; _CUT="cut"; _DATE="date"; _GREP="grep"
        _HEAD="head"; _HOSTNAME="hostname"; _IFCONFIG="ifconfig"
        _IP="ip"; _LS="ls"; _MKDIR="mkdir"; _MV="mv"; _CP="cp"
        _RM="rm"; _RMDIR="rmdir"; _NETSTAT="netstat"; _PS="ps"
        _PING="ping"; _UPTIME="uptime"; _WHOAMI="whoami"; _FREE="free"
        _DF="df"; _UNAME="uname"; _SED="sed"; _FIND="find"; _SORT="sort"
        _TAIL="tail"; _STAT="stat"
        _WGET="wget"; _CURL="curl"
    fi
}
init_tools

CMD_delimiter="----------------------------------------------------" #定义分割横线
# ---------- 加载外部资源函数 ----------
# 固定脚本路径, 无论执行方式如何都指向正确位置
export SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export RESOURCE_DIR="$SCRIPT_DIR/resource"

# 声明全局数组, 存储已加载资源的相对路径
declare -a LOADED_RESOURCES=()

# 封装资源加载函数(首次启动和 reload 共用)
load_resources() {
    LOADED_RESOURCES=()
    if [ -d "$RESOURCE_DIR" ]; then
        # 递归查找所有 cmd_*.bash 文件, 按路径排序加载
        while IFS= read -r -d '' file; do
            if [ -f "$file" ]; then
                source "$file"
                # 存储相对于脚本目录的路径, 便于显示
                rel_path="${file#$SCRIPT_DIR/}"
                LOADED_RESOURCES+=("$rel_path")
            fi
        done < <(find "$RESOURCE_DIR" -type f -name "cmd_*.bash" -print0 | sort -z)
    fi
}

# 首次加载资源
load_resources

if [ ${#LOADED_RESOURCES[@]} -eq 0 ]; then
    if [ ! -d "$RESOURCE_DIR" ]; then
        err "警告: resource 目录不存在, 外部命令将不可用" >&2
    else
        err "警告: resource 目录下未找到任何 cmd_*.bash 文件" >&2
    fi
fi

cmd_resource() {
    case "$1" in
        ""|--help|-h)
            cecho -b "用法: RESOURCE [子命令]"
            cecho "  RESOURCE           显示本帮助"
            cecho "  RESOURCE load      列出已加载的外部资源文件"
            cecho "  RESOURCE reload    重载资源(重新扫描并加载所有 cmd_*.bash)"
            echo ""
            cecho "资源文件位于 resource/ 目录及其子目录下, "
            cecho "以 cmd_*.bash 命名, 主程序启动时自动加载"
            cecho "如果某个命令的资源文件缺失, 且这个命令不在主程序内, 则该命令将不可用"
            ;;
        load)
            local show_all=0
            if [ "$2" = "-debug" ]; then
            show_all=1
            fi

        if [ ${#LOADED_RESOURCES[@]} -eq 0 ]; then
        cecho "没有加载任何资源文件"
        return
    fi

        local filtered=()
    for rel_path in "${LOADED_RESOURCES[@]}"; do
        if [ $show_all -eq 1 ]; then
            filtered+=("$rel_path")
        else
            # 过滤laugh/debug
            if [[ ! "${rel_path,,}" =~ laugh|debug ]]; then
                filtered+=("$rel_path")
            fi
        fi
    done

    if [ ${#filtered[@]} -eq 0 ]; then
        cecho "未显示任何可显示资源"
        return
    fi

    cecho -b "已加载的外部资源文件:"
    local idx=1
    for rel_path in "${filtered[@]}"; do
        cecho "  $idx. $rel_path"
        ((idx++))
    done
    ;;
    esac
}
# ---------- 配置文件 ----------
COLOR_CONFIG_FILE="$SCRIPT_DIR/resource/.cmd_config"
TMP_DIR=""   # 默认值, 先定义, 后续由 load_config 或初始化逻辑覆盖

load_config() {
    if [ -f "$COLOR_CONFIG_FILE" ]; then
        while IFS='=' read -r key value; do
            # 跳过空行和注释
            [[ -z "$key" || "$key" == \#* ]] && continue
            # 去除首尾空格
            key="$(echo "$key" | xargs)"
            value="$(echo "$value" | xargs)"
            case "$key" in
                BG)   BG="$value" ;;
                FG)   FG="$value" ;;
                TMPDIR) TMP_DIR="$value" ;;
            esac
        done < "$COLOR_CONFIG_FILE"
    fi
}

save_config() {
    {
        echo "BG=$BG"
        echo "FG=$FG"
        echo "TITLE=$CUSTOM_TITLE"
        echo "TMPDIR=$TMP_DIR"
    } > "$COLOR_CONFIG_FILE" 2>/dev/null
}

load_config
# ---------- 加载随机标语 ----------
declare -a SPLASHES=()
load_splashes() {
    SPLASHES=()
    local splash_file="$RESOURCE_DIR/splashes.txt"
    if [ -f "$splash_file" ]; then
        mapfile -t SPLASHES < "$splash_file"
    fi
}
load_splashes
# ----------关于退出:全局信号控制变量 ----------
GLOBAL_CMD_RUNNING=0
GLOBAL_CHILD_PID=0
GLOBAL_SIGNAL_RECEIVED=0
GLOBAL_EXIT9_ACTIVE=0
GLOBAL_WORKER_PIDS=()
GLOBAL_PROGRESS_PID=0

# ---------- 信号处理函数 ----------
cmd_exit9() {
    if [ $GLOBAL_EXIT9_ACTIVE -eq 1 ]; then return; fi
    GLOBAL_EXIT9_ACTIVE=1

    echo ""
    err "------CMD Stopping/Killed(Exit 130)------" >&2

    # 强制杀死单个子进程
    if [ -n "$GLOBAL_CHILD_PID" ] && kill -0 "$GLOBAL_CHILD_PID" 2>/dev/null; then
        _kill_process_tree_force "$GLOBAL_CHILD_PID"
        GLOBAL_CHILD_PID=0
    fi

    # 强制杀死所有工作进程(SCAN/PORTSCAN)
    if [ ${#GLOBAL_WORKER_PIDS[@]} -gt 0 ]; then
        for pid in "${GLOBAL_WORKER_PIDS[@]}"; do
            if kill -0 "$pid" 2>/dev/null; then
                _kill_process_tree_force "$pid"
            fi
        done
        GLOBAL_WORKER_PIDS=()
    fi

    # 强制杀死进度显示进程(SCAN/PORTSCAN 的 show_progress)
    if [ $GLOBAL_PROGRESS_PID -ne 0 ] && kill -0 "$GLOBAL_PROGRESS_PID" 2>/dev/null; then
        _kill_process_tree_force "$GLOBAL_PROGRESS_PID"
        wait "$GLOBAL_PROGRESS_PID" 2>/dev/null || true
        GLOBAL_PROGRESS_PID=0
    fi

    GLOBAL_SIGNAL_RECEIVED=1
    GLOBAL_EXIT9_ACTIVE=0

    # 清理临时文件(确保在 exit 之前执行)
    cleanup_temp_files

    exit 130
}

cmd_exit15_0() {
    echo "bro 不是这个ctrl+c!!! 但是我还是会帮你"
    sleep 0.2
    cmd_exit15
}

cmd_exit15() {
    echo ""
    err "-------------CMD Exit(Exit15)------------" >&2
    exit 0
}

handle_signal() {
    if [ "$GLOBAL_CMD_RUNNING" -eq 1 ]; then
        cmd_exit9
    else
        cmd_exit15
    fi
}

# ---------- 设置信号捕捉 ----------
trap handle_signal INT TERM QUIT HUP

# ---------- 临时文件清理函数 ----------
cleanup_temp_files() {
    if [ -d "$TMP_DIR" ]; then
        # 清理 PING 产生的临时文件(进程 PID 相关)
        rm -f "$TMP_DIR/ping_tmp_$$_"* 2>/dev/null
        # 清理 SCAN 产生的临时目录
        rm -rf "$TMP_DIR/scan_$$" 2>/dev/null
        # 清理 PORTSCAN 产生的临时目录
        rm -rf "$TMP_DIR/portscan_$$" 2>/dev/null
        # 清理 TREE 产生的临时文件
        rm -f "$TMP_DIR/tree_$$_"* 2>/dev/null
    fi
}

# ------------CECHO 相关------------
# 保存真实终端文件描述符
exec 3>/dev/tty
BG=40   # 默认背景
FG=97   # 默认前景

# 文字输出说明:cecho(无参数,参数见下)为控制台颜色,err为红色,echo、printf保留原有功能
# -n不换行,-c指定前景色,-cb指定背景色,-b粗,-I斜,-u下划线,-s删除线,-r类似默认echo
# c或者cb支持两位数字颜色码和16进制颜色码
# 当 BG 为 40 或 100(背景为0)时,不输出背景(所以请强制使用黑色背景控制台,命令提示符无论何时都有背景)
_cprint() {
    local opt_n=false
    local custom_fg=""   # 可以是 "31" 或 "#FF0000"
    local custom_bg=""   # 可以是 "41" 或 "#00FF00"
    local bold=0 italic=0 underline=0 strikethrough=0
    local plain=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n) opt_n=true; shift ;;
            -c) custom_fg="$2"; shift 2 ;;
            -cb) custom_bg="$2"; shift 2 ;;
            -b) bold=1; shift ;;
            -i) italic=1; shift ;;
            -u) underline=1; shift ;;
            -s) strikethrough=1; shift ;;
            -r) plain=1; shift ;;
            --) shift; break ;;
            *) break ;;
        esac
    done

    local text="$*"

    # 纯文本模式: 忽略所有样式和颜色
    if [ $plain -eq 1 ]; then
        if $opt_n; then
            printf "%s" "$text"
        else
            printf "%s\n" "$text"
        fi
        return
    fi

    # 构建属性列表(样式 + 背景 + 前景)
    local attrs=()
    [ $bold -eq 1 ] && attrs+=("1")
    [ $italic -eq 1 ] && attrs+=("3")
    [ $underline -eq 1 ] && attrs+=("4")
    [ $strikethrough -eq 1 ] && attrs+=("9")

    # ---------- 背景色处理 ----------
    local bg_code=""
    if [ -n "$custom_bg" ]; then
        if [[ "$custom_bg" =~ ^#([0-9A-Fa-f]{6})$ ]]; then
            # 十六进制颜色,转换为 48;2;R;G;B
            local r=$((16#${BASH_REMATCH[1]:0:2}))
            local g=$((16#${BASH_REMATCH[1]:2:2}))
            local b=$((16#${BASH_REMATCH[1]:4:2}))
            bg_code="48;2;$r;$g;$b"
        else
            # 纯数字颜色码,如 41
            bg_code="$custom_bg"
        fi
    elif [ "$BG" != "40" ] && [ "$BG" != "100" ]; then
        bg_code="$BG"
    fi

    # ---------- 前景色处理 ----------
    local fg_code=""
    if [ -n "$custom_fg" ]; then
        if [[ "$custom_fg" =~ ^#([0-9A-Fa-f]{6})$ ]]; then
            local r=$((16#${BASH_REMATCH[1]:0:2}))
            local g=$((16#${BASH_REMATCH[1]:2:2}))
            local b=$((16#${BASH_REMATCH[1]:4:2}))
            fg_code="38;2;$r;$g;$b"
        else
            fg_code="$custom_fg"
        fi
    else
        fg_code="$FG"
    fi

    # 将背景码和前景码加入属性列表(背景在前,前景在后,不影响显示)
    [ -n "$bg_code" ] && attrs+=("$bg_code")
    attrs+=("$fg_code")

    # 生成转义序列
    local attr_str=$(IFS=';'; echo "${attrs[*]}")
    local esc_seq="\033[${attr_str}m"

    if $opt_n; then
        printf "${esc_seq}%s\033[0m" "$text"
    else
        printf "${esc_seq}%s\033[0m\n" "$text"
    fi
}

# cecho 简单封装(默认换行,使用全局 FG)
cecho() { _cprint "$@"; }

# 逐行读取并换行
cprint_block() {
    while IFS= read -r line; do
        _cprint "$line"
    done
}

cmd_color() {
    if [ $# -eq 0 ]; then
        {
            cecho -b "设置控制台默认前景和背景色"
            cecho "COLOR -def            恢复默认颜色(黑底亮白)"
            cecho "COLOR [背景][前景]    设置颜色,如 COLOR 0A"
            echo ""
            cecho -b "颜色代码: "
            cecho "   0 = 黑色       8 = 灰色"
            cecho "   1 = 蓝色       9 = 淡蓝"
            cecho "   2 = 绿色       A = 淡绿"
            cecho "   3 = 青色       B = 淡青"
            cecho "   4 = 红色       C = 淡红"
            cecho "   5 = 紫色       D = 淡紫"
            cecho "   6 = 黄色       E = 淡黄"
            cecho "   7 = 白色       F = 亮白"
            echo ""
            cecho "示例: COLOR 0A    黑色背景亮绿前景"
        }
        return 0
    fi

    if [ "$1" = "-def" ]; then
        BG=40
        FG=97
        save_config
        cecho "颜色已重置为默认值"
        return 0
    fi

    if [ $# -gt 1 ]; then
        err "参数数量错误用法: COLOR [背景][前景] 或 COLOR -def 恢复默认"
        return 1
    fi

    local arg=$(echo "$1" | tr -d ' ' | tr '[:lower:]' '[:upper:]')
    
    if [ ${#arg} -ne 2 ]; then
        err "无效颜色参数使用 COLOR 无参数查看帮助"
        return 1
    fi

    local bg_char=$(echo "$arg" | cut -c1)
    local fg_char=$(echo "$arg" | cut -c2)

    case $bg_char in
        0) BG=40;;   1) BG=44;;   2) BG=42;;   3) BG=46;;
        4) BG=41;;   5) BG=45;;   6) BG=43;;   7) BG=47;;
        8) BG=100;;  9) BG=104;;  A) BG=102;;  B) BG=106;;
        C) BG=101;;  D) BG=105;;  E) BG=103;;  F) BG=107;;
        *) err "无效背景颜色代码 '$bg_char'使用 COLOR 无参数查看帮助"; return 1;;
    esac

    case $fg_char in
        0) FG=30;;   1) FG=34;;   2) FG=32;;   3) FG=36;;
        4) FG=31;;   5) FG=35;;   6) FG=33;;   7) FG=37;;
        8) FG=90;;   9) FG=94;;   A) FG=92;;   B) FG=96;;
        C) FG=91;;   D) FG=95;;   E) FG=93;;   F) FG=97;;
        *) err "无效前景颜色代码 '$fg_char'使用 COLOR 无参数查看帮助"; return 1;;
    esac

    cecho "颜色已设置为背景[$bg_char]前景[$fg_char]"
    save_config
    return 0
}

# ----------重要函数----------
# 二次确认函数
confirm() {
    while true; do
        printf "\033[1;33m%b (Y/N): \033[0m" "$*"
        read -r answer
        case "$answer" in
            [Yy]) return 0 ;;
            [Nn]) return 1 ;;
            *) err "请回答Y或N" ;;
        esac
    done
}

# 递归杀死进程树(你可以在别的地方引用它来杀死一些东西)
_kill_process_tree() {
    local pid=$1
    local sig=$2
    [ -z "$sig" ] && sig="TERM"
    [ "$pid" -eq $$ ] && return

    if [ -d "/proc" ]; then
        local children=$(grep -l "^PPid:[[:space:]]*$pid$" /proc/*/status 2>/dev/null | cut -d/ -f3)
        for child in $children; do
            _kill_process_tree "$child" "$sig"
        done
    fi
    kill -$sig "$pid" 2>/dev/null
    if [ "$sig" != "KILL" ]; then
        local waited=0
        while kill -0 "$pid" 2>/dev/null && [ $waited -lt 5 ]; do
            sleep 0.1
            waited=$((waited + 1))
        done
        if kill -0 "$pid" 2>/dev/null; then
            kill -KILL "$pid" 2>/dev/null
        fi
    fi
}

# 暴力版本
_kill_process_tree_force() {
    local pid=$1
    # 绝不杀自己
    [ "$pid" -eq $$ ] && return

    # 递归杀死所有子进程(通过 /proc)
    if [ -d "/proc" ]; then
        local children=$(grep -l "^PPid:[[:space:]]*$pid$" /proc/*/status 2>/dev/null | cut -d/ -f3)
        for child in $children; do
            _kill_process_tree_force "$child"
        done
    fi
    # 最后杀目标进程
    kill -KILL "$pid" 2>/dev/null
}

# ---------- 文件操作函数 ----------
# 用法: file_op <copy|move> <源1> [源2 ...] <目标>
file_op() {
    local op="$1"
    shift
    if [ $# -lt 2 ]; then
        err "缺少参数"
        return 1
    fi

    # 提取最后一个参数作为目标
    local dest="${!#}"
    # 源参数列表(除最后一个外)
    local sources=("${@:1:$#-1}")

    # 检查目标是否为目录(已存在且是目录)
    local dest_is_dir=0
    if [ -d "$dest" ]; then
        dest_is_dir=1
    fi

    # 如果有多个源,目标必须是目录
    if [ ${#sources[@]} -gt 1 ] && [ $dest_is_dir -eq 0 ] && [ -e "$dest" ]; then
        err "多个源文件时目标必须是目录"
        return 1
    fi

    for src in "${sources[@]}"; do
        if [ ! -e "$src" ]; then
            err "源文件/目录不存在: $src"
            return 1
        fi

        local target="$dest"
        # 如果目标是目录,拼接文件名
        if [ $dest_is_dir -eq 1 ]; then
            local src_basename=$(basename "$src")
            target="$dest/$src_basename"
        fi

        # 检查目标是否存在,若存在则询问覆盖
        if [ -e "$target" ]; then
            confirm "覆盖 $target 吗?" || { cecho "跳过 $src"; continue; }
        fi

        # 执行复制或移动
        if [ "$op" = "copy" ]; then
            if [ -d "$src" ]; then
                # 递归复制目录
                $_CP -r "$src" "$target" 2>/dev/null || { err "复制目录 $src 失败"; return 1; }
            else
                $_CP "$src" "$target" 2>/dev/null || { err "复制文件 $src 失败"; return 1; }
            fi
        else  # move
            $_MV "$src" "$target" 2>/dev/null || { err "移动 $src 失败"; return 1; }
        fi
    done
    return 0
}
# ------------标题------------
CUSTOM_TITLE=""
get_title() {
    # ----- 读取标题配置(每次显示时读取, 确保最新) -----
    if [ -f "$COLOR_CONFIG_FILE" ]; then
        local title_line=$($_GREP -E '^TITLE=' "$COLOR_CONFIG_FILE" | $_HEAD -1)
        if [ -n "$title_line" ]; then
            CUSTOM_TITLE="${title_line#*=}"
            CUSTOM_TITLE="$(echo "$CUSTOM_TITLE" | xargs)"   # 去除首尾空格
        else
            CUSTOM_TITLE=""   # 如果没有 TITLE 行, 置空
        fi
    fi

    # ----- 显示标题 -----
    if [ -n "$CUSTOM_TITLE" ]; then
        cecho "$CUSTOM_TITLE"
    else
        local osver=$(getprop ro.build.version.release 2>/dev/null || echo '?')
        local kernel=$($_UNAME -r 2>/dev/null || echo '?')
        local title_prefix="Android CMD [版本 $CMD_VER]"
        cecho "$title_prefix"
    fi
    cecho "Copyright (c) 2026 DC10Xray"

    # 标语部分不变
    if [ ${#SPLASHES[@]} -gt 0 ]; then
        local random_index=$(( RANDOM % ${#SPLASHES[@]} ))
        local splash="${SPLASHES[$random_index]}"
        _cprint -i -c 93 "$splash"
    fi

    cecho "使用 HELP 或 /? 来查看命令列表(Ctrl+C退出)"
}

# ---------- 临时目录命令 ----------
cmd_tmpdir() {
    if [ $# -eq 0 ]; then
        err "用法: TMPDIR see/set/about"
        cecho "  TMPDIR see         查看当前生效的临时目录"
        cecho "  TMPDIR set <目录>  设置临时目录"
        cecho "  TMPDIR about       显示详细帮助"
        return 1
    fi
    
    case "$1" in
        see)
        cecho "当前临时目录: $TMP_DIR"
        ;;
        set)
            if [ $# -lt 2 ] || [ -z "$2" ]; then
                err "用法: TMPDIR set <目录>"
                return 1
            fi
            local newdir="$2"
            if ! mkdir -p "$newdir" 2>/dev/null; then
                err "无法创建目录 $newdir,请检查路径是否合法且可写"
                return 1
            fi
            local testfile="$newdir/.write_test_$$"
            if touch "$testfile" 2>/dev/null; then
                rm -f "$testfile"
                TMP_DIR="$newdir"
                save_config
                cecho "临时目录已设置为: $TMP_DIR"
            else
                err "目录 $newdir 不可写,请选择其他目录"
                return 1
            fi
            ;;
        about)
            cecho -b "一些命令需要历史目录,所以务必设置(不设置也没关系,有默认的)"
            cecho -b "配置方式(按优先级从高到低): "
            cecho "1. TMPDIR set <目录> (永久保存)"
            cecho "#设置后自动保存到配置文件,重启后生效"
            cecho "2. 默认使用此脚本路径下的tmp文件夹,没有时创建"
            cecho "3. 回退路径: /storage/emulated/0/tmp"
            cecho "#当以上方法均不可用时使用"
            echo ""
            cecho -b "用法:"
            cecho "  TMPDIR see         查看当前生效的临时目录"
            cecho "  TMPDIR set <目录>  设置临时目录"
            cecho "  TMPDIR about       显示本帮助"
            ;;
        *)
            err "用法: TMPDIR see/set/about"
            cecho "  TMPDIR see         查看当前生效的临时目录"
            cecho "  TMPDIR set <目录>  设置临时目录"
            cecho "  TMPDIR about       显示详细帮助"
            return 1
            ;;
    esac
}

# ---------- 命令实现函数 ----------
cmd_help() {
    cecho "$CMD_delimiter"
    cecho -b "文件和目录操作"
    err "警告:任何命令中的文件名都尽量不包含空格(有bug)" #Shell会把空格拆分,带空格的文件名会变成两个分开的文件名
    cecho "  COPY/CP [源...] [目标]    复制文件/目录 ⤸"
    cecho "  -(支持多个源,目标为目录时复制到目录下)"
    cecho "  RM/DEL/ERASE [文件]       删除文件或目录"
    cecho "  RD/RMDIR [目录]           删除空目录"
    cecho "  FIND <关键词/正则表达式> <文件1> [文件2...] ⤸"  
    cecho "  -在指定文件中搜索字符串/正则表达式"
    cecho "  MD/MKDIR [目录]           创建目录"
    cecho "  NEW/TOUCH 文件        -创建新文件或者更新文件时间"
    cecho "  MOVE [源...] [目标]   -移动文件/目录,或重命名(同目录下)"
    cecho "  REN  [旧名] [新名]        重命名文件(=MOVE)"
    cecho "  DIR [路径]                列出目录内容"
    cecho "  DU [目录]                 列出目录大小"
    cecho "  SIZE [文件]               列出文件大小"
    cecho "  STAT <文件> ⤸"
    cecho "  -显示文件的 inode、权限(八进制)、时间戳 #支持一个空格"
    cecho "  LN -s <源> <目标>         创建软链接(符号链接)"
    cecho "  TREE [路径]               显示目录树"
    cecho "  TYPE [文件]               查看文本文件"
    cecho "  MORE < 文件               分页查看文本文件(不支持颜色)"
    cecho "  ZIP <输出文件> <源文件/目录...> [-f 格式] [-l 级别] ⤸"
    cecho "  -创建 ZIP 压缩包(支持目录递归)"
    cecho "  UNZIP <压缩包> [-d 目标]    解压 ZIP 压缩包"
    echo ""
    cecho -b "系统信息"
    cecho "  NOW             显示当前时钟"
    cecho "  CAL [模式/年份] [月份] 显示日历(无参数详细帮助)"
    cecho "  CLOCK           显示实时时间(Ctrl+C退出,每0.1s刷新)"
    cecho "  FREE            显示当前内存使用"
    cecho "  DF              显示磁盘使用情况"
    cecho "  GETPROP [KEY]   系统属性(空KEY分页显示全部)"
    cecho "  ENV/EXPORT      环境变量(空参数帮助)"
    cecho "  UPTIME          系统运行时间"
    cecho "  RES             显示屏幕分辨率与DPI"
    cecho "  BATT            显示电池信息"
    cecho "  SYSTEMINFO      一些系统信息"
    cecho "  TL/TASKLIST     进程列表"
    cecho "  TM/TOP/TASKMGR  任务管理器"
    cecho "  TEMP            显示温度传感器、温度墙和温控状态"
    cecho "  MONITOR ⤸"
    cecho "  -监控时间、内存和温度(按Ctrl+C键退出,约每2s刷新)"
    cecho "  WHOAMI/OP       显示当前用户UID和权限"
    cecho "  WHICH           查找命令路径"
    cecho "  DISK [超时/ms] [-q 仅显示色块] [-w 仅可读写分区] ⤸"
    cecho "  -检测各可读(写)分区的读写速度(Ctrl+C终止) *实验性*"
    cecho "  PWD             显示当前工作目录"
    cecho "  SELF            显示当前脚本路径"
    echo ""
    cecho -b "网络"
    cecho "  NETSTAT     网络连接统计"
    cecho "  HOSTNAME    显示主机名"
    cecho "  FTP         FTP功能(无参数查看详细帮助)"
    cecho "  PING        测试网络连接(Ctrl+C终止,无参数显示详细参数)"
    cecho "  SCAN        扫描网络中的存活主机(Ctrl+C终止,无参数显示详细参数)"
    cecho "  PORTSCAN    扫描指定地址的存活端口(Ctrl+C终止,无参数显示详细参数)"
    cecho "  DOWNLOAD <URL> <本地路径> ⤸"
    cecho "  -下载网络上的文件到本地的指定位置(Ctrl+C停止下载)"
    cecho ""
    cecho "  ST/SPEEDTEST [-u URL] [-t 超时] ⤸"
    cecho "  -网络测速(默认 Cloudflare 10MB,可能消耗流量,Ctrl+C停止测速)"
    echo ""
    cecho -b "编解码与校验(实验性)"
    cecho "  BASE64/B64 [-d] <字符串> / [-d] -f <文件> ⤸"
    cecho "  -Base64编码/解码(-d解码,-f文件)"
    cecho "  URLENCODE <字符串>/-f <文件>         -URL编码(-f文件)"
    cecho "  URLDECODE <URL编码字符串>/-f <文件>  -URL解码(-f文件)"
    cecho "  MD5 <文件>                计算文件的MD5校验和"
    cecho "  SHA1 <文件>               计算文件的SHA1校验和"
    cecho "  CRC32 <文件>              计算文件的CRC32校验和(cksum)"
    cecho "  PSD [-n 长度] [-C 数量] [-a/-u/-l/-d/-s/-c 字符集] ⤸"
    cecho "  -生成符合要求的随机密码(-h/--help帮助)"
    cecho "  RAND [长度]               生成随机数(默认四位数)"
    echo ""
    cecho -b "杂项"
    cecho "  ECHO/PRINT [消息]      显示消息(-h/--help帮助)"
    cecho "  PRINTF/ECHO -e         解析代码的显示消息"
    cecho "  CECHO [参数] [消息]    我自定义的显示消息(-h/--help帮助)"
    cecho "  ERR [消息]             显示错误样式消息(红色)"
    cecho "  YES [内容]             刷屏某一内容直至按下Ctrl+C"
    cecho "  HACK <目标>        穷举可打印字符直到找到目标"
    cecho "  HACK2 <目标>       使用二分法穷举可打印字符直到找到目标"
    cecho "  CALC <表达式>                 整数计算器 ⤸"
    cecho "  -(无参数交互模式,-h/--help帮助,不是整数就死)"
    cecho "  AWKC <表达式>                 AWK计算器 ⤸"
    cecho "  -(无参数交互模式,-h/--help帮助)"
    cecho "  BC [-s 精度] <表达式>         任意精度计算器 ⤸"
    cecho "  -(无参数交互模式,-h/--help帮助,Ctrl+C终止正在进行的计算)"
    cecho "  TIMER [秒数]/[时间戳]  倒计时/闹钟(Ctrl+C取消)"
    cecho "  SLEEP <秒数>           睡眠指定时间(Ctrl+C停止)"
    cecho "  WATCH <秒数> <命令> [参数] ⤸"
    cecho "  -每隔指定时间清除屏幕并运行命令(Ctrl+C终止,无参数帮助)"
    cecho "  REPEAT <次数> <命令> [参数] ⤸"
    cecho "  -重复执行指定次数命令(Ctrl+C终止,无参数帮助)"
    cecho -b "控制台"
    cecho "  CLS/CLEAR/CLEAN        清除屏幕"
    cecho "  CLSNT/CLEARNT/CLEANNT  清除屏幕(无标题)"
    cecho "  COLOR [-def]/[BF](无参数帮助)       设置控制台颜色"
    cecho "  TITLE [-def]/[字符串](无参数帮助)   设置控制台标题"
    cecho "  TMPDIR set [目录]/see/about   设置/查看/关于临时目录"
    cecho "  RESOURCE load/reload          查看加载资源/重新加载资源"
    cecho "  HELP <OR> /?                  此命令列表"
    cecho "  EXIT/EXIT15                   退出"
    cecho "  EXIT9                         调用强制退出"
    cecho -c "#C0C0C0" "  #按下Ctrl+C退出命令, 未说明时退出脚本"
    cecho "$CMD_delimiter"
    cecho "  SH <脚本路径> [参数] ⤸"
    cecho "  -在此脚本内执行外部 SHELL 脚本(Ctrl+C终止目标脚本)"
    cecho "  C/CMD <系统命令> [参数] ⤸"
    cecho "  -执行任意系统命令/内置命令内部名称(Ctrl+C终止)"
    cecho "  ADB <参数>             执行 ADB 命令 *需要激活ADB调试*"
    cecho "  RUNNING <包名>         启动应用程序  *需要权限*"
    cecho "  KILL [-9 (强制终止)/-15 (正常终止)/-2 (中断)] <PID> ⤸"
    cecho "  -终止指定进程(无权限时只能终止此脚本内进程)"
    cecho "$CMD_delimiter"
    echo ""
}

cmd_cls() {
    clear
    printf '\033[3J'
    for i in {1..200}; do echo; done
    printf '\033[H'
    cecho "$CMD_delimiter"
    get_title
    echo ""
    echo ""
}

cmd_cls_no_title() {
    clear
    printf '\033[3J'
    for i in {1..200}; do echo; done
    printf '\033[H'
}

cmd_title() {
    if [ $# -eq 0 ]; then
        echo "用法: TITLE [-def]/[字符串]"
        echo "  TITLE             显示本帮助"
        echo "  TITLE -def        恢复控制台标题为默认值"
        echo "  TITLE <字符串>    设置自定义标题"
        echo "示例: TITLE cmd.exe [版本 16.0]"
        return 0
    fi

    if [ "$1" = "-def" ]; then
        CUSTOM_TITLE=""
        save_config
        cecho "标题已恢复为默认值"
        return 0
    fi

    CUSTOM_TITLE="$*"
    save_config
    cecho "标题已设置为: $CUSTOM_TITLE"
}

cmd_sleep() {
    if [ $# -eq 0 ]; then
        err "用法: sleep <时间>"
        cecho "示例: sleep 5"
        return 0
    fi

    local time_arg="$1"
    # 检查是否为非负数字
    if ! echo "$time_arg" | grep -qE '^[0-9]+(\.[0-9]+)?$'; then
        err "无效的时间值"
        return 1
    fi

    if [ $# -gt 1 ]; then
        err "多余参数"
        return 1
    fi

    # 保存旧的 INT 陷阱,覆盖为自己的处理
    local old_trap=$(trap -p INT)
    local interrupted=0
    trap 'interrupted=1' INT

    cecho "将会睡眠 $time_arg 秒(按Ctrl+C中断)"
    sleep "$time_arg"

    # 恢复原来的 INT 陷阱
    eval "$old_trap" 2>/dev/null

    if [ $interrupted -eq 1 ]; then
        cecho "睡眠被中断"
        return 130
    fi
    cecho "睡眠完成"
}

cmd_yes() {
    local string="$*"
    local prompt
    if [ -z "$string" ]; then
        prompt="您确定要刷屏空内容吗?(Ctrl+C终止)"
    else
        prompt="您确定要刷屏\"$string\"吗?(Ctrl+C终止)"
    fi

    if ! confirm "$prompt"; then
        return 0
    fi
    # 保存旧的 INT 陷阱
    local old_trap=$(trap -p INT)
    local interrupted=0
    local yes_pid=""

    # 设置新的 INT 陷阱: 设置中断标志并杀死后台进程
    trap 'interrupted=1; [ -n "$yes_pid" ] && kill $yes_pid 2>/dev/null' INT

    # 检测 yes 命令是否存在, 若存在则使用, 否则用循环模拟
    if command -v yes >/dev/null 2>&1; then
        yes "$string" &
        yes_pid=$!
    else
        # 使用子 shell 循环, printf 确保空字符串输出空行且不解释转义
        ( while true; do printf '%s\n' "$string"; done ) &
        yes_pid=$!
    fi

    # 等待后台进程结束(可能被信号中断)
    wait $yes_pid 2>/dev/null

    # 恢复旧的 INT 陷阱
    if [ -n "$old_trap" ]; then
        eval "$old_trap"
    else
        trap - INT
    fi

    # 如果被中断, 返回 130
    if [ $interrupted -eq 1 ]; then
        echo "" >&2
        cecho -c 36 "[YES YES YES/YYY]"
        return 130
    fi
}

cmd_echo() {
    # 显示帮助
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        cecho -b "用法: ECHO [-e] [-n] [消息]"
        cecho -b "支持选项:"
        cecho "  -e       启用转义字符解析(如 \\n, \\t)"
        cecho "  -n       不换行输出"
        cecho "  -en/-ne  同时启用 -e 和 -n"
        return 0
    fi

    local opts=()
    local args=()
    # 解析选项(仅支持 -e、-n、-en、-ne)
    while [ $# -gt 0 ]; do
        case "$1" in
            -e) opts+=("-e"); shift ;;
            -n) opts+=("-n"); shift ;;
            -en|-ne) opts+=("-e" "-n"); shift ;;
            *) break ;;
        esac
    done
    local text="$*"   # 剩余所有参数合并为一个字符串(保留空格)

    # 判断是否启用转义解析
    local has_e=0
    local has_n=0
    for opt in "${opts[@]}"; do
        [ "$opt" = "-e" ] && has_e=1
        [ "$opt" = "-n" ] && has_n=1
    done

    if [ $has_e -eq 1 ]; then
        # 使用 printf 的 %b 来解析转义序列
        if [ $has_n -eq 1 ]; then
            printf "%b" "$text"
        else
            printf "%b\n" "$text"
        fi
    else
        # 不解析转义, 直接原样输出
        if [ $has_n -eq 1 ]; then
            printf "%s" "$text"
        else
            printf "%s\n" "$text"
        fi
    fi
}

# ---------- CECHO 命令 ----------
cmd_cecho() {
    # 显示帮助
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then

cecho -b "用法: CECHO [选项] [消息]"
cecho -b "选项:"
cecho "-n              不换行"
cecho "-c <颜色>       设置前景色 (数字颜色码或十六进制码)"
cecho "-cb <颜色>      设置背景色 (数字颜色码或十六进制码)"
cecho "-b              粗体"
cecho "-i              斜体"
cecho "-u              下划线"
cecho "-s              删除线"
cecho "-r              纯文本模式 (忽略所有样式和颜色)"
cecho "-h, --help      显示本帮助"

        return 0
    fi

    # 初始化变量
    local opt_n=false
    local custom_fg=""
    local custom_bg=""
    local bold=0
    local italic=0
    local underline=0
    local strikethrough=0
    local plain=0
    local text_args=()

    # 解析参数
    while [ $# -gt 0 ]; do
        case "$1" in
            -n) opt_n=true; shift ;;
            -c)
                if [ $# -lt 2 ]; then
                    err "选项 -c 需要指定颜色值"
                    return 1
                fi
                custom_fg="$2"; shift 2 ;;
            -cb)
                if [ $# -lt 2 ]; then
                    err "选项 -cb 需要指定颜色值"
                    return 1
                fi
                custom_bg="$2"; shift 2 ;;
            -b) bold=1; shift ;;
            -i) italic=1; shift ;;
            -u) underline=1; shift ;;
            -s) strikethrough=1; shift ;;
            -r) plain=1; shift ;;
            --) shift; break ;;
            -*)
                err "未知选项: $1"
                return 1
                ;;
            *) break ;;
        esac
    done

    # 剩余所有参数视为文本
    text_args=("$@")

    # 构建调用 _cprint 的参数列表
    local call_args=()
    [ "$opt_n" = true ] && call_args+=("-n")
    [ -n "$custom_fg" ] && call_args+=("-c" "$custom_fg")
    [ -n "$custom_bg" ] && call_args+=("-cb" "$custom_bg")
    [ "$bold" -eq 1 ] && call_args+=("-b")
    [ "$italic" -eq 1 ] && call_args+=("-i")
    [ "$underline" -eq 1 ] && call_args+=("-u")
    [ "$strikethrough" -eq 1 ] && call_args+=("-s")
    [ "$plain" -eq 1 ] && call_args+=("-r")

    # 如果存在文本, 将其合并为一个字符串并添加到参数列表
    if [ ${#text_args[@]} -gt 0 ]; then
        local text="${text_args[*]}"
        call_args+=("$text")
    fi

    # 调用底层函数执行输出
    _cprint "${call_args[@]}"
}

cmd_du() {
    if [[ $# -eq 0 ]]; then
        err "用法: DU [目录]"
        cecho "示例: DU /storage/emulated/0"
        cecho "      DU .          # 当前目录"
        return 0
    fi
    if [[ $# -gt 1 ]]; then
        err "只能指定一个目录"
        return 1
    fi
    local target="$1"
    if [[ -d "$target" ]]; then
        local size_output
        size_output=$(du -sh "$target" 2>/dev/null)
        cecho "$size_output"
    else
        err "'$target' 不是目录"
        return 1
    fi
}

cmd_size() {
    if [[ $# -ne 1 ]]; then
        err "用法: SIZE <文件>"
        return 1
    fi
    local target="$1"
    if [[ -f "$target" ]]; then
        local sz
        sz=$(du -sh "$target" 2>/dev/null)
        cecho "$sz"
    else
        err "'$target' 不是普通文件"
        return 1
    fi
}

# ---------- STAT 显示文件信息 ----------
cmd_stat() {
    local file="$*"
    if [[ -z "$file" ]]; then
        err "用法: STAT <文件>"
        return 1
    fi
    if [[ ! -e "$file" ]]; then
        err "文件不存在: $file"
        return 1
    fi

    # 获取文件类型描述
    local file_type="未知"
    if [[ -f "$file" ]]; then
        file_type="常规文件"
    elif [[ -d "$file" ]]; then
        file_type="目录"
    elif [[ -L "$file" ]]; then
        file_type="符号链接"
    elif [[ -b "$file" ]]; then
        file_type="块设备"
    elif [[ -c "$file" ]]; then
        file_type="字符设备"
    elif [[ -p "$file" ]]; then
        file_type="管道"
    elif [[ -S "$file" ]]; then
        file_type="套接字"
    fi

    # 尝试使用系统 stat 并自定义格式(支持 -c)
    if command -v stat >/dev/null 2>&1 && stat -c '%a' "$file" >/dev/null 2>&1; then
        cecho "文件名: $(stat -c '%n' "$file")"
        cecho "类型: $file_type"
        local size_bytes=$(stat -c '%s' "$file")
        local size_hr=$(numfmt --to=iec "$size_bytes" 2>/dev/null || echo "${size_bytes} 字节")
        cecho "大小: $size_hr ($size_bytes 字节)"
        cecho "权限: $(stat -c '%A' "$file") ($(stat -c '%a' "$file"))"
        cecho "所有者: $(stat -c '%U:%G' "$file")"
        cecho "Inode: $(stat -c '%i' "$file")"
        cecho "链接数: $(stat -c '%h' "$file")"
        cecho "修改时间: $(stat -c '%y' "$file" | cut -d'.' -f1 | sed 's/ /  /')"
        cecho "访问时间: $(stat -c '%x' "$file" | cut -d'.' -f1 | sed 's/ /  /')"
        cecho "改变时间: $(stat -c '%z' "$file" | cut -d'.' -f1 | sed 's/ /  /')"
        return 0
    fi

    # 回退: 使用 ls -li 和 date 组合
    local inode perms owner group size mtime atime ctime
    local ls_out
    ls_out=$(ls -li --time-style=+%Y-%m-%d_%H:%M:%S "$file" 2>/dev/null)
    if [[ -z "$ls_out" ]]; then
        err "无法使用 ls 读取文件信息"
        return 1
    fi

    read -r inode perms _ owner group size mtime _ <<< "$ls_out" 2>/dev/null
    local perm_chars="${perms:1}"
    local user_perm="${perm_chars:0:3}"
    local group_perm="${perm_chars:3:3}"
    local other_perm="${perm_chars:6:3}"
    local u_val=0 g_val=0 o_val=0
    [[ ${user_perm:0:1} == 'r' ]] && u_val=$((u_val+4))
    [[ ${user_perm:1:1} == 'w' ]] && u_val=$((u_val+2))
    [[ ${user_perm:2:1} == 'x' ]] && u_val=$((u_val+1))
    [[ ${group_perm:0:1} == 'r' ]] && g_val=$((g_val+4))
    [[ ${group_perm:1:1} == 'w' ]] && g_val=$((g_val+2))
    [[ ${group_perm:2:1} == 'x' ]] && g_val=$((g_val+1))
    [[ ${other_perm:0:1} == 'r' ]] && o_val=$((o_val+4))
    [[ ${other_perm:1:1} == 'w' ]] && o_val=$((o_val+2))
    [[ ${other_perm:2:1} == 'x' ]] && o_val=$((o_val+1))
    local octal_perm=$(printf "%o%o%o" $u_val $g_val $o_val)

    local atime_str=$(ls -lu --time-style=+%Y-%m-%d_%H:%M:%S "$file" 2>/dev/null | awk '{print $6, $7}')
    local ctime_str=$(ls -lc --time-style=+%Y-%m-%d_%H:%M:%S "$file" 2>/dev/null | awk '{print $6, $7}')
    [[ -z "$atime_str" ]] && atime_str="未知"
    [[ -z "$ctime_str" ]] && ctime_str="未知"

    local size_hr=$(numfmt --to=iec "$size" 2>/dev/null || echo "${size} 字节")

    cecho "文件名: $file"
    cecho "类型: $file_type"
    cecho "大小: $size_hr ($size 字节)"
    cecho "权限: $perms ($octal_perm)"
    cecho "所有者: $owner:$group"
    cecho "Inode: $inode"
    cecho "链接数: (未知,ls 输出可能缺此项)"
    cecho "修改时间: $mtime"
    cecho "访问时间: $atime_str"
    cecho "改变时间: $ctime_str"
}

# ---------- LN 创建软链接 ----------
cmd_ln() {
    if [[ $# -ne 3 ]] || [[ "$1" != "-s" ]]; then
        err "用法: LN -s <源> <目标>"
        cecho "示例: LN -s /path/to/original /path/to/link"
        return 1
    fi
    local src="$2"
    local target="$3"

    if [[ ! -e "$src" ]]; then
        err "源文件/目录不存在: $src"
        return 1
    fi

    # 检查目标是否已存在(若是链接则询问覆盖)
    if [[ -e "$target" ]] || [[ -L "$target" ]]; then
        confirm "目标 '$target' 已存在, 是否覆盖?" || { cecho "已取消"; return 0; }
        rm -f "$target" 2>/dev/null || {
            err "无法删除已存在的目标: $target"
            return 1
        }
    fi

    ln -s "$src" "$target" 2>/dev/null
    local ret=$?
    if [[ $ret -eq 0 ]]; then
        cecho "软链接已创建: $target -> $src"
    else
        err "创建软链接失败(错误码 $ret)"
        return $ret
    fi
}

cmd_dir() {
    if [ $# -eq 0 ]; then
        $_LS -l --color=auto 2>&1 | while IFS= read -r line; do cecho "$line"; done
    else
        for path in "$@"; do
            cecho "$path:"
            # 同样处理带参数的ls命令
            $_LS -l --color=auto "$path" 2>&1 | while IFS= read -r line; do cecho "$line"; done
            echo ""
        done
    fi
}

cmd_type() {
    [ $# -eq 0 ] && { err "命令语法不正确"; return; }
    for file in "$@"; do
        if [ -f "$file" ]; then
            $_CAT "$file" 2>&1 | while IFS= read -r line; do cecho "$line"; done
        else
            err "系统找不到指定的文件: $file"
        fi
    done
}

cmd_del() {
    [ $# -eq 0 ] && { err "命令语法不正确"; return; }
    for f in "$@"; do
        if [ -e "$f" ]; then
            confirm "删除 $f 吗?" || { cecho "操作已取消"; continue; }
            if [ -d "$f" ]; then
                $_RM -r "$f" 2>/dev/null && cecho "已删除目录: $f" || err "删除目录 $f 失败"
            else
                $_RM "$f" 2>/dev/null && cecho "已删除文件: $f" || err "删除文件 $f 失败"
            fi
        else
            err "系统找不到指定的路径: $f"
        fi
    done
}

cmd_md() {
    [ $# -eq 0 ] && { err "命令语法不正确"; return; }
    for dir in "$@"; do
        $_MKDIR -p "$dir" 2>/dev/null || err "目录创建失败: $dir"
    done
}

cmd_touch() {
    [ $# -ne 1 ] && { err "用法: TOUCH/NEW 文件名"; return 1; }

    local file="$1"
    local dir=$(dirname "$file")

    # 自动创建父目录(如果不存在)
    if [ -n "$dir" ] && [ ! -d "$dir" ]; then
        mkdir -p "$dir" 2>/dev/null || {
            err "无法创建目录 '$dir', 跳过 '$file'"
            return 1
        }
    fi

    if [ -e "$file" ]; then
        touch "$file" 2>/dev/null && cecho "已更新: $file" || err "无法更新: $file"
    else
        touch "$file" 2>/dev/null && cecho "已创建: $file" || err "创建失败: $file"
    fi
}

cmd_rd() {
    [ $# -eq 0 ] && { err "命令语法不正确"; return; }
    for dir in "$@"; do
        if [ -d "$dir" ]; then
            confirm "删除目录 $dir 吗?" || { cecho "操作已取消"; continue; }
            $_RMDIR "$dir" 2>/dev/null || err "目录删除失败(可能非空): $dir"
        else
            err "系统找不到指定的路径: $dir"
        fi
    done
}

cmd_copy() {
    if [ $# -lt 2 ]; then
        err "命令语法不正确用法: COPY 源... 目标"
        cecho "示例: COPY file1.txt file2.txt ../dir/   # 复制多个文件到目录"
        cecho "      COPY old.txt new.txt               # 复制并重命名(目标不是目录)"
        return 1
    fi

    local dest="${!#}"
    local dest_dir=$(dirname "$dest")
    if [ -n "$dest_dir" ] && [ ! -d "$dest_dir" ]; then
        mkdir -p "$dest_dir" 2>/dev/null || {
            err "无法创建目标目录 '$dest_dir',请检查权限"
            return 1
        }
    fi

    file_op "copy" "$@"
}

cmd_move() {
    if [ $# -lt 2 ]; then
        err "用法: MOVE [源...] [目标]   (重命名时源和目标应在同一目录)"
        cecho "示例: MOVE file1.txt ../dir/       # 移动"
        cecho "      MOVE old.txt new.txt         # 重命名"
        return 1
    fi

    local dest="${!#}"
    local dest_dir=$(dirname "$dest")
    if [ -n "$dest_dir" ] && [ ! -d "$dest_dir" ]; then
        mkdir -p "$dest_dir" 2>/dev/null || {
            err "无法创建目标目录 '$dest_dir',请检查权限"
            return 1
        }
    fi

    file_op "move" "$@"
}

cmd_free() {
    $_FREE -h 2>&1 | while IFS= read -r line; do cecho "$line"; done
}

cmd_monitor() {
    cecho "正在监控时间、内存和温度(按Ctrl+C终止)"
    cecho "$CMD_delimiter"
    
    local saved_bg=$BG
    local saved_fg=$FG
    local stop_monitor=0
    
    # 保存旧的 INT trap, 设置自己的
    local old_trap=$(trap -p INT)
    trap 'stop_monitor=1' INT
    
    # ---------- 1. 定义关键温度传感器路径 ----------
    local thermal_base="/sys/class/thermal"
    local cpu_sensor_path=""
    local gpu_sensor_path=""
    local battery_sensor_path=""
    
    if [ -d "$thermal_base" ]; then
        for zone in "$thermal_base"/thermal_zone*; do
            if [ -d "$zone" ]; then
                local type_file="$zone/type"
                local temp_file="$zone/temp"
                if [ -r "$type_file" ] && [ -r "$temp_file" ]; then
                    local sensor_type=$($_CAT "$type_file" 2>/dev/null | tr -d '\n\r')
                    case "$sensor_type" in
                        cpu-0-0|cpuss-0|cpu-0-1|cpuss-1|cpu-1-0)
                            if [ -z "$cpu_sensor_path" ]; then
                                cpu_sensor_path="$temp_file"
                            fi
                            ;;
                        gpuss-0|gpuss-1|gpu)
                            if [ -z "$gpu_sensor_path" ]; then
                                gpu_sensor_path="$temp_file"
                            fi
                            ;;
                        battery)
                            battery_sensor_path="$temp_file"
                            ;;
                    esac
                fi
            fi
        done
    fi
    
    if [ -z "$battery_sensor_path" ] && [ -r "/sys/class/power_supply/battery/temp" ]; then
        battery_sensor_path="/sys/class/power_supply/battery/temp"
    fi
    
    # ---------- 2. 温度读取函数 ----------
    _read_temp() {
        local sensor_path="$1"
        local default_display="$2"
        if [ -n "$sensor_path" ] && [ -r "$sensor_path" ]; then
            local temp_raw=$($_CAT "$sensor_path" 2>/dev/null | tr -d '\n\r')
            if [ -n "$temp_raw" ]; then
                local temp_c
                if [ "$temp_raw" -gt 1000 ] 2>/dev/null; then
                    temp_c=$(echo "scale=1; $temp_raw / 1000" | bc 2>/dev/null 2>/dev/null || echo "$((temp_raw / 1000))")
                else
                    temp_c="$temp_raw"
                fi
                if echo "$temp_c" | awk -v t="$temp_c" 'BEGIN {if (t > 5 && t < 120) exit 0; else exit 1}' 2>/dev/null; then
                    echo "${temp_c}°C"
                    return
                fi
            fi
        fi
        echo "$default_display"
    }
    
    # ---------- 3. 先输出三行占位 ----------
    printf "\n\n\n"
    
    # ---------- 4. 主显示循环 ----------
    while [ $stop_monitor -eq 0 ]; do
        # 4.1 获取当前时间
        local current_time=$($_DATE "+%Y-%m-%d %a %H:%M:%S")
        
        # 4.2 获取内存信息
        local mem_total_kb mem_free_kb buffers_kb cached_kb
        mem_total_kb=$($_GREP -E '^MemTotal:' /proc/meminfo 2>/dev/null | $_AWK '{print $2}')
        mem_free_kb=$($_GREP -E '^MemFree:' /proc/meminfo 2>/dev/null | $_AWK '{print $2}')
        buffers_kb=$($_GREP -E '^Buffers:' /proc/meminfo 2>/dev/null | $_AWK '{print $2}')
        cached_kb=$($_GREP -E '^Cached:' /proc/meminfo 2>/dev/null | $_AWK '{print $2}')
        
        [ -z "$mem_total_kb" ] && mem_total_kb=0
        [ -z "$mem_free_kb" ] && mem_free_kb=0
        [ -z "$buffers_kb" ] && buffers_kb=0
        [ -z "$cached_kb" ] && cached_kb=0
        
        local mem_used_kb=$((mem_total_kb - mem_free_kb - buffers_kb - cached_kb))
        [ $mem_used_kb -lt 0 ] && mem_used_kb=0
        
        local mem_total_mb=$((mem_total_kb / 1024))
        local mem_used_mb=$((mem_used_kb / 1024))
        
        local percent=0
        if [ $mem_total_mb -gt 0 ]; then
            percent=$(( (mem_used_mb * 100) / mem_total_mb ))
        fi
        
        # 4.3 读取温度
        local cpu_temp=$(_read_temp "$cpu_sensor_path" "N/A")
        local gpu_temp=$(_read_temp "$gpu_sensor_path" "N/A")
        local bat_temp=$(_read_temp "$battery_sensor_path" "N/A")
        
        # ---------- 5. 原地刷新三行 ----------
        printf "\033[3A"
        
        printf "\r\033[K"
        _cprint -c 92 "实时时钟: $current_time"
        
        printf "\r\033[K"
        _cprint -c 93 "内存使用率: $percent%   已用: ${mem_used_mb}M / 总共: ${mem_total_mb}M"
        
        printf "\r\033[K"
        _cprint -c 96 -n "CPU: ${cpu_temp:-N/A}  "
        _cprint -c 95 -n "GPU: ${gpu_temp:-N/A}  "
        _cprint -c 92 "Battery: ${bat_temp:-N/A}"
        
        # 6. 精确等待到下一秒
        if [ $stop_monitor -eq 0 ]; then
            local now_ms
            if date +%s%N >/dev/null 2>&1; then
                now_ms=$(date +%s%N | $_CUT -b1-13 2>/dev/null)
            else
                now_ms=$(date +%s)000
            fi
            
            if [ -n "$now_ms" ]; then
                local current_second=$((now_ms % 1000))
                local sleep_ms=$((1000 - current_second))
                if [ $sleep_ms -gt 0 ]; then
                    local sleep_sec=$(echo "scale=3; $sleep_ms / 1000" | bc 2>/dev/null)
                    if [ -n "$sleep_sec" ]; then
                        sleep $sleep_sec 2>/dev/null || true
                    else
                        sleep 1
                    fi
                fi
            else
                sleep 1
            fi
        fi
    done
    
    # 退出时,清空最后三行并换行
    printf "\033[3A\033[K\n\033[K\n\033[K\n"
    BG=$saved_bg
    FG=$saved_fg
    echo ""
    cecho "已退出监控"
    
    # 恢复旧的 trap
    eval "$old_trap" 2>/dev/null
    return 0
}

cmd_clock() {
    local colors=(31 32 33 34 35 36 37)
    local color_index=0
    local stop=0
    local last_color_time=$(date +%s)

    # 保存旧的 trap, 设置自己的 INT 处理
    local old_trap=$(trap -p INT)
    trap 'stop=1' INT

    cecho "(按Ctrl+C退出时钟显示)"
    cecho "$CMD_delimiter"
    while [ $stop -eq 0 ]; do
        local time_str=$(date "+%Y-%m-%d %a %H:%M:%S")
        local color=${colors[$color_index]}
        printf "\r\033[K\033[1;%sm实时时钟: [%s]\033[0m" "$color" "$time_str"

        local now=$(date +%s)
        if [ $((now - last_color_time)) -ge 1 ]; then
            color_index=$(( (color_index + 1) % ${#colors[@]} ))
            last_color_time=$now
        fi

        sleep 0.1
    done

    printf "\r\033[K\n"
    cecho "时钟已退出"

    # 恢复旧的 trap
    eval "$old_trap" 2>/dev/null
}

cmd_getprop() {
    if ! command -v getprop >/dev/null 2>&1; then
        err "getprop 命令未找到(可能非 Android 环境)"
        return 1
    fi
    if [ $# -eq 0 ]; then
        # 无参数: 分页显示所有属性
        if command -v more >/dev/null 2>&1; then
        cmd_cls_no_title
            getprop | more
        cmd_cls
        else
            getprop | while IFS= read -r line; do cecho "$line"; done
        fi
    else
        # 有参数: 显示指定属性值
        local key="$1"
        local value
        value=$(getprop "$key" 2>/dev/null)
        if [ -n "$value" ]; then
            cecho "$value"
        else
            cecho "[空]"
        fi
    fi
}

cmd_env() {
    # 无参数: 显示帮助
    if [ $# -eq 0 ]; then
        cecho -b "用法:"
        cecho "  ENV                   显示本帮助"
        cecho "  ENV list/show       显示所有环境变量(分页)"
        cecho "  ENV set KEY=VALUE     设置环境变量(也支持 KEY VALUE 空格格式)"
        cecho "  ENV unset KEY         删除环境变量"
        return 0
    fi

    local subcmd="$1"
    shift

    case "$subcmd" in
        list|show)
            # 显示所有环境变量
            if command -v env >/dev/null 2>&1; then
                if command -v more >/dev/null 2>&1; then
                    env | more
                else
                    env | while IFS= read -r line; do cecho "$line"; done
                fi
            elif command -v export >/dev/null 2>&1; then
                if command -v more >/dev/null 2>&1; then
                    export -p | more
                else
                    export -p | while IFS= read -r line; do cecho "$line"; done
                fi
            else
                err "无法显示环境变量"
                return 1
            fi
            ;;

        set)
            if [ $# -eq 0 ]; then
                err "用法: ENV set KEY=VALUE 或 ENV set KEY VALUE"
                return 1
            fi
            local key value
            if [[ "$1" == *=* ]]; then
                key="${1%%=*}"
                value="${1#*=}"
            else
                if [ $# -lt 2 ]; then
                    err "用法: ENV set KEY VALUE"
                    return 1
                fi
                key="$1"
                value="$2"
            fi
            if ! [[ "$key" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
                err "无效的环境变量名: $key"
                return 1
            fi
            export "$key=$value"
            cecho "已设置环境变量: $key=$value"
            ;;

        unset)
            if [ $# -eq 0 ]; then
                err "用法: ENV unset KEY"
                return 1
            fi
            local key="$1"
            if ! [[ "$key" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
                err "无效的环境变量名: $key"
                return 1
            fi
            if unset "$key" 2>/dev/null; then
                cecho "已删除环境变量: $key"
            else
                err "无法删除环境变量: $key"
                return 1
            fi
            ;;

        *)
            err "未知子命令: $subcmd"
            cecho "用法: ENV [list|show|set|unset] ...  或直接输入 ENV 查看帮助"
            return 1
            ;;
    esac
}

cmd_watch() {
    if [ $# -lt 2 ]; then
        err "用法: WATCH <秒数> <命令> [参数]"
        cecho "示例: WATCH 2 systeminfo"
        cecho "      WATCH 5 ls -l /sdcard"
        cecho "提示: 通过<内部命令名称>运行此脚本内置命令"
        cecho "按Ctrl+C随时退出"
        return 1
    fi

    local interval="$1"
    shift
    local cmd_line="$*"

    # 检查间隔是否为有效的正数(整数或小数)
    if ! [[ "$interval" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        err "错误:秒数必须是正数"
        return 1
    fi
    # 使用 bc 检查是否 > 0
    if [ "$(echo "$interval <= 0" | bc)" -eq 1 ]; then
        err "错误:秒数必须大于0"
        return 1
    fi

    if ! confirm "每 ${interval} 秒清屏并执行: \"$cmd_line\"?(按Ctrl+C随时退出)"; then
        cecho "已取消"
        return 0
    fi

    # 保存旧的 INT 陷阱,设置自己的处理
    local old_trap=$(trap -p INT)
    local stop_watch=0
    trap 'stop_watch=1' INT

    while [ $stop_watch -eq 0 ]; do
        cmd_cls_no_title
        eval "$cmd_line"
        if [ $stop_watch -eq 0 ]; then
            sleep "$interval"   # sleep 已支持小数
        fi
    done

    # 恢复旧的陷阱
    if [ -n "$old_trap" ]; then
        eval "$old_trap"
    else
        trap - INT
    fi

    echo ""
    sleep 0.1

    # 退出时询问是否保留当前输出
    if ! confirm "是否保留输出?"; then
    cmd_cls
    fi

    return 0
}

cmd_repeat() {
    if [ $# -lt 2 ]; then
        err "用法: REPEAT <次数> <命令> [参数]"
        cecho "示例: REPEAT 100 echo Hello World"
        cecho "      REPEAT 3 ls -l"
        cecho "按 Ctrl+C 可提前终止"
        return 1
    fi

    local count="$1"
    shift
    local cmd_line="$*"

    # 验证次数为正整数
    if ! [[ "$count" =~ ^[0-9]+$ ]] || [ "$count" -eq 0 ]; then
        err "次数必须是正整数"
        return 1
    fi

    if ! confirm "执行 \"$cmd_line\" *$count?(按Ctrl+C随时退出)"; then
        cecho "已取消"
        return 0
    fi

    # 保存旧的 INT 陷阱,设置自己的处理
    local old_trap=$(trap -p INT)
    local stop_repeat=0
    trap 'stop_repeat=1' INT

    local i
    for ((i=1; i<=count; i++)); do
        if [ $stop_repeat -eq 1 ]; then
            break
        fi
        eval "$cmd_line"
    done

    # 恢复旧的 INT 陷阱
    if [ -n "$old_trap" ]; then
        eval "$old_trap"
    else
        trap - INT
    fi

    if [ $stop_repeat -eq 1 ]; then
        echo ""
        cecho "REPEAT 已被用户中断 (执行了 $((i-1)) 次)"
        return 130
    else
        cecho "REPEAT 完成 (共执行 $count 次)"
        return 0
    fi
}

cmd_which() {
    [ $# -eq 0 ] && { err "用法: WHICH <命令>"; return 1; }
    local path=$(command -v "$1" 2>/dev/null)
    [ -n "$path" ] && cecho "$path" || err "未找到命令: $1"
}

cmd_tasklist() {
    cecho "进程列表"
    cecho "$CMD_delimiter"
    # 标题, 宽度与数据一致(任务管理器风格)
    printf "  %-6s %-9s %-14s %5s\n" "PID" "USER" "TASK" "RSS"

    local top_output=$(top -n 1 -b 2>/dev/null)
    local pid_line=$(echo "$top_output" | grep -n '^[ ]*PID' | head -1 | cut -d: -f1)
    if [ -n "$pid_line" ]; then
        # 取前 20 个进程
        echo "$top_output" | tail -n +$((pid_line+1)) | head -n 20 | awk '{
            if (NF < 8) next;
            pid=$1; user=$2; res=$6; cmd=$NF;
            if (length(cmd)>12) cmd=substr(cmd,1,12)"..";
            printf "  %-6s %-9s %-14s %5s\n", pid, user, cmd, res
        }'
    else
        # 回退到 ps
        err "无法从 top 获取进程列表, 使用 ps 回退"
        if ps -A -o pid,user,comm,rss 2>/dev/null | head -n1 | grep -q "PID"; then
            ps -A -o pid,user,comm,rss 2>/dev/null | tail -n +2 | head -n 20 | awk '{
                pid=$1; user=$2; cmd=$3; rss=$4;
                if (rss ~ /^[0-9]+$/ && rss > 0) {
                    rss_mb = rss/1024;
                    if (rss_mb >= 1000) val = sprintf("%.0fM", rss_mb);
                    else val = sprintf("%.1fM", rss_mb);
                    # 固定宽度 5 右对齐
                    rss_str = sprintf("%5s", val);
                } else {
                    rss_str = "  N/A";
                }
                if (length(cmd)>12) cmd=substr(cmd,1,12)"..";
                printf "  %-6s %-9s %-14s %5s\n", pid, user, cmd, rss_str;
            }'
        else
            cecho "无可用进程数据"
        fi
    fi
}

# RUNNING
cmd_running() {
    if [ $# -eq 0 ]; then
        err "用法: RUNNING <包名>"
        cecho "示例: RUNNING com.android.settings"
        return
    fi
    
    local pkg="$1"

    # 获取当前 Android 用户 ID(通常为 0)
    local user_id
    user_id=$(am get-current-user 2>/dev/null)
    [ -z "$user_id" ] && user_id=0

    # 方式一: 标准启动(不依赖解析 Activity 名)
    if am start -a android.intent.action.MAIN \
                -c android.intent.category.LAUNCHER \
                --user "$user_id" \
                "$pkg" >/dev/null 2>&1; then
        cecho "已启动 $pkg"
        return
    fi

    # 方式二: 解析主 Activity 名后启动
    local act
    act=$(pm resolve-activity --brief "$pkg" 2>/dev/null | grep '/' | head -1)
    if [ -n "$act" ]; then
        if am start -n "$act" --user "$user_id" >/dev/null 2>&1; then
            cecho "已启动 $pkg"
            return
        fi
    fi

    # 方式三: 使用 monkey 兜底
    if monkey -p "$pkg" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1; then
        cecho "已启动 $pkg"
        return
    fi

    err "无法启动 $pkg"
}

cmd_systeminfo() {
    # ===== 基础信息 =====
    local hostname=$($_HOSTNAME 2>/dev/null || $_CAT /proc/sys/kernel/hostname 2>/dev/null || echo 'unknown')
    local osver=$(getprop ro.build.version.release 2>/dev/null || echo '?')
    local sdkver=$(getprop ro.build.version.sdk 2>/dev/null || echo '?')
    local manuf=$(getprop ro.product.manufacturer 2>/dev/null || echo '?')
    local model=$(getprop ro.product.model 2>/dev/null || echo '?')
    local cpu=$($_CAT /proc/cpuinfo 2>/dev/null | $_GREP -E 'Processor|Hardware' | $_HEAD -1 | $_CUT -d: -f2- | $_SED 's/^[ \t]*//')
    [ -z "$cpu" ] && cpu="unknown"
    local kernel=$($_UNAME -r 2>/dev/null || echo 'unknown')

    # ===== CPU核心数 =====
    local cpu_cores=$($_GREP -c '^processor' /proc/cpuinfo 2>/dev/null)
    [ -z "$cpu_cores" ] && cpu_cores="未知"

    # ===== 内存信息 =====
    local mem_total_kb=$($_CAT /proc/meminfo 2>/dev/null | $_GREP 'MemTotal' | $_AWK '{print $2}')
    local mem_avail_kb=$($_CAT /proc/meminfo 2>/dev/null | $_GREP 'MemAvailable' | $_AWK '{print $2}')
    local mem_used_kb=""
    local mem_percent=""
    local mem_total_display="未知"
    local mem_avail_display="未知"
    local mem_used_display="未知"

    if [ -n "$mem_total_kb" ] && [ -n "$mem_avail_kb" ]; then
        mem_used_kb=$((mem_total_kb - mem_avail_kb))
        mem_percent=$(( (mem_used_kb * 100) / mem_total_kb ))
        mem_total_display="${mem_total_kb} kB"
        mem_avail_display="${mem_avail_kb} kB"
        mem_used_display="${mem_used_kb} kB"
    else
        mem_percent="?"
    fi

    # ===== 运行时间 & 负载 =====
    local uptime_raw=$(uptime 2>/dev/null)
    [ -z "$uptime_raw" ] && uptime_raw="无法获取"

    # ===== 温度传感器 =====
    local thermal_base="/sys/class/thermal"
    local cpu_sensor=""
    local gpu_sensor=""
    local battery_sensor=""
    if [ -d "$thermal_base" ]; then
        for zone in "$thermal_base"/thermal_zone*; do
            [ -d "$zone" ] || continue
            local type_file="$zone/type"
            local temp_file="$zone/temp"
            [ -r "$type_file" ] && [ -r "$temp_file" ] || continue
            local sensor_type=$($_CAT "$type_file" 2>/dev/null | tr -d '\n\r')
            case "$sensor_type" in
                cpu-0-0|cpuss-0|cpu-0-1|cpuss-1|cpu-1-0) [ -z "$cpu_sensor" ] && cpu_sensor="$temp_file" ;;
                gpuss-0|gpuss-1|gpu) [ -z "$gpu_sensor" ] && gpu_sensor="$temp_file" ;;
                battery) battery_sensor="$temp_file" ;;
            esac
        done
    fi
    [ -z "$battery_sensor" ] && [ -r "/sys/class/power_supply/battery/temp" ] && battery_sensor="/sys/class/power_supply/battery/temp"

    _get_temp() {
        local path="$1"
        [ -n "$path" ] && [ -r "$path" ] || { echo "N/A"; return; }
        local raw=$($_CAT "$path" 2>/dev/null | tr -d '\n\r')
        [ -z "$raw" ] && { echo "N/A"; return; }
        if [ "$raw" -gt 1000 ] 2>/dev/null; then
            raw=$((raw / 1000))
        fi
        if [ "$raw" -gt 5 ] && [ "$raw" -lt 120 ] 2>/dev/null; then
            echo "${raw}°C"
        else
            echo "N/A"
        fi
    }

    local cpu_temp=$(_get_temp "$cpu_sensor")
    local gpu_temp=$(_get_temp "$gpu_sensor")
    local bat_temp=$(_get_temp "$battery_sensor")

    # ===== 最终输出 =====
    {
        cecho -b "系统信息"
        cecho "$CMD_delimiter"
        cecho "主机名: $hostname"
        cecho "系统版本: Linux(Android $osver, SDK $sdkver) (内核 $kernel)"
        cecho "制造商: $manuf"
        cecho "型号: $model"
        cecho "处理器: $cpu"
        cecho "CPU核心数: $cpu_cores"
        cecho "$CMD_delimiter"
        cecho "内存使用率: ${mem_percent}%"
        cecho "总内存: $mem_total_display"
        cecho "可用内存: $mem_avail_display"
        cecho "已用内存: $mem_used_display"
        cecho "$CMD_delimiter"
        cecho "CPU温度: $cpu_temp    GPU温度: $gpu_temp    电池温度: $bat_temp"
        cecho "$CMD_delimiter"
        cecho "运行时间及负载: $uptime_raw"
        cecho "$CMD_delimiter"
    }
}

cmd_find() {
    if [ $# -lt 2 ]; then
        err "用法: FIND <关键词/正则表达式> <文件1> [文件2...]"
    else
        local pattern="$1"; shift
        $_GREP "$pattern" "$@" 2>&1 | while IFS= read -r line; do cecho "$line"; done
    fi
}

cmd_more() {
    if [ -z "$1" ]; then
        err "命令语法不正确"
        return 1
    fi
    if command -v more >/dev/null 2>&1; then
        more "$1"
    else
        err "系统未找到 more 命令"
        return 1
    fi
}

#TREE
cmd_tree() {
    local path="${1:-.}"
    if [ ! -d "$path" ]; then
        err "系统找不到指定的路径"
        return
    fi
    # 获取绝对路径,失败则使用原路径
    path=$(cd "$path" 2>/dev/null && pwd) || path="$(realpath "$path" 2>/dev/null || echo "$path")"

    # 确定临时目录基础路径
    local tmp_base="$TMP_DIR"
    if [ ! -d "$tmp_base" ]; then
        mkdir -p "$tmp_base" 2>/dev/null || { err "无法创建或访问临时目录: $tmp_base"; return; }
    fi
    if [ ! -w "$tmp_base" ]; then
        err "临时目录不可写: $tmp_base"; return;
    fi

    # 生成唯一的临时文件前缀,使用进程ID、脚本运行时间戳和随机数
    local tmp_prefix="tree_$$_$(date +%s%N)_${RANDOM:-$$}_"

    _tree_recursive() {
        local dir="$1"
        local prefix="$2"
        # 为当前递归层级创建专用临时文件
        local tmpfile
        tmpfile=$(mktemp -p "$tmp_base" "${tmp_prefix}XXXXXX" 2>/dev/null) || {
            tmpfile="$tmp_base/${tmp_prefix}$(od -An -N4 -tu4 /dev/urandom 2>/dev/null | tr -d ' ')"
            if ! touch "$tmpfile" 2>/dev/null; then
                err "无法创建临时文件"; return 1;
            fi
        }
        # 确保退出时清理临时文件
        trap 'rm -f "$tmpfile" 2>/dev/null' RETURN

        # 列出目录内容并排序
        if ls -A "$dir" >/dev/null 2>&1; then
            ls -A "$dir" | $_SORT 2>/dev/null > "$tmpfile"
        else
            ls -a "$dir" 2>/dev/null | $_GREP -v '^\.$' | $_GREP -v '^\.\.$' | $_SORT 2>/dev/null > "$tmpfile"
        fi
        local count=0
        if [ -s "$tmpfile" ]; then
            count=$($_AWK 'END {print NR}' "$tmpfile" 2>/dev/null)
        fi
        if [ -z "$count" ] || [ "$count" -eq 0 ]; then
            return
        fi
        local i=0
        while IFS= read -r entry; do
            i=$((i+1))
            local full="$dir/$entry"
            local is_last=0
            [ $i -eq $count ] && is_last=1

            local connector="├── "
            local child_prefix="${prefix}│   "
            if [ $is_last -eq 1 ]; then
                connector="└── "
                child_prefix="${prefix}    "
            fi

            if [ -d "$full" ]; then
                _cprint -c 34 "${prefix}${connector}${entry}"
                _tree_recursive "$full" "$child_prefix"
            else
                _cprint "${prefix}${connector}${entry}"
            fi
        done < "$tmpfile"
        # 临时文件由 trap 清理
    }

    local rootname=$(basename "$path")
    [ -z "$rootname" ] && rootname="/"
    _cprint -c 32 "$rootname"
    _tree_recursive "$path" ""
}

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

    local result
    result=$(bc -l <<< "$bc_script" 2>&1)
    if [ $? -ne 0 ]; then
        err "计算错误: $result"
        return 1
    fi

    if echo "$result" | grep -qi "divide by zero\|Math error: divide by 0"; then
        err "计算错误: 除数不能为零"
        return 1
    elif echo "$result" | grep -qi "Parse error\|syntax error"; then
        err "表达式解析错误"
        return 1
    elif [ -z "$result" ]; then
        err "计算错误(无输出)"
        return 1
    fi

    result=$(echo "$result" | sed ':a; /\\$/ { N; s/\\\n//; ta }' 2>/dev/null || echo "$result")
    if [ "$prefix_mode" = "prefix" ]; then
        cecho "结果: $result"
    else
        cecho "$result"
    fi
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

# ---------- ADB 命令 ----------
cmd_adb() {
    if [ $# -eq 0 ]; then
        err "用法: ADB <参数>"
        cecho "示例: ADB devices"
        return 1
    fi
    if ! confirm "确认要执行此ADB命令吗?(请确认命令是否安全!)"; then
        cecho "已取消执行"
        return 0
    fi
    #调用系统adb
    if command -v adb >/dev/null 2>&1; then
        adb "$@" 2>&1 | while IFS= read -r line; do cecho "$line"; done
    else
        err "未找到 adb 命令"
        return 1
    fi
}

cmd_cmd() {
    if [ $# -eq 0 ]; then
        err "用法: C/CMD <系统命令> [参数]"
        cecho "示例: C/CMD ls -l"
        return 1
    fi

    local raw_cmd="$*"
    local compact=$(printf "%s" "$raw_cmd" | tr -d '[[:space:]]"' | tr -d "'")
    if [[ "$compact" == *":(){"* && "$compact" == *":|:&"* ]]; then
        err "检测到你的命令貌似是个炸弹!"
        cecho "如果你想执行这样的炸弹,请输入并运行 cmd_bomb_fork"
        cecho "如果误判了你的安全命令,请向作者反馈"
        echo ""
        return 0
    fi

    if ! confirm "确认要执行这个命令吗?(请确认命令是否安全!)"; then
        cecho "已取消执行"
        return 0
    fi

    local old_trap=$(trap -p INT)
    local child_pid=""
    local interrupted=0

    trap 'interrupted=1; [ -n "$child_pid" ] && kill -INT "$child_pid" 2>/dev/null' INT

    eval "$@" &
    child_pid=$!
    wait "$child_pid"
    local exit_code=$?

    eval "$old_trap" 2>/dev/null || trap - INT

    if [ $interrupted -eq 1 ]; then
        echo ""
        cecho "命令被中断"
        return 130
    elif [ $exit_code -ne 0 ]; then
        echo ""
        err "命令以退出码 $exit_code 退出"
        return $exit_code
    else
        echo ""
        cecho "命令执行完毕"
        return 0
    fi
}

cmd_sh() {
    local force=0
    # 1. 检测第一个参数是否为 --force
    if [[ "$1" == "--force" ]]; then
        force=1
        shift
    fi

    if [ $# -eq 0 ]; then
        err "用法: SH <脚本路径> [参数]"
        return 1
    fi

    local script="$1"
    shift

    # 检查脚本文件是否存在且可读
    if [ ! -f "$script" ]; then
        err "脚本文件不存在: $script"
        return 1
    fi
    if [ ! -r "$script" ]; then
        err "脚本文件不可读: $script"
        return 1
    fi

    # 炸弹检测
    local content
    content=$($_CAT "$script" 2>/dev/null)
    if [ -n "$content" ]; then
        local compact=$(printf "%s" "$content" | tr -d '[[:space:]]"' | tr -d "'")
        if [[ "$compact" == *":(){"* && "$compact" == *":|:&"* ]]; then
            # ------- 新增检测分支 -------
            if [ $force -eq 1 ]; then
                # 如果使用了 --force
                if ! confirm "检测到炸弹内容, 但使用了 --force! 你确定要强制运行这个脚本吗?(如果你已经确认脚本安全)"; then
                    cecho "已取消执行"
                    return 0
                fi
            else
                err "检测到脚本内容包含炸弹!"
                cecho "如果你想执行这样的炸弹, 请输入并运行 cmd_bomb_fork"
                cecho "如果误判了你的安全脚本, 请向作者反馈"
                cecho "如果你确认脚本安全, 请使用 --force(这个参数必须是第一个) 强制执行"
                return 0
            fi
        fi
    fi

    # 确认执行
    if ! confirm "确认要执行此脚本吗?(请确认脚本中不含有危险代码!)"; then
        cecho "已取消执行"
        return 0
    fi

    cecho "执行脚本: $script"
    local old_trap=$(trap -p INT)
    local child_pid=""
    local interrupted=0
    trap 'interrupted=1; [ -n "$child_pid" ] && kill -INT "$child_pid" 2>/dev/null' INT

    sh "$script" "$@" &
    child_pid=$!
    wait "$child_pid"
    local exit_code=$?

    eval "$old_trap" 2>/dev/null || trap - INT

    if [ $interrupted -eq 1 ]; then
        echo ""
        cecho "脚本被用户中断"
        return 130
    elif [ $exit_code -ne 0 ]; then
        echo ""
        err "脚本以退出码 $exit_code 退出"
        return $exit_code
    else
        echo ""
        cecho "脚本执行完成"
        return 0
    fi
}

# ---------- KILL 命令 ----------
cmd_kill() {
    if [ $# -eq 0 ]; then
        err "用法: KILL <PID> / KILL -9 <PID> (强制终止) / KILL -2 <PID> (中断)"
        err "使用 TASKLIST 查看进程列表"
        return 1
    fi

    local signal="TERM"  # 默认发送 TERM 信号
    local pid=""
    
    # 解析参数
    if [ "$1" = "-9" ] || [ "$1" = "-KILL" ] || [ "$1" = "-SIGKILL" ]; then
        signal="KILL"
        shift
        if [ $# -eq 0 ]; then
            err "需要指定进程ID用法: KILL -9 <PID>"
            return 1
        fi
    elif [ "$1" = "-15" ] || [ "$1" = "-TERM" ] || [ "$1" = "-SIGTERM" ]; then
        signal="TERM"
        shift
        if [ $# -eq 0 ]; then
            err "需要指定进程ID用法: KILL -15 <PID>"
            return 1
        fi
    elif [ "$1" = "-2" ] || [ "$1" = "-INT" ] || [ "$1" = "-SIGINT" ]; then
        signal="INT"
        shift
        if [ $# -eq 0 ]; then
            err "需要指定进程ID用法: KILL -2 <PID>"
            return 1
        fi
    fi

    pid="$1"
    
    # 验证 PID 是否为数字
    if ! echo "$pid" | $_GREP -qE '^[0-9]+$'; then
        err "无效的进程ID: $pid (必须为数字)"
        return 1
    fi

    # 检查进程是否存在
    if ! $_PS -p "$pid" >/dev/null 2>&1; then
        err "进程 $pid 不存在或已终止"
        return 1
    fi

    # 获取进程信息(用于显示)
    local proc_info=""
    if command -v ps >/dev/null 2>&1; then
        proc_info=$($_PS -o pid,user,comm= -p "$pid" 2>/dev/null | tail -1)
    else
        # 简单回退
        proc_info="PID: $pid"
    fi

    # 确认操作
    if [ "$signal" = "KILL" ]; then
        cecho "将发送 SIGKILL (强制终止) 信号给进程 $pid"
        cecho "进程信息: $proc_info"
        echo ""
        if ! confirm "确定要强制终止此进程吗?"; then
            cecho "操作已取消"
            return 0
        fi
    else
        cecho "将发送 SIG$signal 信号给进程 $pid"
        cecho "进程信息: $proc_info"
        echo ""
        if ! confirm "确定要终止此进程吗?"; then
            cecho "操作已取消"
            return 0
        fi
    fi

    # 尝试终止进程
    if kill -$signal "$pid" 2>/dev/null; then
        cecho "已发送 SIG$signal 信号到进程 $pid"
        
        # 如果是 TERM 信号,等待并检查是否真的终止了
        if [ "$signal" = "TERM" ] || [ "$signal" = "INT" ]; then
            cecho "等待进程退出..."
            local waited=0
            while kill -0 "$pid" 2>/dev/null && [ $waited -lt 5 ]; do
                sleep 0.5
                waited=$((waited + 1))
            done
            
            if kill -0 "$pid" 2>/dev/null; then
                cecho "进程 $pid 未响应 SIG$signal,尝试强制终止..."
                if kill -KILL "$pid" 2>/dev/null; then
                    cecho "已强制终止进程 $pid"
                else
                    err "强制终止失败,进程可能已被保护或无权限"
                    return 1
                fi
            else
                cecho "进程 $pid 已成功终止"
            fi
        fi
        return 0
    else
        # 检查失败原因
        local kill_result=$?
        case $kill_result in
            1)
                err "操作不允许: 无权限终止进程 $pid"
                cecho "可能需要 ROOT 或 ADB 权限才能终止此进程"
                ;;
            127)
                err "命令执行失败: KILL 命令不可用"
                ;;
            *)
                err "终止进程失败 (错误码: $kill_result)"
                ;;
        esac
        return 1
    fi
}
# ---------- debug ----------
debug_help() {
cecho "$CMD_delimiter"
err "#以下显示的是debug命令:"
cecho "debug___/debug_help_/help_debug_ -ME"
cecho "debug_0/debug_priv_level <root/adb/normal/[空]> -更改我认为的你的权限"
cecho "debug_1/debug_exit <退出码> -以任意退出码退出"
cecho "debug_2/debug_load/cmd_resource load -debug -查看隐藏资源(默认屏蔽调试和laugh命令)"
cecho "debug_3/debug_line -统计行数"
cecho "$CMD_delimiter"
err "#以下显示的是\$iamvar命令"
cecho "114514/1145141919810 -error stink"
cecho "100/dev100/dev_build_0.100 -正如名字所说"
cecho "yesyesyes/yyy/yy/yesyes -YES YES YES!!!"
cecho "command not found/commandnotfound -command not found!!!"
err "cmd_bomb_fork -炸弹,将会导致设备死机!!!"
cecho "$CMD_delimiter/CMD_delimiter -无意义"
cecho "wtf -wtffffffff"
cecho "wtf2 -wtffffffff"
cecho "$CMD_delimiter"
}
debug_0() {
    if [ $# -eq 0 ]; then
        PRIV_LEVEL="$PRIV_LEVEL_0"
        cecho "已恢复到: $PRIV_LEVEL"
    else
        case "$1" in
            root|adb|normal) PRIV_LEVEL="$1" ;;
            *) err "无效调试参数"; return 1 ;;
        esac
    fi
    # 同步更新提示符符号
    case "$PRIV_LEVEL" in
        root) PROMPT_SYMBOL="#" ;;
        adb)  PROMPT_SYMBOL="$" ;;
        *)    PROMPT_SYMBOL="->" ;;
    esac
}
debug_1() {
    local code="$1"
    if [[ -z "$code" ]]; then
        err "无调试参数" >&2
        return 1
    fi
    if [[ ! "$code" =~ ^-?[0-9]+$ ]]; then
        err "此命令调试参数必须为数字" >&2
        return 1
    fi
    exit "$code"
}
debug_3() {
    # 主程序
    local main_lines=$(wc -l < "$0" 2>/dev/null)
    [[ -z "$main_lines" ]] && main_lines=0
    local main_bytes=$(wc -c < "$0" 2>/dev/null)
    [[ -z "$main_bytes" ]] && main_bytes=0

    # 统计 resource 目录
    local res_total=0
    local res_bytes=0
    local file_count=0
    if [[ -d "$RESOURCE_DIR" ]]; then
        while IFS= read -r -d '' file; do
            local lines=$(wc -l < "$file" 2>/dev/null)
            if [[ $? -eq 0 ]]; then
                res_total=$((res_total + lines))
                ((file_count++))
                # 增加字节数统计
                local bytes=$(wc -c < "$file" 2>/dev/null)
                [[ -n "$bytes" ]] && res_bytes=$((res_bytes + bytes))
            fi
        done < <(find "$RESOURCE_DIR" -type f -name "*.bash" -print0 2>/dev/null)
    fi

    cecho -b "--- 代码统计 ---"
    cecho "主程序 ($(basename "$0")): $main_lines 行, $main_bytes 字节"
    if [[ $file_count -gt 0 ]]; then
        cecho "资源目录 (共 $file_count 个 .bash 文件): $res_total 行, $res_bytes 字节"
    else
        err "资源目录未发现bash文件"
    fi
    cecho -b "总行数: $((main_lines + res_total))  总字节数: $((main_bytes + res_bytes))"
}
# ---------- 主逻辑 ---------
# 标题
get_title
echo ""
echo ""

# ---------- 初始化临时目录 ----------
# 如果 TMP_DIR 未设置或无效, 则回退到默认
if [ -z "$TMP_DIR" ] || [ ! -d "$TMP_DIR" ] || [ ! -w "$TMP_DIR" ]; then
    if mkdir -p "$SCRIPT_DIR/tmp" 2>/dev/null && [ -w "$SCRIPT_DIR/tmp" ]; then
        TMP_DIR="$SCRIPT_DIR/tmp"
    else
        TMP_DIR="/storage/emulated/0/tmp"
        mkdir -p "$TMP_DIR" 2>/dev/null || true
    fi
fi

# 获取当前用户名(一次)
USERNAME=$($_WHOAMI 2>/dev/null || id -un 2>/dev/null || echo 'user')

# 查询权限并设定提示符
PRIV_LEVEL="normal"
ADB_TCP_PORT=""
# 1. 检测 Root
if [ "$(id -u 2>/dev/null)" = "0" ] || [ "$(whoami 2>/dev/null)" = "root" ]; then
    PRIV_LEVEL="root"
# 2. 检测 Shizuku(基于进程特征: shell用户 + app_process + shizuku)
else
    shizuku_detected=0
    if $_PS -A -o user,args 2>/dev/null | $_GREP -v grep | $_GREP -qE '^shell.*shizuku' 2>/dev/null; then
        shizuku_detected=1
    elif $_PS -e -o user,args 2>/dev/null | $_GREP -v grep | $_GREP -qE '^shell.*shizuku' 2>/dev/null; then
        shizuku_detected=1
    elif $_PS 2>/dev/null | $_GREP -v grep | $_GREP -qE 'shell.*shizuku' 2>/dev/null; then
        shizuku_detected=1
    fi

    if [ $shizuku_detected -eq 1 ]; then
        PRIV_LEVEL="adb"
    else
        # 3. 检测常规 ADB
        is_adb=0
        if [ -n "$ADB_SHELL" ] || [ -n "$ASH_STARTED" ] || \
           (echo "$PPID" | xargs ps -o comm= 2>/dev/null | $_GREP -qi 'adbd'); then
            is_adb=1
        fi

        prop_tcpport=$(getprop service.adb.tcp.port 2>/dev/null)
        prop_state=$(getprop init.svc.adbd 2>/dev/null)
        if [ "$prop_state" = "running" ]; then
            is_adb=1
        fi
        if [ -n "$prop_tcpport" ] && [ "$prop_tcpport" -gt 0 ] 2>/dev/null; then
            is_adb=1
            ADB_TCP_PORT="$prop_tcpport"
        fi

        if [ $is_adb -eq 1 ]; then
            PRIV_LEVEL="adb"
        else
            PRIV_LEVEL="normal"
        fi
    fi
fi
# 根据权限设定符号
case "$PRIV_LEVEL" in
    root) PROMPT_SYMBOL="#" ;;
    adb)  PROMPT_SYMBOL="$" ;;
    *)    PROMPT_SYMBOL="->" ;;
esac
PRIV_LEVEL_0="$PRIV_LEVEL"
# ---------- 主循环 ----------
while true; do
    # 判断是否使用默认颜色(黑底亮白)
    if [ "$BG" = "40" ] && [ "$FG" = "97" ]; then
        case "$PRIV_LEVEL" in
            root) CMD_prompt_fg___=31 ;;   # 红色
            adb)  CMD_prompt_fg___=36 ;;   # 蓝色
            *)    CMD_prompt_fg___=97 ;;   # 普通用户保持亮白
        esac
    else
        CMD_prompt_fg___="$FG"             # 跟随用户自定义
    fi

    printf "\033[%d;%dm%s%s " "$BG" "$CMD_prompt_fg___" "$USERNAME" "$PROMPT_SYMBOL"
    read -r input

    # 空输入处理: 只重置颜色, 不换行
    if [ -z "$input" ]; then
        printf '\033[0m'
        continue
    fi

    # 非空输入: 重置颜色并换行, 然后处理命令
    printf '\033[0m\n'

    # dev_build_0.56 核心更新(正确检测命令内的空字符)
    # 1. 将输入按空格分割为单词数组
    IFS=' ' read -r -a input_array <<< "$input"

    # 2. 提取命令(第一个单词,转为小写)
    cmd="${input_array[0],,}"

    # 3. 提取参数(第二个单词及之后的所有单词)
    args_array=("${input_array[@]:1}")

    # 4. 命令分发(按照命令列表顺序)
case "$cmd" in
    # ---------- 文件和目录操作 ----------
    copy|cp)           cmd_copy "${args_array[@]}" ;;
    del|rm|erase)   cmd_del "${args_array[@]}" ;;
    find)           cmd_find "${args_array[@]}" ;;
    md|mkdir)       cmd_md "${args_array[@]}" ;;
    touch|new)      cmd_touch "${args_array[@]}" ;;
    move|ren|rename) cmd_move "${args_array[@]}" ;;
    rd|rmdir)       cmd_rd "${args_array[@]}" ;;
    dir)            cmd_dir "${args_array[@]}" ;;
    du)             cmd_du "${args_array[@]}" ;;
    size)           cmd_size "${args_array[@]}" ;;
    stat)           cmd_stat "${args_array[@]}" ;;
    ln)             cmd_ln "${args_array[@]}" ;;
    tree)           cmd_tree "${args_array[@]}" ;;
    type)           cmd_type "${args_array[@]}" ;;
    more)           cmd_more "${args_array[@]}" ;;
    zip)            cmd_zip "${args_array[@]}" ;;
    unzip)          cmd_unzip "${args_array[@]}" ;;
    # ---------- 系统信息 ----------
    now|date|time|datetime)  cecho "$($_DATE "+%Y-%m-%d %H:%M:%S (%A)")" ;;
    cal)            cmd_cal "${args_array[@]}" ;;
    clock)          cmd_clock ;;
    free)           cmd_free ;;
    df)             $_DF -h 2>&1 | while IFS= read -r line; do cecho "$line"; done ;;
    getprop)        cmd_getprop "${args_array[@]}" ;;
    env|export)     cmd_env "${args_array[@]}" ;;
    path)           cecho "$PATH" ;;
    uptime)         $_UPTIME 2>&1 | while IFS= read -r line; do cecho "$line"; done ;;
    res)            cmd_res ;;
    batt)           cmd_batt ;;
    systeminfo)     cmd_systeminfo ;;
    tl|tasklist)    cmd_tasklist ;;
    tm|top|taskmgr|taskmanager) cmd_taskmanager ;;
    temp)           cmd_temp ;;
    monitor)        cmd_monitor ;;
    whoami|op)      cmd_whoami_op ;;
    which)          cmd_which "${args_array[@]}" ;;
    pwd)            cecho "$(pwd)" ;;
    self)           cecho "$0" ;;
    # ---------- 网络 ----------
    netstat)        $_NETSTAT 2>&1 | while IFS= read -r line; do cecho "$line"; done ;;
    hostname)       cecho "$($_HOSTNAME 2>/dev/null || echo 'localhost')"; ;;
    ftp)            cmd_ftp "${args_array[@]}" ;;
    ping)           cmd_ping "${args_array[@]}" ;;
    scan)           cmd_scan "${args_array[@]}" ;;
    portscan)       cmd_portscan "${args_array[@]}" ;;
    download)       cmd_download "${args_array[@]}" ;;
    speedtest|st)   cmd_speedtest "${args_array[@]}" ;;
    # ---------- 编解码和校验 ----------
    base64|b64)     cmd_base64 "${args_array[@]}" ;;
    urlencode)      cmd_urlencode "${args_array[@]}" ;;
    urldecode)      cmd_urldecode "${args_array[@]}" ;;
    md5)            cmd_md5 "${args_array[@]}" ;;
    sha1)           cmd_sha1 "${args_array[@]}" ;;
    crc32)          cmd_crc32 "${args_array[@]}" ;;
    psd|passgen)    cmd_psd "${args_array[@]}" ;;
    rand)           cmd_rand "${args_array[@]}" ;;
    # ---------- 控制台/杂项 ----------
    help|/? )       cmd_help ;;
    cls|clear|clean) cmd_cls ;;
    clsnt|clearnt|cleannt) cmd_cls_no_title ;;
    title)          cmd_title "${args_array[@]}" ;;
    color)          cmd_color "${args_array[@]}" ;;
    tmpdir)         cmd_tmpdir "${args_array[@]}" ;;
    resource)       cmd_resource "${args_array[@]}" ;;
    echo|print)     cmd_echo "${args_array[@]}" ;;
    printf)         printf "${args_array[@]}";echo "" ;;
    cecho)          cmd_cecho "${args_array[@]}" ;;
    err)            err "${args_array[*]}" ;;
    yes)            cmd_yes "${args_array[@]}" ;;
    hack)           cmd_hack "${args_array[@]}" ;;
    hack2)          cmd_hack2 "${args_array[@]}" ;;
    sleep)          cmd_sleep "${args_array[@]}" ;;
    timer)          cmd_timer "${args_array[@]}" ;;
    calc)           cmd_calc "${args_array[@]}" ;;
    awkc)           cmd_awkc "${args_array[@]}" ;;
    bc)             cmd_bc "${args_array[@]}" ;;
    disk|diskcheck)           cmd_diskcheck "${args_array[@]}" ;;
    watch)          cmd_watch "${args_array[@]}" ;;
    repeat)         cmd_repeat "${args_array[@]}" ;;
    exit|exit15)    cmd_exit15 ;;
    exit9)          cmd_exit9 ;;
    "ctrl+c"|"<ctrl+c>") cmd_exit15_0 ;;
    sh)             cmd_sh "${args_array[@]}" ;;
    c|cmd)              cmd_cmd "${args_array[@]}" ;;
    adb)            cmd_adb "${args_array[@]}" ;;
    running)        cmd_running "${args_array[@]}" ;;
    kill)           cmd_kill "${args_array[@]}" ;;
    # ---------- debug ----------
    debug|debug_|debug__|debug_help|help_debug|debughelp|helpdebug) err "调试模式还在设计中(真的吗?)" ;;
    debug___|debug_help_|help_debug_)     debug_help ;;
    debug_priv_level|debug_0) debug_0 "${args_array[@]}" ;;
    debug_exit|debug_1) debug_1 "${args_array[@]}" ;;
    debug_load|debug_2)   cmd_resource load -debug ;;
    debug_line|debug_3)    debug_3 ;;
    # ---------- laugh ----------
    $CMD_delimiter|cmd_delimiter|$CMD_delimiter/cmd_delimiter)   err "bro 复制这个何意味?" ;;
    commandnotfound)      cmd_laugh_command_not_found ;;
    command)        cmd_laugh_command_not_found "${args_array[@]}" ;;
    114514|1145141919810) cmd_laugh_114514 ;;
    100|dev100|dev_build_0.100) cmd_laugh_100 ;;
    yesyesyes|yyy|yy|yesyes) cmd_laugh_yyy ;;
    cmd_bomb_fork|cmd_bomb_fork.bash)    cmd_bomb_fork ;; #危险指令!
    wtf)  cmd_laugh_wtf ;;
    wtf2) cmd_laugh_wtf2 ;;

    *)              err "未知命令 \"$cmd\", 请使用 HELP 或 /? 来查看命令列表" ;;
esac
done
#null