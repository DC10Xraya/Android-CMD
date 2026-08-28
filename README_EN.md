# Android CMD

## [简体中文](README.md) | **English**

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

An interactive Bash script integrating common operations, network and system monitoring features (plus jokes), specifically designed to run on Android.

<details>
<summary><h2>Commands (109) Click to expand</h2></summary>

Note: Hidden (laugh) and debug commands are not included.

| Command | Description |
| :--- | :--- |
| COPY/CP | Copy files/directories |
| CD | Change working directory |
| DD | Copy and convert file |
| RM/DEL | Delete file or directory |
| RD/RMDIR | Remove empty directory |
| FIND | Search for string/regex in files |
| HEAD | Show first N lines of file |
| TAIL | Show last N lines of file |
| MD/MKDIR | Create directory |
| NEW/TOUCH | Create new file or update timestamp |
| MOVE | Move or rename files/directories |
| REN | Rename file |
| DIR/LS | List directory contents |
| DU | Show directory size |
| SIZE | Show file size |
| STAT | Show file details |
| WC | Count lines, words, characters |
| CODEWC | Count code lines, words, characters (BETA) |
| LN -s | Create symbolic link |
| TREE | Display directory tree |
| TYPE | View text file |
| CAT | View text file (system) |
| MORE | Paginated view (no colour) |
| ZIP | Create ZIP archive |
| UNZIP | Extract ZIP archive |
| DUMP | Export folder structure to text file |
| FORMAT | Format storage device (root required) |
| MOUNT | Mount filesystem (root required) |
| UMOUNT | Unmount filesystem (root required) |
| NOW | Show current time |
| CAL | Show calendar |
| CLOCK | Real‑time clock (0.1s refresh) |
| FREE | Memory usage |
| DF | Disk usage |
| GETPROP | System properties |
| ENV/EXPORT | Environment variables |
| LOGCAT | System log management |
| PATH | Show PATH variable |
| UPTIME | System uptime |
| RES/WM | Screen resolution (WM detailed) |
| BATT | Battery information |
| SYSTEMINFO | System information |
| TL/TASKLIST | Process list |
| TM/TOP/TASKMGR | Task manager |
| TEMP | Temperature sensors & thermal status |
| MONITOR | Real‑time time/memory/temperature |
| CPUMONITOR | Real‑time CPU core frequencies |
| WHOAMI/OP | Show current user UID and privileges |
| WHICH | Locate command path |
| DISKC | Mount point read/write speed test |
| DISKT | Storage device sequential/random speed test |
| PWD | Show current working directory |
| SDIR | Show script directory |
| SELF | Show current script path |
| NETSTAT | Network connection statistics |
| HOSTNAME | Show hostname |
| DNS | Convert between domain and IP |
| NETNEIG | Scan local network hosts |
| FTP | FTP functions |
| PING | Test network connectivity |
| SCAN | Scan alive hosts |
| PORTSCAN | Scan open ports |
| DOWNLOAD | Download network file to local |
| ST/SPEEDTEST | Network speed test |
| MCMODDOWNLOAD | Download MC mods from Modrinth |
| BASE64/B64 | Base64 encode/decode |
| SHA256 | Compute SHA256 |
| SHA1 | Compute SHA1 |
| MD5 | Compute MD5 |
| CRC32 | Compute CRC32 |
| DIFF | Compare files/directories |
| JSON | Validate JSON format |
| PSD | Generate random password |
| RAND | Generate random number |
| ECHO/PRINT | Display message |
| PRINTF/ECHO -e | Display with escape interpretation |
| CECHO | Custom coloured display |
| ERR | Error message (red) |
| YES | Flood screen until Ctrl+C |
| HACK | Brute‑force printable chars |
| HACK2 | Binary‑search brute‑force |
| AWKC | AWK calculator |
| BC | Arbitrary precision calculator |
| TIMER | Countdown / alarm |
| SLEEP | Sleep for specified seconds |
| WATCH | Execute command periodically (clear screen) |
| REPEAT | Repeat command N times |
| CMDTIME | Measure command execution time |
| MCSERVER | Simulate MC server running |
| FUN/FUNCTION | Define temporary function (lost on restart) |
| CLS/CLEAR | Clear screen |
| CLSD/CLEARD | Set default clear behaviour |
| COLOR | Set console colour |
| TITLE | Set terminal title |
| TMPDIR | Set/view temporary directory |
| RESOURCE | View/reload resources |
| HISTORY | Command history management |
| CONFIG | Show or restore default config |
| UPDATE | Check for updates |
| INFO | Show script information |
| HELP | Show this help (or /?) |
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
- Command-rich and powerful
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

Although this script has been developed for a long time, there may still be shortcomings. Feel free to raise any issues, but please don't flame if you don't like it. 😉

### License

MIT License

Copyright (c) 2026 DC10Xray