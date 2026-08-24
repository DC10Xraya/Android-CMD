# Android CMD

## **English** | [简体中文](README.md)

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

An interactive Bash script integrating common运维 (operations), network and system monitoring features (plus jokes), specifically designed to run on Android.

<details>
<summary><h2>Commands (91+) Click to expand</h2></summary>

Note: Hidden (laugh) and debug commands are not included.

| Command | Description |
| :--- | :--- |
| COPY/CP | Copy files/directories |
| CD | Change working directory |
| RM/DEL | Delete files or directories |
| RD/RMDIR | Remove empty directories |
| FIND | Search for string/regex in specified files |
| MD/MKDIR | Create directories |
| NEW/TOUCH | Create new file or update file timestamp |
| MOVE | Move files/directories, or rename (within same directory) |
| REN | Rename file (same as MOVE) |
| DIR/LS | List directory contents |
| DU | List directory size |
| SIZE | List file size |
| STAT | Show detailed file information |
| WC | Count lines, words, characters |
| CODEWC | Count lines, words, characters in code (BETA) |
| LN -s | Create symbolic link |
| TREE | Display directory tree |
| TYPE | View text file |
| MORE | Paginate view text file (no color support) |
| ZIP | Create ZIP archive (supports recursive directories) |
| UNZIP | Extract ZIP archive |
| NOW | Show current clock |
| CAL | Show calendar |
| CLOCK | Real‑time clock (refreshes every 0.1s) |
| FREE | Show memory usage |
| DF | Show disk usage |
| GETPROP | System properties (all when KEY empty, paginated) |
| ENV/EXPORT | Environment variables (help when no args) |
| LOGCAT | System log related functions |
| PATH | Show PATH variable |
| UPTIME | System uptime |
| RES/WM | Display screen info (WM detailed, RES compatible) |
| BATT | Show battery information |
| SYSTEMINFO | System information |
| TL/TASKLIST | Process list |
| TM/TOP/TASKMGR | Task manager |
| TEMP | Show temperature sensors, thermal throttle status |
| MONITOR | Real‑time display of time, memory, temperature (~2s refresh) |
| CPUMONITOR | Real‑time display of each CPU core frequency |
| WHOAMI/OP | Show current user UID and privileges |
| WHICH | Locate command path |
| DISKC | Test read/write speed of mounted points |
| DISKT | Test sequential and random read/write speed of storage device |
| PWD | Show current working directory |
| SDIR | Show script directory |
| SELF | Show current script path |
| NETSTAT | Network connection statistics |
| HOSTNAME | Show hostname |
| DNS | Convert between IPv4 and domain name |
| NETNEIG | Scan local network hosts |
| FTP | FTP functions |
| PING | Test network connectivity |
| SCAN | Scan alive hosts in network |
| PORTSCAN | Scan alive ports of a specified address |
| DOWNLOAD | Download network file to local |
| ST/SPEEDTEST | Network speed test (default Cloudflare 10MB, watch data usage) |
| MCMODDOWNLOAD | Download MC Java mods from Modrinth |
| BASE64/B64 | Base64 encode/decode |
| SHA256 | Compute SHA256 of file |
| SHA1 | Compute SHA1 of file |
| MD5 | Compute MD5 of file |
| CRC32 | Compute CRC32 of file (cksum) |
| DIFF | Compare differences between two files/directories |
| PSD | Generate random password with requirements |
| RAND | Generate random number (default 4 digits) |
| ECHO/PRINT | Display message |
| PRINTF/ECHO -e | Display message with escaped codes |
| CECHO | Custom coloured display (ME's own) |
| ERR | Display error‑style message (red) |
| YES | Flood screen with content until Ctrl+C |
| HACK | Brute‑force printable chars until target found |
| HACK2 | Same as HACK, but using binary search |
| AWKC | AWK calculator |
| BC | Arbitrary precision calculator |
| TIMER | Countdown / alarm clock |
| SLEEP | Sleep for specified seconds |
| WATCH | Execute command repeatedly at interval, clearing screen |
| REPEAT | Repeat command specified number of times |
| CMDTIME | Measure execution time of a command |
| MCSERVER | Simulate running a MC server |
| CLS/CLEAR | Clear screen (-n no title / -r / -y yes) |
| CLSD/CLEARD | Set default clear screen behaviour |
| COLOR | Set console colours |
| TITLE | Set console title |
| TMPDIR | Set/view temporary directory |
| RESOURCE | View loaded resources / reload resources |
| HISTORY | Command history management |
| CONFIG | Show configuration or restore defaults |
| UPDATE | Check for updates |
| INFO | Show script information |
| HELP | This command list (or /?) |
| EXIT/EXIT15 | Normal exit |
| EXIT9 | Force exit |
| EXITK/KILLSELF | Kill self to exit |
| ULIMIT | Limit shell resources |
| SH | Execute external shell script |
| C/CMD | Execute arbitrary system command |
| ADB | Execute ADB command |
| RUNNING | Launch an application |
| KILL | Terminate specified process |

</details>

### Key Features

**Network & Server**
- `DOWNLOAD`: simpler download, just URL and local path
- Windows‑style `PING`
- `SCAN`, `PORTSCAN` (pseudo‑multithreaded scanning)
- Interactive FTP client: supports connection, upload, download, batch operations (mget/mput), perfectly adapted for mobile operation

**System & Android Customisation**
- Built‑in custom `TREE` command – no need for system `tree`
- Full‑scale monitoring: `TASKMGR` (task manager), real‑time memory monitoring
- Android‑specific: `GETPROP` (system properties), `RES/WM` (screen resolution), `LOGCAT` (system logs), `ADB`

**About Minecraft**
- Mod downloader: `MCMODDOWNLOAD` downloads Java edition mods via Modrinth API in batch
- Server simulator (hidden): `MCSERVER` simulates running a Paper server on Android

### Highlights
- Download, extract and use – easy to get started
- Modular design with lazy loading (0.05+), faster startup; new functions can be placed in `resource/` for easy maintenance; config and history stored in `etc/` (0.06+)
- Interactive enhancements: arrow up/down for command history, `HISTORY` command for management (0.06+)
- Persistent configuration: saves colour, title, TMPDIR, clear‑screen default settings
- Detects your privileges and displays different prompt symbols
- Plenty of commands, powerful functionality
- Hidden `laugh` command (no tell you)
- Minecraft‑related features and design

### Core Built‑in Modules

1. **Colour & Output System** (`_cprint`/`cecho`/`ccat`)  
   Provides coloured and styled (bold, italic, underline, strikethrough) terminal output, supports 16‑colour, 256‑colour and hex RGB, and can parse `//cecho` directives in files for colourful text display.

2. **Command Line Parser** (`parse_line`)  
   Custom argument parser supporting single quotes, double quotes, escape characters and comments (`#`), splits input into array `PARSED_ARGS` for main loop command dispatch.

3. **Configuration Management** (`load_config`/`save_config`)  
   Reads/writes default background colour, foreground colour, title display mode, temporary directory etc. from `etc/cmd_config`, and supports persistent saving.

4. **History Management** (`HISTFILE`/history related)  
   Automatically loads and saves command history, checks history file size, deduplicates, and supports various `HISTORY` command operations.

5. **Signal Handling & Exit Mechanisms** (`exit9`/`exit15`/signal traps)  
   Handles Ctrl+C, TERM, etc., recursively kills child process trees, cleans temporary files, and implements safe exit (forceful or graceful).

6. **General Utility Functions** (`confirm`/`kill_tree`/`file_op`/`err`)  
   Provides interactive confirmation, process‑tree killing, file copy/move (with overwrite confirmation), and red error output.

7. **Privilege Detection Module** (`PRIV_LEVEL`/`PROMPT_SYMBOL`)  
   At startup, detects whether current user is root, adb or normal user via `id`, `ps`, `getprop`, and sets prompt accordingly (`#`/`$`/`->`).

8. **Path & Directory Management** (`SCRIPT_DIR`/`RESOURCE_DIR`/`ETC_DIR`/`TMP_DIR`)  
   Defines script root, resource, config and temporary directories, and ensures they exist and are writable.

9. **Lazy Loader** (`lazy_load`)  
   Dynamically loads external commands from `resource/cmd_*.bash` on demand, avoiding loading all extensions at startup for improved speed.

10. **Initialisation Module** (`init_tools`/`load_splashes`/`get_title`)  
    Checks for `busybox` and sets tool prefix, loads random splash messages, displays startup title and version info.

11. **Version Update Check** (background check + `cmd_update`)  
    At startup, fetches latest version from GitHub API in background, caches result and prompts for update in main loop; `UPDATE` command can be used manually for details.

### How to RUN

1. Extract the downloaded `.tar.gz` archive.
2. Open a terminal and execute:
```bash
cd # directory where main script (cmd_main_dev) is located
bash CMD_main_dev.bash
```

After startup, type HELP or /? to see the full command list.

### Runtime Dependencies

Bash 4.0+ is required, and the following must be pre‑installed:

```txt
Awk, Grep, Sed, Cat, Cut, Head, Tail, BC, wget<or>curl
```

Missing these will prevent the script from starting. Missing other dependencies may cause some commands to fail.

### Miscellaneous

Although this script has been developed for a long time (230+ dev versions), there may still be shortcomings. Feel free to raise any issues, but please don't flame if you don't like it. 😉

### License

MIT License
Copyright (c) 2026 DC10Xray

https://img.shields.io/badge/Email-3896444757%40qq.com-brightgreen?logo=gmail&logoColor=white