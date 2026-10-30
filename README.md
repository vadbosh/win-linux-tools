# win-linux-tools

**One PowerShell script installs Linux command-line tools on Windows 10/11:
`ls`, `grep`, `sed`, `awk`, `rg`, `fd`, `jq`, `curl`, `mtr` and more.** Each
tool is a separate program from [Scoop](https://scoop.sh). The script also
updates them and removes everything it added. No WSL, no BusyBox, no winget.

[Русская версия](README.RU.md)

## Contents

- [Quick start](#quick-start)
- [Two modes: with and without -LinuxFirst](#two-modes-with-and-without--linuxfirst)
- [Options](#options)
- [Which command to run](#which-command-to-run)
- [Tools](#tools)
- [Short names](#short-names)
- [File colors](#file-colors)
- [Far Manager](#far-manager)
- [What else the script does](#what-else-the-script-does)
- [Per user, not per computer](#per-user-not-per-computer)
- [Update and removal](#update-and-removal)
- [Requirements](#requirements)

## Quick start

1. Download `Install-LinuxTools.ps1` into any folder, for example `C:\Tools`.
2. Open PowerShell in that folder. An ordinary window is enough.
3. Run:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\Install-LinuxTools.ps1 -LinuxFirst
   ```

4. Read the summary at the end. It lists what works. If something failed, it
   lists what to do by hand.
5. Open a new terminal window. The tools work there.

## Two modes: with and without -LinuxFirst

> [!IMPORTANT]
> **`-LinuxFirst` is a mode, not an extra set of tools.** Both modes install
> the same tools. The mode decides which program opens when you type a name
> that Windows already has: `ls`, `rm`, `find`, `curl`, `sort`.

| You type | Without `-LinuxFirst`, PowerShell | Without `-LinuxFirst`, cmd | With `-LinuxFirst`, PowerShell and cmd |
|---|---|---|---|
| `ls -la` | error: `ls` is PowerShell's `Get-ChildItem` | Linux `ls` | Linux `ls` |
| `rm -rf dir` | error: `rm` is PowerShell's `Remove-Item` | Linux `rm` | Linux `rm` |
| `curl` | PowerShell's `Invoke-WebRequest` | Windows `curl.exe` | Linux `curl` |
| `wget` | PowerShell's `Invoke-WebRequest` | Linux `wget` | Linux `wget` |
| `find . -name "*.log"` | error: Windows `find.exe` searches text | error: Windows `find.exe` searches text | Linux `find` |
| `sort`, `more`, `timeout`, `whoami`, `hostname` | Windows programs or PowerShell commands | Windows programs | Linux tools |
| `grep`, `sed`, `awk`, `rg`, `fd`, `jq`, `bat`, `ll`, `mtr` | Linux tools | Linux tools | Linux tools |
| What changes in your shells | nothing | nothing | a block in the PowerShell profile, doskey macros in cmd |

**Choose `-LinuxFirst`** if you type Linux commands by hand. **Skip it** if
you are used to PowerShell's `ls` and `rm` and the Windows `find`, or if the
names that do not clash are enough.

How it works: in PowerShell, a block in the profile replaces each alias with
the Linux tool, if that tool is installed. In cmd, doskey macros do the same;
with clink they also work after `|` and `&`. Scripts (`.ps1`) do not load the
profile and are not affected. To turn the mode on later, run the script again
with `-LinuxFirst`. `-Uninstall` removes both the block and the macros.

## Options

| Option | What it does |
|---|---|
| *(none)* | Installs the base tools. Tools that are already installed stay as they are. |
| **`-LinuxFirst`** | **Mode.** Installs, and makes Linux names win over Windows names in PowerShell and cmd: [details](#two-modes-with-and-without--linuxfirst). |
| `-WithFar` | Also installs Far Manager with plugins, a dark theme and settings: [details](#far-manager). |
| `-WithNmap` | Also installs `nmap` and `ncat` (`nc`) with the Npcap driver. |
| `-Update` | Updates Scoop and every tool the script installed, Far plugins included. Installs tools that were added to the script later. |
| `-Uninstall` | Removes what the script added. Keeps git, Visual C++ and Npcap. |
| `-Help`, `--help` | Shows the help. |

Without `-WithFar` and `-WithNmap`, Far and nmap are not installed. Add either
option at any time; nothing installed earlier is removed, and the other
options do not need to be repeated. `-Update` does not add Far or nmap.

## Which command to run

| You want | Run |
|---|---|
| The Linux tools, Windows commands stay as they are | `.\Install-LinuxTools.ps1` |
| To type `ls -la`, `rm -rf`, `find . -name` by hand | `.\Install-LinuxTools.ps1 -LinuxFirst` |
| A two-panel file manager, like mc | `.\Install-LinuxTools.ps1 -WithFar` |
| Port scans and netcat | `.\Install-LinuxTools.ps1 -WithNmap` |
| Everything | `.\Install-LinuxTools.ps1 -LinuxFirst -WithFar -WithNmap` |
| New versions, and tools added to the script later | `.\Install-LinuxTools.ps1 -Update` |
| To remove it all | `.\Install-LinuxTools.ps1 -Uninstall` |

If running scripts is blocked, or you are in cmd, start each command with
`powershell -ExecutionPolicy Bypass -File`.

## Tools

| Command | What it is for |
|---|---|
| `ls cat head tail wc cut sort uniq tr tee du cp mv rm …` | 89 GNU core utilities (uutils, in Rust) with the usual Linux options |
| `find`, `xargs` | Find files by name, size or date; pass a list of files to another command |
| `grep` | Search text in files with regular expressions |
| `awk` | Work with columns of text: pick fields, add up numbers, reformat |
| `sed` | Replace text in a stream or a file |
| `less` | Page through long output and search in it |
| `jq` | Read, filter and reshape JSON |
| `which` | Show which file a command runs |
| `rg` (ripgrep) | Fast recursive search in code; skips files listed in `.gitignore` |
| `ug`, `ugrep` | grep with the same options, plus search inside archives (`-z`) and an interactive mode (`-Q`) |
| `fd` | A fast and simple `find`: `fd name` |
| `lsd`, `ll` | `ls` with colors and readable columns; `ll` is the long listing |
| `eza` | Another modern `ls`: tree view (`--tree`), git status of files |
| `bat` | `cat` with syntax highlighting and line numbers |
| `dust` | Which folders take the space, as a bar chart |
| `gdu` | Disk usage you can browse and clean up interactively, like ncdu |
| `duf` | Free space on every disk, as a table (`df`) |
| `btm` (bottom) | `top` with graphs: CPU, memory, network, processes |
| `procs` | `ps` with readable columns and search |
| `sudo` (gsudo) | Run one command as administrator in the same window |
| `dig`, `host` | DNS queries |
| `trip`, `mtr` | traceroute and ping in one live screen |
| `whois` | Who owns a domain or an IP address |
| `xh` | HTTP requests with readable output, like HTTPie |
| `curl` | A current curl; the curl.exe built into Windows stays |
| `wget` | Download files, resume a download, mirror a site |
| `git` | Scoop needs it to update itself; a full git you can use |
| `nmap`, `nping` | Port and host scans *(with `-WithNmap`)* |
| `ncat`, `nc` | Read and write network connections, netcat *(with `-WithNmap`)* |
| `far` | Two-panel file manager, like mc *(with `-WithFar`)* |

`tree` is already in Windows. `Get-Help .\Install-LinuxTools.ps1 -Full`
lists the Scoop package and the source of every tool.

## Short names

They work in PowerShell and cmd, also without `-LinuxFirst`.

| Name | Runs |
|---|---|
| `ll` | `lsd -lha --group-directories-first --date "+%F %R:%S" --icon never` |
| `mtr` | `trip` through gsudo: it needs administrator rights and asks for them |
| `nc` | `ncat` |
| `nmap`, `nping` | the same, through gsudo *(with `-WithNmap`)* |
| `far` | Far opens in the current folder. After you quit Far, the shell stays in the folder Far was in *(with `-WithFar`)* |

## File colors

`ll`, `eza`, `ls` and `fd` color names by type. Without settings, folders come
out in the console's dark blue `#0037DA` and are hard to read. The script sets
`LS_COLORS` and `EZA_COLORS` for your user, with readable colors for folders
and file types. Links get a turquoise background, and `ll` shows them as
`name ⇒ link to target`.

The script does not touch a value you set yourself. New colors appear in new
windows; cmd sometimes needs you to sign out of Windows and back in.

## Far Manager

With `-WithFar` the script installs Far Manager and sets it up:

- **Plugins.** NetBox (SFTP, FTP, SCP, WebDAV, S3) and IntChecker2
  (checksums). Each comes from the latest GitHub release and is checked by
  SHA-256. ArcLite (archives) and FarColorer (syntax highlighting) come with
  Far.
- **Theme.** FarDark-2026, fixed to one commit and checked by hash. The
  theme files store colors in the wrong byte order; the script swaps them, so
  folders are blue, not orange.
- **Brighter colors.** Panel cursor `#4B5263`, editor line numbers `#275A65`,
  editor status line `#124B55`, current line in the editor `#3A3D41`.
- **Settings.** 24-bit color (VT rendering), settings saved on exit, the
  FarColorer TrueMod style. In the editor (F4): line numbers, scroll bar, auto
  indent, Tab as spaces, cursor stops at the end of a line.
- **Folder hand-over.** `far` opens in the current folder; after you quit,
  PowerShell or cmd stays in the folder Far was in, like `mc` in Linux.

The script saves the old values and `-Uninstall` puts them back. A plugin
folder that the script did not create is left alone. `-Update` updates Far and
its plugins; it skips Far while Far is running.

## What else the script does

- **Missing DLLs.** After each package it reads which Visual C++ runtime the
  programs need, downloads Visual C++ 2015–2022 of that architecture from
  Microsoft, checks the signature and installs it. Without the x64 runtime
  most tools do not start, so if it fails, the script stops before it changes
  anything else.
- **Npcap.** For `-WithNmap` it opens the Npcap installer from the nmap
  package after it checks the signature.
- **Log.** Every run writes its full output to
  `Install-LinuxTools_<date-time>.log` next to the script.
- **Summary.** At the end: what works, what not to start, warnings without
  repeats, and what to do by hand, in order.
- **Record of changes.** What the script added is kept in
  `%LOCALAPPDATA%\Install-LinuxTools\state.json`. `-Uninstall` reads it.

## Per user, not per computer

The script changes only the environment of the Windows user who runs it:

| What | Where |
|---|---|
| Scoop and the tools | `%USERPROFILE%\scoop`, or `%SCOOP%` if it is set |
| `PATH`, `LS_COLORS`, `EZA_COLORS` | environment variables of the user |
| PowerShell block, `far` function | `profile.ps1` files in the user's Documents folder |
| cmd macros | `AutoRun` in `HKCU\Software\Microsoft\Command Processor` |
| Far settings, plugins, theme | `persist\far` in the Scoop folder |
| lsd settings | `%APPDATA%\lsd\config.yaml` |
| Execution policy | scope `CurrentUser` |
| Record of changes | `%LOCALAPPDATA%\Install-LinuxTools\state.json` |

Other users of the computer get none of this. Each user runs the script in
their own account and gets their own copy and settings. An administrator can
still start a program by its full path, for example
`C:\Users\<user>\scoop\apps\far\current\Far.exe`, but the commands and
settings above are not set up for them.

Two exceptions are installed for the whole computer and need administrator
rights: the Visual C++ 2015–2022 runtime and the Npcap driver.
`-Uninstall` keeps them.

## Update and removal

`-Update` updates Scoop, every tool the script installed, the Far plugins and
theme, and installs tools that were added to the script later.

`-Uninstall` removes only what the script added:

- its packages;
- Scoop, if the script installed it and no other package is left in it;
- the PowerShell profile block and the cmd macros;
- the colors, the Far settings and plugins;
- the execution policy change.

It keeps:

- **git**: your repositories may need it. Remove it with `scoop uninstall git`.
- **Visual C++ and Npcap**: other programs may need them.

## Requirements

Windows 10 or 11 and Windows PowerShell 5.1 (built in). Internet access to
GitHub, Scoop and Microsoft. Installing Visual C++ and Npcap asks for
administrator rights.

Tested on two machines. On Windows 11, under an account without
administrator rights: install with `-WithFar` and `-WithNmap`, `-Update`,
`-Uninstall`.

## License

[MIT](LICENSE)
