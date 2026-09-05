# Android CMD

## **简体中文** | [English](README_EN.md)

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

一个集成了常用运维, 网络与系统监控功能(还有笑话)的交互式 Bash 脚本,  专门在 Android 上运行

### 重点功能
网络与服务器
- DOWNLOAD: 更简单的下载, 只需要网址和本地路径
- WINDOWS风格的PING
- SCAN、PORTSCAN(伪多线程扫描)
- 交互式 FTP 客户端: 支持连接、上传、下载、批量操作(mget/mput), 完美适配手机端操作

系统与安卓定制
- 内置手写 TREE 命令, 无需系统自带的 tree 工具
- 全维度监控: TASKMGR(任务管理器)、MEMORY 实时监控
- 安卓专属: GETPROP(系统属性)、RES/WM(屏幕分辨率)、LOGCAT(系统日志)、ADB

关于Minecraft
- 模组下载器: MCMODDOWNLOAD 通过 Modrinth API, 批量下载 Java 版模组
- 服务器模拟器(隐藏): MCSERVER 模拟在手机上运行JAVA版Paper服务端

### 特色
- 下载解压一键式使用, 上手简单
- 模块化设计, Lazy加载(0.05+), 启动更快 ; 新的函数可以放在 resource 目录中, 易于维护 ; 配置与历史记录保存在 etc 目录下(0.06+)
- 交互增强: 上下箭头调用历史命令, HISTORY 命令管理记录(0.06+)
- 配置保存: 保存你的Color、Title、TMPDIR、Clsd设置
- 识别你的权限, 给你不同的命令提示符
- 命令众多, 功能强大
- Laugh隐藏命令(NO tell you)
- 关于我的世界的功能和设计

### 核心基础模块(主程序内置)

1. **颜色与输出系统** (`_cprint`/`cecho`/`ccat`)  
   提供带颜色和样式(粗体, 斜体, 下划线, 删除线)的终端输出, 支持16色, 256色和十六进制RGB, 并能解析文件中的 //cecho 指令实现彩色文本显示.

2. **命令行解析器** (`parse_line`)  
   自定义参数解析, 支持单引号, 双引号, 转义符和注释 (`#`), 将输入拆分为数组 `PARSED_ARGS`, 供主循环分发命令.

3. **配置管理** (`load_config`/`save_config`)  
   从 `etc/cmd_config` 读写默认背景色, 前景色, 标题显示方式, 临时目录等用户配置, 并支持持久化保存.

4. **历史记录管理** (`HISTFILE`/history 相关)  
   自动加载和保存命令历史, 支持历史文件大小检查, 去重以及 `HISTORY` 命令的各种操作.

5. **信号处理与退出机制** (`exit9`/`exit15`/信号陷阱)  
   处理 Ctrl+C, TERM 等信号, 递归杀死子进程树, 清理临时文件, 实现安全退出(强制或温和两种方式).

6. **通用辅助函数** (`confirm`/`kill_tree`/`file_op`/`err`)  
   提供交互式确认, 进程树杀死, 文件复制/移动(带覆盖确认)以及红色错误输出等常用工具.

7. **权限检测模块** (`PRIV_LEVEL`/`PROMPT_SYMBOL`)  
   启动时通过 `id`, `ps`, `getprop` 检测当前用户是 root, adb 还是普通用户, 并相应设置提示符(`#`/`$`/`->`).

8. **路径与目录管理** (`SCRIPT_DIR`/`RESOURCE_DIR`/`ETC_DIR`/`TMP_DIR`)  
   定义脚本根目录, 资源目录, 配置目录和临时目录, 并确保它们存在且可写.

9. **懒惰加载器** (`lazy_load`)  
   按需从 `resource/` 目录下动态加载 `cmd_*.bash` 外部命令, 避免启动时加载所有扩展, 提高启动速度.

10. **初始化模块** (`init_tools`/`load_splashes`/`get_title`)  
    检测 `busybox` 并设定工具前缀, 加载随机标语, 显示启动标题和版本信息.

11. **版本更新检查**(后台检查 + `cmd_update`)  
    启动时后台从 GitHub API 获取最新版本, 缓存结果并在主循环中提示更新; `UPDATE` 命令可手动查看详情.

### 启动方式
1. 解压下载得到的 .tar.gz 压缩包
2. 打开终端, 执行以下命令:
```bash
cd #主程序(cmd_main_dev)所在目录
bash CMD_main_dev.bash
```

启动后输入 HELP 或 /? 即可查看所有命令列表

### 运行依赖

基础环境为 Bash 4.0+, 必须预装:

```txt
Awk, Grep, Sed, Cat, Cut, Head, Tail, BC, wget<or>curl
```

缺失以上依赖无法启动脚本, 其他的依赖缺失可能导致部分命令无法使用

### 杂七杂八

这个脚本虽然开发了很久, 但是难免会有不足, 遇到任何问题都可以提出, 不喜欢也别喷qwq

### 许可证

MIT License

Copyright (c) 2026 DC10Xray
