# Android CMD

## [简体中文](README.md) | **English**

### A Bash interactive script designed for Android terminal environments, aiming to imitate CMD.exe while adding more unique features

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

### Key Features

Network & Servers
- DOWNLOAD: Simpler downloads—just provide a URL and local path; the download tool is selected automatically
- Windows-style PING, with support for many system parameters
- SCAN, PORTSCAN (pseudo-multithreaded scanning, up to 128 threads)
- (Pseudo-)interactive FTP client: supports connection, upload, download, and batch operations; can serve as a lightweight alternative client

System & Android Customization
- Built-in TREE command; no system-provided TREE required
- Full-dimensional monitoring (real-time refresh): TASKMGR task manager, MONITOR real-time monitoring, CPUMONITOR CPU frequency monitoring
- Android-specific: GETPROP (system properties), RES/WM (screen resolution), LOGCAT (system logs), ADB
- WHOAMI outputs the username and automatically detects the current privilege level [correctly detects root and ADB (wired or wireless, including Shizuku)]

### Features
- Windows-style, with Windows aliases; all uppercase (commands you type are automatically converted to lowercase for matching)
- One-click download and extraction for immediate use; easy to get started
- Modular design, lazy loading, faster startup
- Non-critical command functions are placed in the `resource` directory, making maintenance easier; you can add your own command functions at any time
- Enhanced interaction: use the up/down arrow keys to recall history commands; the HISTORY command manages records
- Configuration saving: saves your Color, Title, TMPDIR, and Clsd settings, so you do not need to configure them every time
- 100+ built-in commands, and direct support for executing system commands

### Core Base Modules (built into the main program)

1. **Color and output system** (`_cprint`/`cecho`/`ccat`)  
   CECHO provides terminal output with colors and styles (bold, italic, underline, strikethrough), supporting 16 colors, 256 colors, and hexadecimal RGB.  
   CCAT outputs multiline text or outputs a file, and parses `//cecho` in the content.

2. **Command-line parser** (`parse_line`)  
   Custom argument parsing, supporting single quotes, double quotes, escape characters, and comments (`#`); automatically expands variables and splits input into the array `PARSED_ARGS` for the main loop to dispatch commands.

3. **Configuration management** (`load_config`/`save_config`)  
   Reads and writes user configurations such as default background color, foreground color, title display mode, and temporary directory from `etc/cmd_config`, and supports persistent saving.

4. **History management** (`HISTORY`)  
   Automatically loads and saves command history; supports history file size checks, deduplication, and various operations via the `HISTORY` command.

5. **Signal handling and exit mechanism**  
   Handles exit signals and exits the entire script when idle; when executing a command, the command function itself is responsible for exiting that command.

6. **Lazy loader** (`lazy_load`)  
   Dynamically loads external commands `cmd_*.bash` from the `resource/` directory on demand, avoiding loading all extensions at startup and improving startup speed.

7. **Version update check** (background check + `cmd_update`)  
   At startup, fetches the latest version from the GitHub API in the background, caches the result, and prompts for updates in the main loop; the `UPDATE` command can manually view details.

### How to Use?
1. Download the tar.gz archive from the latest release.
2. Open a terminal and run the following commands:
```bash
# 1. Create target dir
mkdir -p "target_dir"
# 2. Extract archive into it
tar -xzf "archive_path" -C "target_dir"
# 3. Run script (choose one)
# (Then just run:)
# A
bash "target_dir/CMD_main_dev.bash"
# B
cd "target_dir"
bash CMD_main_dev.bash
```

After startup, enter HELP or /? to view the list of built-in commands

if you want to run system commands, you can use C(eval) or the BASH command to run system commands

if you want to continue running other scripts internally, you can use SH

### Runtime Dependencies

The basic environment is Bash 4.0+. The following must be preinstalled:

```txt
Awk, Grep, Sed, Cat, Cut, Head, Tail, BC, wget <or> curl
```

Missing the above dependencies will prevent the script from starting. Missing other dependencies may cause some commands to be unavailable.

* If only one of curl and wget is present, a reminder will be displayed on every startup, and some network features will be unavailable; if neither is present, it cannot start.

### Miscellaneous

Although this script has been developed for a long time, shortcomings are inevitable. If you encounter any problems, feel free to report them. If you do not like it, please do not flame me 🍬🚚

### License

MIT License

Copyright (c) 2026 DC10Xray