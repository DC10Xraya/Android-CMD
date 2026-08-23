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
![Lines](https://img.shields.io/badge/Code-8800%2B-blue)
![Android](https://img.shields.io/badge/Platform-Android-brightgreen?logo=android)

An interactive Bash script integrating common operations, network, and system monitoring functions (plus jokes), designed specifically to run on Android.

<details>
<summary><h2>Commands (91) Click to view</h2></summary>

Note: Does not include hidden (laugh) and debugging commands

| Command | Description |
| :--- | :--- |
| COPY/CP | Copy files/directories |
| RM/DEL | Delete files or directories |
| RD/RMDIR | Delete empty directories |
| FIND | Search within specified files |
| MD/MKDIR | Create directories |
| NEW/TOUCH | Create new files |
| MOVE | Move or rename |
| REN | Rename files |
| DIR | List directory contents |
| DU | List directory size |
| SIZE | List file size |
| STAT | Display detailed file information |
| LN -s | Create symbolic links |
| TREE | Display directory tree |
| TYPE | View text files |
| MORE | View paginated |
| ZIP | Create ZIP archives |
| UNZIP | Extract ZIP archives |
| NOW | Display current clock |
| CAL | Display calendar |
| CLOCK | Real-time clock |
| FREE | Memory usage |
| DF | Disk usage |
| GETPROP | System properties |
| ENV/EXPORT | Environment variables |
| LOGCAT | System logs |
| UPTIME | System uptime |
| RES/WM | Screen info |
| BATT | Battery info |
| SYSTEMINFO | System information |
| TL/TASKLIST | Process list |
| TM/TOP/TASKMGR | Task manager |
| TEMP | Temperature monitoring |
| MONITOR | Monitor time, memory, temperature |
| WHOAMI/OP | User UID and permissions |
| WHICH | Find command path |
| DISKC | Mount point read/write speed |
| DISKT | Storage device read/write speed |
| PWD | Current directory |
| SELF | Script path |
| NETSTAT | Network connection statistics |
| HOSTNAME | Hostname |
| DNS | Convert IPv4 or domains |
| NETNEIG | Scan LAN hosts |
| FTP | FTP functions |
| PING | Test network connections |
| SCAN | Scan live hosts |
| PORTSCAN | Scan live ports |
| DOWNLOAD | Download network files |
| ST/SPEEDTEST | Network speed test |
| MCMODDOWNLOAD | Download mods from Modrinth |
| BASE64/B64 | Base64 encode/decode |
| SHA256 | Calculate SHA256 |
| SHA1 | Calculate SHA1 |
| MD5 | Calculate MD5 |
| CRC32 | Calculate CRC32 |
| PSD | Generate random passwords |
| RAND | Generate random numbers |
| ECHO/PRINT | Display messages |
| PRINTF/ECHO -e | Parse and display code |
| CECHO | Custom display |
| ERR | Display errors |
| YES | Spam output |
| HACK | Exhaustive target search |
| HACK2 | Binary search exhaustive target |
| AWKC | AWK calculator |
| BC | Arbitrary precision calculator |
| TIMER | Countdown/Alarm |
| SLEEP | Sleep for a specified time |
| WATCH | Loop execute commands |
| REPEAT | Repeat execution a specified number of times |
| CLS/CLEAR | Clear screen |
| CLSD/CLEARD | Set default clear screen behavior |
| COLOR | Set console colors |
| TITLE | Set console title |
| TMPDIR | Set temporary directory |
| RESOURCE | View/Reload resources |
| HISTORY | Command history |
| CONFIG | View config or restore |
| UPDATE | Check for updates |
| INFO | Display script information |
| HELP | View help |
| EXIT/EXIT15 | Normal exit |
| EXIT9 | Force exit |
| EXITK/KILLSELF | Kill self |
| ULIMIT | Limit SHELL |
| SH | Execute external SHELL scripts |
| C/CMD | Execute system commands |
| ADB | Execute ADB commands |
| RUNNING | Launch applications |
| KILL | Terminate specified processes |

</details>

### Key Features
Network & Server
- DOWNLOAD: Simplified downloading, just need URL and local path
- WINDOWS-style PING
- SCAN, PORTSCAN (pseudo-multithreaded scanning)
- Interactive FTP Client: Supports connecting, uploading, downloading, batch operations (mget/mput), perfectly adapted for mobile operation

System & Android Customization
- Built-in handwritten TREE command, no system tree tool required
- All-round monitoring: TASKMGR (Task Manager), MEMORY real-time monitoring
- Android specific: GETPROP (System Properties), RES/WM (Screen Resolution), LOGCAT (System Logs), ADB

About Minecraft
- Mod Downloader: MCMODDOWNLOAD via Modrinth API, batch download Java Edition mods
- Server Simulator (Hidden): MCSERVER simulates running a JAVA Edition Paper server on mobile

### Features
- One-click use after downloading and extracting, easy to get started
- Modular design, Lazy loading (0.05+), faster startup; New functions can be placed in the resource directory, easy to maintain; Configuration and history are stored in the etc directory (0.06+)
- Enhanced interaction: Use up/down arrows to recall history commands, HISTORY command to manage records (0.06+)
- Save configuration: Save your Color, Title, TMPDIR, Clsd settings
- Identify your permissions and give you different command prompts
- Numerous commands and powerful features, over 230 development versions
- Laugh hidden commands (No tell you)
- About Minecraft features and design

### Core Base Modules (Built into Main Program)

1. **Color and Output System** (`_cprint`/`cecho`/`ccat`)
   Provides terminal output with colors and styles (bold, italic, underline, strikethrough), supports 16-color, 256-color, and hexadecimal RGB, and can parse `//cecho` directives in files to display colored text.

2. **Command Line Parser** (`parse_line`)
   Custom parameter parsing, supporting single quotes, double quotes, escape characters, and comments (`#`), splitting input into array `PARSED_ARGS` for main loop command dispatch.

3. **Configuration Management** (`load_config`/`save_config`)
   Read and write default background color, foreground color, title display mode, temp directory, and other user configurations from `etc/cmd_config`, supporting persistent storage.

4. **History Record Management** (`HISTFILE`/history related)
   Automatically load and save command history, supporting history file size checks, deduplication, and various operations of the `HISTORY` command.

5. **Signal Handling and Exit Mechanism** (`exit9`/`exit15`/signal traps)
   Handles Ctrl+C, TERM, and other signals, recursively kills subprocess trees, cleans up temp files, and implements safe exit (force or gentle methods).

6. **General Helper Functions** (`confirm`/`kill_tree`/`file_op`/`err`)
   Provides interactive confirmation, process tree killing, file copy/move (with overwrite confirmation), and red error output common tools.

7. **Permission Detection Module** (`PRIV_LEVEL`/`PROMPT_SYMBOL`)
   On startup, detect if current user is root, adb, or normal user via `id`, `ps`, `getprop`, and set the corresponding prompt (`#`/`$`/`->`).

8. **Path and Directory Management** (`SCRIPT_DIR`/`RESOURCE_DIR`/`ETC_DIR`/`TMP_DIR`)
   Define script root directory, resource directory, configuration directory, and temp directory, ensuring they exist and are writable.

9. **Lazy Loader** (`lazy_load`)
   Dynamically load `cmd_*.bash` external commands from the `resource/` directory on demand, avoiding loading all extensions at startup and improving startup speed.

10. **Initialization Module** (`init_tools`/`load_splashes`/`get_title`)
    Detects `busybox` and sets tool prefixes, loads random slogans, displays startup title and version information.

11. **Version Update Check** (Background check + `cmd_update`)
    Fetches the latest version from GitHub API in the background at startup, caches the result and prompts for updates in the main loop; `UPDATE` command to manually view details.

### How to Run
1. Extract the downloaded .tar.gz archive
2. Open a terminal and execute:
```bash
cd #Directory where main program (cmd_main_dev) is located
bash CMD_main_dev.bash
```

After startup, enter HELP or /? to view all command lists

Dependencies

Basic environment is Bash 4.0+, must be pre-installed:

```txt
Awk, Grep, Sed, Cat, Cut, Head, Tail, BC, wget<or>curl
```

Missing these dependencies will prevent the script from starting. Missing other dependencies may cause certain commands to be unavailable.

Miscellaneous

Although this script has been developed for a long time (230+ dev), it inevitably has shortcomings. Feel free to raise any issues. Don't hate if you don't like it :D

License

MIT License
Copyright (c) 2026 DC10Xray

https://img.shields.io/badge/Email-3896444757%40qq.com-brightgreen?logo=gmail&logoColor=white