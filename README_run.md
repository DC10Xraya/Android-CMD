# Android CMD
### 一个为 Android 终端环境设计的 Bash 交互脚本, 旨在模仿CMD.exe, 并且加入更多特色功能

---

### 怎样使用?
1. 在最新发行版中下载 tar.gz 压缩包
2. 打开终端, 执行以下命令:
```bash
# 1. 创建你想要的目录
mkdir -p "你想解压到的目录"
# 2. 解压压缩包到该目录
tar -xzf "你下载的压缩包路径" -C "你想解压到的目录"
# 3. 运行脚本 (二选一)
# 方式A (不改变工作目录)
bash "你解压到的目录/CMD_main_dev.bash"
# 方式B (改变工作目录)
cd "你解压到的目录"
bash CMD_main_dev.bash
```

启动后输入 HELP 或 /? 即可查看内置命令列表

如果想运行系统命令, 可以使用C(eval)或BASH命令来运行系统命令

如果想在内部继续运行其他脚本, 可以使用SH

### 运行依赖

基础环境为 Bash 4.0+, 必须预装:

```txt
Awk, Grep, Sed, Cat, Cut, Head, Tail, BC, wget 或 curl
```

缺失以上依赖无法启动脚本, 其他的依赖缺失可能导致部分命令无法使用

* 如果curl、wget只存在一个, 每次启动时都会提醒, 并且一些网络功能不可用; 如果都不存在, 则无法启动

---

MIT License

Copyright (c) 2026 DC10Xray

更多信息: https://github.com/DC10Xraya/Android-CMD

* 此文件仅在运行前提供帮助, 不是真正的README, 一些内容在新版本中可能过时