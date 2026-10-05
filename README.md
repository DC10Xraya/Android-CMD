# Android CMD

## **简体中文** | [English](README_EN.md)

### 一个为 Android 终端环境设计的 Bash 交互脚本, 旨在模仿CMD.exe, 并且加入更多特色功能

<p align="left">
  <img src="icon.png" alt="Android CMD" width="250">
</p>

> The latest version:
>
> [![Latest Release](https://img.shields.io/github/v/release/DC10Xraya/Android-CMD?label=&color=white)](https://github.com/DC10Xraya/Android-CMD/releases)
>
> [See Releases](https://github.com/DC10Xraya/Android-CMD/releases)

![Language](https://img.shields.io/badge/Language-Bash-blue)
![License](https://img.shields.io/badge/License-MIT-blue)
![Android](https://img.shields.io/badge/Platform-Android-brightgreen?logo=android)

### 重点功能
网络与服务器
- DOWNLOAD: 更简单的下载, 只需要网址和本地路径, 自动选择下载工具
- WINDOWS风格的PING, 并且同时支持众多系统参数
- SCAN、PORTSCAN(伪多线程扫描, 最大128线程)
- (伪)交互式 FTP 客户端: 支持连接、上传、下载、批量操作, 可以作为轻量版的替代客户端

系统与安卓定制
- 内置 TREE 命令, 无需系统自带
- 全维度监控(实时刷新): TASKMGR任务管理器、MONITOR 实时监控、CPUMONITOR 监测CPU频率
- 安卓专属: GETPROP(系统属性)、RES/WM(屏幕分辨率)、LOGCAT(系统日志)、ADB
- WHOAMI输出用户名并自动检测当前的权限[正确检测root、ADB(有线或无线, 包含Shizuku)]

### 特色
- WINDOWS风格, 提供WINDOWS别名, 全大写(当然, 输入的命令自动转换为小写匹配)
- 下载解压一键式使用, 上手简单
- 模块化设计, Lazy加载, 启动更快
- 非关键命令函数放在 resource 目录中, 易于维护, 可以随时添加您自己的命令函数
- 交互增强: 上下箭头调用历史命令, HISTORY 命令管理记录
- 配置保存: 保存你的Color、Title、TMPDIR、Clsd设置, 无需每次配置
- 100+个内置命令, 并且直接支持执行系统命令

### 核心基础模块(主程序内置)

1. **颜色与输出系统** (`_cprint`/`cecho`/`ccat`)  
   CECHO提供带颜色和样式(粗体, 斜体, 下划线, 删除线)的终端输出, 支持16色, 256色和十六进制RGB
   CCAT输出多行文字或者输出文件, 并且解析内容中的 //cecho

2. **命令行解析器** (`parse_line`)  
   自定义参数解析, 支持单引号, 双引号, 转义符和注释 (`#`), 自动展开变量, 将输入拆分为数组 `PARSED_ARGS`, 供主循环分发命令

3. **配置管理** (`load_config`/`save_config`)  
   从 `etc/cmd_config` 读写默认背景色, 前景色, 标题显示方式, 临时目录等用户配置, 并支持持久化保存

4. **历史记录管理**  (`HISTORY`)  
   自动加载和保存命令历史, 支持历史文件大小检查, 去重以及 `HISTORY` 命令的各种操作

5. **信号处理与退出机制**
   处理退出信号, 空闲时退出整个脚本; 执行命令时由命令函数自己负责, 退出该命令

6. **懒惰加载器** (`lazy_load`)  
   按需从 `resource/` 目录下动态加载 `cmd_*.bash` 外部命令, 避免启动时加载所有扩展, 提高启动速度

7. **版本更新检查**(后台检查 + `cmd_update`)  
    启动时后台从 GitHub API 获取最新版本, 缓存结果并在主循环中提示更新; `UPDATE` 命令可手动查看详情

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

### 杂七杂八

这个脚本虽然开发了很久, 但是难免会有不足, 遇到任何问题都可以提出, 不喜欢也别喷qwq

### 许可证

MIT License

Copyright (c) 2026 DC10Xray