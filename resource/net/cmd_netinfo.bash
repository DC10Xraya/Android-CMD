# ---------- LOCALNET ----------
cmd_netinfo() {
    # ---------- 1. 本地回环地址 ----------
    local loop_ip=""
    if [ -r /etc/hosts ]; then
        loop_ip=$($_GREP -E '^[[:space:]]*127\.' /etc/hosts 2>/dev/null \
            | $_AWK '{print $1}' \
            | $_HEAD -n1)
    fi
    [ -z "$loop_ip" ] && loop_ip="127.0.0.1"

    if [ "$loop_ip" = "127.0.0.1" ]; then
        cecho "本地地址: $loop_ip (localhost)"
    else
        cecho "本地地址: $loop_ip"
    fi

    # ---------- 2. 局域网地址 ----------
    local lan_ips=""
    if command -v getprop >/dev/null 2>&1; then
        lan_ips=$(getprop dhcp.wlan0.ipaddress 2>/dev/null; \
                  getprop dhcp.eth0.ipaddress  2>/dev/null) \
            | $_GREP -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' \
            | $_GREP -vE '^127\.'
    fi

    if [ -n "$lan_ips" ]; then
        local _one
        printf '%s\n' "$lan_ips" \
            | $_AWK '!seen[$0]++' \
            | while IFS= read -r _one; do
                [ -n "$_one" ] && cecho "局域网地址: $_one"
              done
    else
        err "局域网地址: N/A (无法读取网络接口)"
    fi

    # ---------- 3. 互联网(公网)地址: IPv4 / IPv6 ----------
    local wan4_ip="" wan6_ip=""

    _is_ipv4() {
        printf '%s' "$1" | $_GREP -qE '^([0-9]{1,3}\.){3}[0-9]{1,3}$'
    }

    _is_ipv6() {
        case "$1" in *:*:*) ;; *) return 1 ;; esac
        printf '%s' "$1" | $_GREP -qiE '^[0-9a-f:]{3,45}$'
    }

    _probe_wan() {
        local fam="$1" url out
        local -a urls

        if [ "$fam" = "4" ]; then
            urls=(
                "https://ipv4.icanhazip.com"
                "https://checkip.amazonaws.com"
                "https://ipv4.ident.me"
            )
        else
            urls=(
                "https://ipv6.icanhazip.com"
                "https://api6.ipify.org"
                "https://6.ipw.cn"
            )
        fi

        for url in "${urls[@]}"; do
            out=""
            if [ "$HAS_CURL" -eq 1 ]; then
                out=$($_CURL -s -"$fam" --connect-timeout 2 --max-time 3 "$url" 2>/dev/null)
            elif [ "$HAS_WGET" -eq 1 ]; then
                if [ "$fam" = "4" ]; then
                    out=$($_WGET -qO- --inet4-only --timeout=3 "$url" 2>/dev/null)
                else
                    out=$($_WGET -qO- --inet6-only --timeout=3 "$url" 2>/dev/null)
                fi
            fi
            out=$(printf '%s' "$out" | tr -d '[:space:]')
            [ -z "$out" ] && continue

            if [ "$fam" = "4" ]; then
                _is_ipv4 "$out" && { printf '%s' "$out"; return 0; }
            else
                _is_ipv6 "$out" && { printf '%s' "$out"; return 0; }
            fi
        done
        return 1
    }

    wan4_ip=$(_probe_wan 4)
    if [ -n "$wan4_ip" ]; then
        cecho "公网 IPv4: $wan4_ip"
    else
        err "公网 IPv4: N/A  (网络不可用或超时)"
    fi

    wan6_ip=$(_probe_wan 6)
    if [ -n "$wan6_ip" ]; then
        cecho "公网 IPv6: $wan6_ip"
    else
        err "公网 IPv6: N/A  (无IPv6网络或超时)"
    fi

    # ---------- 4. 附加公网信息 (ifconfig.me / ipinfo.io) ----------
local _extra=""

# JSON 取字符串字段: $1=json  $2=key
_json_get() {
    local json="$1" key="$2"
    if command -v jq >/dev/null 2>&1; then
        printf '%s' "$json" | jq -r --arg k "$key" '.[$k] // empty' 2>/dev/null
    else
        printf '%s' "$json" | $_AWK -v key="$key" '
        {
            s = $0
            re = "\"" key "\"[[:space:]]*:[[:space:]]*\"[^\"]*\""
            if (match(s, re)) {
                v = substr(s, RSTART, RLENGTH)
                sub("^\"" key "\"[[:space:]]*:[[:space:]]*\"", "", v)
                sub("\"$", "", v)
                print v
                exit
            }
        }'
    fi
}

if [ "$HAS_CURL" -eq 1 ] || [ "$HAS_WGET" -eq 1 ]; then
    # ifconfig.me: 纯文本 IP
    if [ "$HAS_CURL" -eq 1 ]; then
        _extra=$($_CURL -s --connect-timeout 2 --max-time 3 \
            "https://ifconfig.me" 2>/dev/null)
    else
        _extra=$($_WGET -qO- --timeout=3 \
            "https://ifconfig.me" 2>/dev/null)
    fi
    _extra=$(printf '%s' "$_extra" | tr -d '[:space:]')
    if [ -n "$_extra" ]; then
        cecho "ifconfig.me: $_extra"
    else
        err "ifconfig.me: N/A  (网络不可用或超时)"
    fi

    # ipinfo.io: 拉 JSON 后逐字段解析
    _extra=""
    if [ "$HAS_CURL" -eq 1 ]; then
        _extra=$($_CURL -s --connect-timeout 2 --max-time 3 \
            "https://ipinfo.io" 2>/dev/null)
    else
        _extra=$($_WGET -qO- --timeout=3 \
            "https://ipinfo.io" 2>/dev/null)
    fi

    if [ -n "$_extra" ]; then
        local _ip _city _region _country _loc _org _tz
        _ip=$(_json_get "$_extra" ip)
        _city=$(_json_get "$_extra" city)
        _region=$(_json_get "$_extra" region)
        _country=$(_json_get "$_extra" country)
        _loc=$(_json_get "$_extra" loc)
        _org=$(_json_get "$_extra" org)
        _tz=$(_json_get "$_extra" timezone)

        cecho "ipinfo.io:"
        [ -n "$_ip" ]      && cecho "  IP:       $_ip"
        [ -n "$_city" ]    && cecho "  City:     $_city"
        [ -n "$_region" ]  && cecho "  Region:   $_region"
        [ -n "$_country" ] && cecho "  Country:  $_country"
        [ -n "$_loc" ]     && cecho "  Loc:      $_loc"
        [ -n "$_org" ]     && cecho "  Org:      $_org"
        [ -n "$_tz" ]      && cecho "  Timezone: $_tz"

        if [ -z "$_ip$_city$_region$_country$_loc$_org$_tz" ]; then
            err "  (JSON 解析失败, 原始输出:)"
            printf '%s\n' "$_extra"
        fi
    else
        err "ipinfo.io: N/A  (网络不可用或超时)"
    fi
else
    err "附加公网信息: N/A  (缺少 curl/wget)"
fi
}