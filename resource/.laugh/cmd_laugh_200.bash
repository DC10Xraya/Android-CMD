cmd_laugh_200() {
  local old_trap=$(trap -p INT)
  cecho -b "[在这里只需要按Ctrl+C就会退出该命令(~v~)]"
  cecho "$CMD_delimiter"
  printf "\n"
  trap 'break' INT
  printf '\033[?25l'
  DEV_ART=(
" ####  ######  ######"
"    #  #    #  #    #"
"####   #    #  #    #"
"#      #    #  #    #"
"####   ######  ######"
)
  declare -a positions=()
  max_row=${#DEV_ART[@]}
  for ((r=0; r<max_row; r++)); do
    line="${DEV_ART[r]}"
    len=${#line}
    for ((c=0; c<len; c++)); do
      [[ "${line:c:1}" != " " ]] && positions+=("$r,$c")
    done
  done
  total=${#positions[@]}
  reset='\033[0m'
  fill_color='\033[1;36m'
  unfill_color='\033[2;37m'
  printf '\033[s'
  progress=0
  while (( progress <= 100 )); do
    fill_count=$(( progress * total / 100 ))
    lines=()
    for ((r=0; r<max_row; r++)); do
      line="${DEV_ART[r]}"
      len=${#line}
      out_line=""
      for ((c=0; c<len; c++)); do
        char="${line:c:1}"
        if [[ "$char" == " " ]]; then
          out_line+=" "
        else
          filled=0
          for ((i=0; i<fill_count; i++)); do
            pos="${positions[i]}"
            pr="${pos%,*}"; pc="${pos#*,}"
            if [[ $pr -eq $r && $pc -eq $c ]]; then
              filled=1; break
            fi
          done
          if (( filled )); then
            out_line+="${fill_color}${char}${reset}"
          else
            out_line+="${unfill_color}${char}${reset}"
          fi
        fi
      done
      lines+=("$out_line")
    done
    bar_width=50
    filled_len=$(( progress * bar_width / 100 ))
    bar="["
    for ((i=0; i<bar_width; i++)); do
      (( i < filled_len )) && bar+="█" || bar+="░"
    done
    bar+="]"
    percent_str=$(printf " %3d%%" "$progress")
    lines+=("")
    lines+=("$bar$percent_str")
    printf '\033[u'
    for ((i=0; i<${#lines[@]}; i++)); do
      printf '\033[2K'
      printf '%b' "${lines[i]}"
      (( i < ${#lines[@]} - 1 )) && printf '\n'
    done
    ((progress++))
    sleep 0.1
  done
  printf '\033[?25h'
  echo ""
  cecho -c 92 "🎉 200th dev (~v~) (Build Time: 2026-08-10 [or] 11) 🎉"
  echo ""
  eval "$old_trap"
}