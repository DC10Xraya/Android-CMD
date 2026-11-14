#/resource/cmd_laugh_yyy.bash
cmd_laugh_yyy() {
   if ! confirm "YES YES YES?(Ctrl+C终止)"; then
       return
   fi

   # 保存旧的 INT 陷阱
   local old_trap=$(trap -p INT)
   local interrupted=0
   local yes_pid=""

   # 设置新的 INT 陷阱
   trap 'interrupted=1; [ -n "$yes_pid" ] && kill $yes_pid 2>/dev/null' INT

   # 后台运行 yes, 并获取 PID
   yes "YES YES YES YES YES YES YES YES YES YES YES YES YES YES YES YES YES YES YES YES YES YES YES YES YES YES YES YES YES YES YES YES YES YES YES YES" &
   yes_pid=$!

   # 等待 yes 结束(可能被信号中断)
   wait $yes_pid 2>/dev/null

   # 恢复旧的 INT 陷阱(若原来没有则恢复默认)
   if [ -n "$old_trap" ]; then
       eval "$old_trap"
   else
       trap - INT
   fi

   # 检查是否被中断
   if [ $interrupted -eq 1 ]; then
       echo ""
       cecho -c 36 "[yes is stop]" >&2
       return 130
   fi
}