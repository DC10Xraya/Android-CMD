#resource/cmd_mcserver.bash
cmd_laugh_mcserver() {
    # ---------- 颜色定义 ----------
    local GREEN='\033[0;32m'
    local YELLOW='\033[1;33m'
    local RED='\033[0;31m'
    local CYAN='\033[0;36m'
    local WHITE='\033[0;37m'
    local PURPLE='\033[0;35m'
    local NC='\033[0m'

    # ---------- 全局状态 ----------
    ONLINE_PLAYERS=""
    BANNED_PLAYERS=""
    BANNED_IPS=""
    OPS=""
    WHITELIST_ENABLED="false"
    WHITELIST=""
    LOG_ENABLED=true
    _abort=0  # 中断标志

    # ---------- 真实系统信息 ----------
    get_mem_available() {
        if [ -r /proc/meminfo ]; then
            local mem=$(grep -E '^MemAvailable:' /proc/meminfo 2>/dev/null | awk '{print $2}')
            [ -n "$mem" ] && echo $((mem / 1024)) && return
        fi
        echo "N/A"
    }

    get_mem_total() {
        if [ -r /proc/meminfo ]; then
            local total=$(grep -E '^MemTotal:' /proc/meminfo | awk '{print $2}')
            echo $((total / 1024))
        else
            echo "N/A"
        fi
    }

    get_loadavg() {
        if [ -r /proc/loadavg ]; then
            awk '{print $1}' /proc/loadavg
        else
            echo "N/A"
        fi
    }

    get_disk_free() {
        local target="/storage/emulated/0"
        [ -d "$target" ] || target="/data"
        df -m "$target" 2>/dev/null | awk 'NR==2 {print $4}'
    }

    get_cpu_info() {
        if [ -r /proc/cpuinfo ]; then
            local model=$(grep -m1 'Hardware' /proc/cpuinfo 2>/dev/null | cut -d':' -f2- | sed 's/^[[:space:]]*//')
            [ -n "$model" ] && echo "$model" && return
            model=$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d':' -f2- | sed 's/^[[:space:]]*//')
            [ -n "$model" ] && echo "$model" && return
        fi
        echo "N/A"
    }

    get_cpu_cores() {
        nproc 2>/dev/null || grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo "N/A"
    }

    get_battery_level() {
        if [ -r /sys/class/power_supply/battery/capacity ]; then
            cat /sys/class/power_supply/battery/capacity 2>/dev/null
        elif [ -r /sys/class/power_supply/battery/charge_now ] && [ -r /sys/class/power_supply/battery/charge_full ]; then
            echo $(( $(cat /sys/class/power_supply/battery/charge_now) * 100 / $(cat /sys/class/power_supply/battery/charge_full) ))
        else
            echo "N/A"
        fi
    }

    get_battery_status() {
        if [ -r /sys/class/power_supply/battery/status ]; then
            cat /sys/class/power_supply/battery/status 2>/dev/null
        else
            echo "N/A"
        fi
    }

    # ---------- 堆计算 ----------
    calculate_heap() {
        local total_mem=$(get_mem_total)
        if [ "$total_mem" = "N/A" ] || [ -z "$total_mem" ]; then
            echo "2048"
            return
        fi
        local ratio=$(awk -v r=$RANDOM 'BEGIN{printf "%.2f", 0.55 + r/32767*0.10}')
        local heap_mb=$(echo "$total_mem * $ratio" | bc | cut -d'.' -f1)
        [ "$heap_mb" -gt 8192 ] && heap_mb=8192
        [ "$heap_mb" -lt 512 ] && heap_mb=512
        echo "$heap_mb"
    }

    # ---------- 日志函数 ----------
    log_info()  {
        $LOG_ENABLED && echo -e "${GREEN}[$(date '+%H:%M:%S')] [Server thread/INFO]: $1${NC}"
    }
    log_warn()  {
        $LOG_ENABLED && echo -e "${YELLOW}[$(date '+%H:%M:%S')] [Server thread/WARN]: $1${NC}"
    }
    log_error() {
        $LOG_ENABLED && echo -e "${RED}[$(date '+%H:%M:%S')] [Server thread/ERROR]: $1${NC}"
    }
    log_debug() {
        $LOG_ENABLED && echo -e "${CYAN}[$(date '+%H:%M:%S')] [Server thread/DEBUG]: $1${NC}"
    }
    log_plugin(){
        $LOG_ENABLED && echo -e "${PURPLE}[$(date '+%H:%M:%S')] [Server thread/INFO]: [Essentials] $1${NC}"
    }

    # ---------- 工具函数 ----------
    rand_sleep()      { sleep $((RANDOM % 3 + 2)); }
    rand_sleep_short(){ sleep $(awk -v r=$RANDOM 'BEGIN{printf "%.1f", r/32767*1.5+0.5}'); }

    random_from_list() {
        oldifs="$IFS"; IFS=','; set -- $1; IFS="$oldifs"
        eval echo \${$((RANDOM % $# + 1))}
    }

    generate_uuid() {
        local a b c d e f g h
        a=$(printf '%04x' $((RANDOM%65536)) 2>/dev/null || echo "0000")
        b=$(printf '%04x' $((RANDOM%65536)) 2>/dev/null || echo "0000")
        c=$(printf '%04x' $((RANDOM%65536)) 2>/dev/null || echo "0000")
        d=$(printf '%04x' $((RANDOM%65536)) 2>/dev/null || echo "0000")
        e=$(printf '%04x' $((RANDOM%65536)) 2>/dev/null || echo "0000")
        f=$(printf '%04x' $((RANDOM%65536)) 2>/dev/null || echo "0000")
        g=$(printf '%04x' $((RANDOM%65536)) 2>/dev/null || echo "0000")
        h=$(printf '%04x' $((RANDOM%65536)) 2>/dev/null || echo "0000")
        echo "$a$b-$c$d-$e$f-$g$h"
    }

    is_online() {
        case ",$ONLINE_PLAYERS," in *",$1,"*) return 0 ;; *) return 1 ;; esac
    }

    add_player() {
        if ! is_online "$1"; then
            [ -n "$ONLINE_PLAYERS" ] && ONLINE_PLAYERS="$ONLINE_PLAYERS,$1" || ONLINE_PLAYERS="$1"
        fi
    }
    remove_player() {
        local new="" old="$ONLINE_PLAYERS" first rest
        while [ -n "$old" ]; do
            case "$old" in
                *","*) first="${old%%,*}"; rest="${old#*,}" ;;
                *)     first="$old"; rest="" ;;
            esac
            if [ "$first" != "$1" ]; then
                [ -n "$new" ] && new="$new,$first" || new="$first"
            fi
            old="$rest"
        done
        ONLINE_PLAYERS="$new"
    }

    online_count() {
        [ -z "$ONLINE_PLAYERS" ] && echo 0 || echo "$ONLINE_PLAYERS" | tr ',' ' ' | wc -w
    }

    # ---------- 关闭服务器函数 ----------
    shutdown_server() {
        log_info "Stopping the server..."
        if [ -n "$ONLINE_PLAYERS" ]; then
            for p in $(echo "$ONLINE_PLAYERS" | tr ',' ' '); do
                log_info "$p lost connection: Server closed"
            done
            ONLINE_PLAYERS=""
        fi
        log_info "Saving players"
        sleep 1
        log_info "Saving worlds"
        sleep 1
        log_info "Saved the game"
        log_info "Server stopped"
        echo -e "${YELLOW}Server simulation ended.${NC}"
    }

    # ---------- 设置中断处理 ----------
    trap '_abort=1' INT

    # ---------- 启动模拟（在启动过程中检查 _abort） ----------
    START_TIME=$SECONDS

    HEAP_MB=$(calculate_heap)
    HEAP_GB=$(echo "scale=2; $HEAP_MB/1024" | bc)
    INIT_HEAP_MB=$(echo "$HEAP_MB * 0.75" | bc | cut -d'.' -f1)
    [ -z "$INIT_HEAP_MB" ] && INIT_HEAP_MB=$((HEAP_MB * 3 / 4))

    echo -e "${GREEN}Starting Minecraft Paper server on *:25565${NC}"
    [ $_abort -eq 1 ] && { shutdown_server; return 0; }
    rand_sleep_short
    [ $_abort -eq 1 ] && { shutdown_server; return 0; }
    log_info "Loading libraries, please wait..."
    [ $_abort -eq 1 ] && { shutdown_server; return 0; }
    rand_sleep
    [ $_abort -eq 1 ] && { shutdown_server; return 0; }
    log_info "Environment: OS: $(uname -o) ($(uname -m))"
    [ $_abort -eq 1 ] && { shutdown_server; return 0; }
    log_info "Java: Java 21-internal (OpenJDK 64-Bit Server VM)"
    [ $_abort -eq 1 ] && { shutdown_server; return 0; }
    log_info "JVM flags: -XX:+UseG1GC -XX:MaxGCPauseMillis=250 -XX:+ParallelRefProcEnabled -XX:+PerfDisableSharedMem"
    [ $_abort -eq 1 ] && { shutdown_server; return 0; }
    log_info "Heap: -Xmx${HEAP_MB}M (${HEAP_GB}G) -Xms${INIT_HEAP_MB}M"
    [ $_abort -eq 1 ] && { shutdown_server; return 0; }
    log_info "Additional: -XX:+DisableExplicitGC -XX:+UseStringDeduplication -XX:+OptimizeStringConcat"
    [ $_abort -eq 1 ] && { shutdown_server; return 0; }
    log_info "CPU: $(get_cpu_info) (cores: $(get_cpu_cores))"
    [ $_abort -eq 1 ] && { shutdown_server; return 0; }
    rand_sleep
    [ $_abort -eq 1 ] && { shutdown_server; return 0; }

    log_info "Loading mods/plugins..."
    [ $_abort -eq 1 ] && { shutdown_server; return 0; }
    for plugin in "EssentialsX v2.20.1" "WorldEdit v7.2.15" "LuckPerms v5.4.102" "CoreProtect v22.2" "ViaVersion v4.8.1"; do
        log_info "  - $plugin"
        [ $_abort -eq 1 ] && { shutdown_server; return 0; }
        rand_sleep_short
        [ $_abort -eq 1 ] && { shutdown_server; return 0; }
    done

    log_info "Preparing level \"world\""
    [ $_abort -eq 1 ] && { shutdown_server; return 0; }
    rand_sleep
    [ $_abort -eq 1 ] && { shutdown_server; return 0; }
    log_info "Preparing start region for dimension minecraft:overworld"
    [ $_abort -eq 1 ] && { shutdown_server; return 0; }
    rand_sleep
    [ $_abort -eq 1 ] && { shutdown_server; return 0; }

    for pct in 0 11 23 37 45 58 67 76 84 93 100; do
        log_info "Preparing spawn area: ${pct}%"
        [ $_abort -eq 1 ] && { shutdown_server; return 0; }
        rand_sleep_short
        [ $_abort -eq 1 ] && { shutdown_server; return 0; }
    done

    rand_sleep
    [ $_abort -eq 1 ] && { shutdown_server; return 0; }
    log_info "Time elapsed: $((SECONDS - START_TIME)) ms"
    [ $_abort -eq 1 ] && { shutdown_server; return 0; }
    rand_sleep
    [ $_abort -eq 1 ] && { shutdown_server; return 0; }

    mem_total=$(get_mem_total)
    mem_avail=$(get_mem_available)
    if [ "$mem_total" != "N/A" ] && [ "$mem_total" -lt 2048 ]; then
        log_warn "Low memory detected (${mem_total}MB total, ${mem_avail}MB free) - adjusting GC settings"
    else
        log_info "Memory: ${mem_avail}MB free / ${mem_total}MB total"
    fi
    [ $_abort -eq 1 ] && { shutdown_server; return 0; }
    rand_sleep
    [ $_abort -eq 1 ] && { shutdown_server; return 0; }

    log_info "Loaded 441 spawn chunks for world 'world'"
    [ $_abort -eq 1 ] && { shutdown_server; return 0; }
    rand_sleep
    [ $_abort -eq 1 ] && { shutdown_server; return 0; }

    ELAPSED=$((SECONDS - START_TIME))
    log_info "Done (${ELAPSED}.${RANDOM:0:2}s)! Server is running. (Press Ctrl+C to stop)"
    echo -e "${YELLOW}Simulation is active...${NC}"

    # ---------- 资源池 ----------
    PLAYER_POOL="Steve_Phone,Alex_Tab,LagMaster,ThermalLimit,HotBattery,Crashy,LowMemUser,DiamondHunter,RedstoneGuru,Herobrine"
    CHAT_MSGS="hey,found diamonds,lag spike,tps?,my game froze,where is everyone,gg,creeper!,ouch,need food,who built this,help me,awesome base"
    ACHIEVEMENTS="Stone Age,Getting an Upgrade,Acquire Hardware,Suit Up,Hot Stuff,Ice Bucket Challenge,Diamonds!,We Need to Go Deeper,The End?,The End.,Return to Sender"
    DEATH_MSGS="was slain by Zombie,fell from a high place,drowned,blew up,hit the ground too hard,was killed by magic,went up in flames,was squashed by a falling anvil,was pricked to death,experienced kinetic energy,was shot by Skeleton,was slain by Enderman"

    # ---------- 主循环 ----------
    ticks=0
    while true; do
        if [ $_abort -eq 1 ]; then
            shutdown_server
            return 0
        fi
        cnt=$(online_count)
        roll=$((RANDOM % 20))
        ticks=$((ticks + 1))

        if [ $((ticks % 40)) -eq 0 ]; then
            disk_free=$(get_disk_free)
            log_info "Autosave started... (Disk free: ${disk_free}MB)"
            rand_sleep_short
            log_info "Autosave complete."
        fi

        if [ $roll -lt 2 ] && [ $cnt -lt 10 ]; then
            new_player=$(random_from_list "$PLAYER_POOL")
            is_online "$new_player" && continue
            add_player "$new_player"
            uuid=$(generate_uuid)
            log_info "UUID of player $new_player is $uuid"; rand_sleep_short
            log_info "$new_player joined the game"
            log_plugin "$new_player logged in (mode: survival, world: world)"
        elif [ $roll -eq 2 ] && [ $cnt -gt 0 ]; then
            leaving=$(random_from_list "$ONLINE_PLAYERS")
            remove_player "$leaving"
            case $((RANDOM % 3)) in
                0) log_warn "$leaving lost connection: Timed out" ;;
                1) log_info "$leaving left the game" ;;
                2) log_warn "$leaving lost connection: Disconnected" ;;
            esac
        elif [ $roll -eq 10 ] && [ $cnt -gt 0 ]; then
            actor=$(random_from_list "$ONLINE_PLAYERS")
            subroll=$((RANDOM % 6))
            case $subroll in
                0) log_info "$actor has made the advancement [$(random_from_list "$ACHIEVEMENTS")]" ;;
                1) log_info "$actor $(random_from_list "$DEATH_MSGS")" ;;
                2) log_info "$actor issued server command: /help"; rand_sleep_short; log_warn "Unknown or incomplete command, see below for error"; log_warn "<--[HERE]" ;;
                3) log_debug "<$actor> $(random_from_list "$CHAT_MSGS")" ;;
                4) target=$(random_from_list "$ONLINE_PLAYERS")
                   [ "$target" != "$actor" ] && { log_info "$actor issued server command: /tpa $target"; log_info "$actor has requested to teleport to $target."; } ;;
                5) log_info "There are $((RANDOM % 200 + 50)) entities in world 'world'" ;;
            esac
        elif [ $roll -eq 15 ]; then
            load=$(get_loadavg)
            free_mem=$(get_mem_available)
            batt=$(get_battery_level)
            case $((RANDOM % 4)) in
                0) ms=$((RANDOM % 4000 + 500))
                   ticks_behind=$((RANDOM % 80 + 20))
                   log_warn "Can't keep up! Is the server overloaded? Running ${ms}ms or ${ticks_behind} ticks behind (Load: ${load}, Free mem: ${free_mem}MB, Battery: ${batt}%)" ;;
                1) log_error "java.lang.OutOfMemoryError: Java heap space (System free: ${free_mem}MB)"
                   log_warn "Forced garbage collection reclaimed 4MB" ;;
                2) log_warn "Chunk save took $((RANDOM%3000+800))ms, possible disk I/O lag (Disk free: $(get_disk_free)MB)" ;;
                3) log_warn "Player movement lag detected for $((RANDOM % 3 + 1)) clients (Load: ${load})" ;;
            esac
        fi
        sleep 0.5
    done
}