# win-linux-tools

**One PowerShell script installs Linux command-line tools on Windows 10/11:
`ls`, `grep`, `sed`, `awk`, `rg`, `fd`, `jq`, `curl`, `mtr` and more.** Each
tool is a separate program from [Scoop](https://scoop.sh). The script also
updates them and removes everything it added. No WSL, no BusyBox, no winget.

[Русская версия](README.RU.md)

## Contents

- [Quick start](#quick-start)
- **🔵 [Firewall rules for mtr](#firewall-rules-for-mtr)**
- [Two modes: with and without -LinuxFirst](#two-modes-with-and-without--linuxfirst)
- [Options](#options)
- [Which command to run](#which-command-to-run)
- [Tools](#tools)
- [Short names](#short-names)
- [File colors](#file-colors)
- [Nerd Font and Windows Terminal](#nerd-font-and-windows-terminal)
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

## Firewall rules for mtr

> [!IMPORTANT]
> Windows Defender Firewall drops the ICMP replies that `trip` waits for, so
> `mtr` shows no hops. The script adds two inbound rules for any program. They
> allow reply types only: ICMPv4 0, 3 and 11 (Echo Reply, Destination
> Unreachable, Time Exceeded) and ICMPv6 129 (Echo Reply). The computer still
> does not answer ping.
>
> A rule for `trip.exe` alone does not work: Windows does not match ICMP on a
> raw socket to a program. If Windows does not give administrator rights, the
> summary lists the command to run by hand. `-Uninstall` removes the rules.
>
> To add only these rules, without the rest of the script, run
> `tools\Enable-TripFirewall.ps1`; `-Remove` deletes them.

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
| `cat a.txt \| sort` — a Windows name after `\|` or `&` | PowerShell's `Sort-Object` | Windows `sort.exe` | PowerShell: Linux `sort`. cmd: Linux `sort` with [clink](#cmd-and-clink), Windows `sort.exe` without it |
| `grep`, `sed`, `awk`, `rg`, `fd`, `jq`, `bat`, `ll`, `mtr` | Linux tools | Linux tools | Linux tools |
| Grey hint from history as you type | no | no | PowerShell: yes. cmd: only with [clink](#cmd-and-clink) |
| What changes in your shells | nothing | nothing | a block in the PowerShell profile, doskey macros in cmd |

**Choose `-LinuxFirst`** if you type Linux commands by hand. **Skip it** if
you are used to PowerShell's `ls` and `rm` and the Windows `find`, or if the
names that do not clash are enough.

How it works: in PowerShell, a block in the profile turns each name into a
small function, if its Linux tool is installed. A command you type runs the
Linux tool. The same name in a script or in a Windows module runs what it ran
before: `sort` runs `Sort-Object`, `find` runs Windows `find.exe`. In cmd,
doskey macros do the same: they work only for what you type.
PowerShell also shows the rest of a matching command from history in grey;
Right arrow accepts it. Windows PowerShell 5.1 comes with PSReadLine 2.0,
which cannot do this, so the script installs the current PSReadLine from
PSGallery for your user. A PSReadLine 2.1+ that you installed stays as it is.
Also with `-LinuxFirst`, [posh-git](https://github.com/dahlbyk/posh-git) shows
the git branch and changes in the prompt. It also completes git commands with
Tab. [fzf](https://github.com/junegunn/fzf) with
[PSFzf](https://github.com/kelleyma49/PSFzf) adds two keys. Ctrl+R is a fuzzy
search over the whole history. Ctrl+T is a file search that pastes the path.

History works as in bash with `HISTSIZE=999999`, `ignorespace` and
`HISTIGNORE='ls:ll:la:pwd:exit:history:clear'`. It keeps 999999 commands. A
command that starts with a space is not saved, and neither is a line that is
exactly one of those commands; `ls -la` is saved. Arrows do not show a repeat
twice, but the history file keeps it. `history` lists the whole saved
history with numbers and times (`%F %T`), `history 20` the last 20.
PowerShell does not record when a command ran, so the profile writes the time
of each saved command to `Install-LinuxTools-times.txt` next to the
PSReadLine history. Commands from before that have no time. `-Uninstall`
deletes the file.

Scripts (`.ps1`) and Windows modules work as without `-LinuxFirst`, also
when you start them from that window. To turn the mode on later, run the script again with `-LinuxFirst`. `-Uninstall` removes
both the block and the macros.

### cmd and clink

[clink](https://chrisant996.github.io/clink/) is not
required. Without it, a doskey macro works only as the first word of a line:
in `dir | sort` or `cd x & find . -name a` the Windows `sort.exe` and
`find.exe` run. This applies only to names that Windows also has (`find`,
`sort`, `more`, `timeout`, `whoami`, `hostname`, `curl`); the other tools work
anywhere in the line. With clink the macros also work after `|` and `&`.
Without it, use the full path: `dir | %USERPROFILE%\scoop\shims\sort.exe`.

cmd without clink has no grey hints. Its own history keys: F8 completes the
typed start from history (press again for older matches), F7 shows a list.
`-WithClink` installs clink from Scoop and starts it with every cmd window
(`clink autorun install`). It turns on clink's grey hints
(`autosuggest.enable`) and the Windows key bindings
(`clink.default_bindings windows`), as clink's own installer does with
enhanced defaults. At the start of cmd, clink prints one
short version line instead of its copyright notice (`clink.logo short`); to
remove it too, run `clink set clink.logo none`.

History in clink is set up as in bash too. It keeps 999999 lines, skips a
line that starts with a space and keeps no repeats (`erasedups`). `history`
shows the time of each command (`%F %T`). Unlike bash, clink checks `ls ll la pwd exit history
clear` against the first word, so `ls -la` is not saved either.

Keys in clink:

- Right arrow accepts the grey hint; F2 lists all hints.
- Up and Down search history by the typed start.
- Tab puts the next matching command or file name into the line, Shift+Tab
  the previous one, as in PowerShell.

The script adds Up, Down, Tab and Shift+Tab to `.inputrc`. A clink that you
already start with cmd stays as it is.

## Options

| Option | What it does |
|---|---|
| *(none)* | Installs the base tools. Tools that are already installed stay as they are. |
| **`-LinuxFirst`** | **Mode.** Installs, and makes Linux names win over Windows names in PowerShell and cmd: [details](#two-modes-with-and-without--linuxfirst). |
| `-WithFar` | Also installs Far Manager with plugins, a dark theme and settings: [details](#far-manager). |
| `-WithNmap` | Also installs `nmap` and `ncat` (`nc`) with the Npcap driver. |
| `-WithOhMyPosh` | Also installs oh-my-posh with a prompt theme that needs no special font: [`themes/install-linuxtools.omp.json`](themes/install-linuxtools.omp.json). Edit it and run `-Update` to apply. With `-WithClink` too, cmd gets the same prompt: [`themes/oh-my-posh.lua`](themes/oh-my-posh.lua) goes to `%LOCALAPPDATA%\clink`. Other oh-my-posh themes draw icons and need a Nerd Font: the script installs JetBrainsMono Nerd Font and sets it in Windows Terminal ([Nerd Font and Windows Terminal](#nerd-font-and-windows-terminal)). |
| `-WithClink` | Also installs [clink](#cmd-and-clink) for cmd: grey hints from history, macros after `\|` and `&`. |
| `-Update` | Updates Scoop and every tool the script installed, Far plugins included. Installs tools that were added to the script later. |
| `-Uninstall` | Removes what the script added. Keeps git, Visual C++ and Npcap. |
| `-Uninstall -WithFar`, `-WithNmap`, `-WithClink`, `-WithOhMyPosh` | Removes only that add-on. Everything else stays. |
| `-Help`, `--help` | Shows the help. |

Without `-WithFar`, `-WithNmap` and `-WithClink`, Far, nmap and clink are not
installed. Add either
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
| To remove only Far, or only nmap | `.\Install-LinuxTools.ps1 -Uninstall -WithFar`, `-Uninstall -WithNmap` |
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
| `lsd` | `ls` with colors and readable columns |
| `eza`, `ll` | Another modern `ls`: tree view (`--tree`), git status of files; `ll` is the long listing |
| `bat` | `cat` with syntax highlighting and line numbers |
| `dust` | Which folders take the space, as a bar chart |
| `gdu` | Disk usage you can browse and clean up interactively, like ncdu; the script sets its colors and a percentage next to the size bar |
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
| `clink` | Bash-like line editing in cmd *(with `-WithClink`)* |
| `oh-my-posh` | Two-line PowerShell prompt `┌──user@host [folder] \| branch` / `└─>` in Material colors, brighter colors of the typed command; no special font *(with `-WithOhMyPosh`)* |
| `fzf` | Fuzzy finder: Ctrl+R history, Ctrl+T files in PowerShell *(with `-LinuxFirst`)* |

`tree` is already in Windows. `Get-Help .\Install-LinuxTools.ps1 -Full`
lists the Scoop package and the source of every tool.

## Short names

They work in PowerShell and cmd, also without `-LinuxFirst`.

| Name | Runs |
|---|---|
| `ll` | `eza -la --classify --git --smart-group --group-directories-first --time-style "+%F %R:%S"` |
| `mtr` | `trip` through gsudo: it needs administrator rights and asks for them |
| `nc` | `ncat` |
| `nmap`, `nping` | the same, through gsudo *(with `-WithNmap`)* |
| `far` | Far opens in the current folder. After you quit Far, the shell stays in the folder Far was in *(with `-WithFar`)* |

`ll` shows folders first, then files: attributes, size, date and time to the
second, git status (`-M`, `N-`, … inside a repository), name. A `/` after a
name marks a folder, `*` a program. Folders have no size: eza cannot add up a
folder on Windows (`--total-size` works on Unix only); see folder sizes with
`dust` or `gdu`.

## File colors

`ll`, `eza`, `ls` and `fd` color names by type. Without settings, folders come
out in the console's dark blue `#0037DA` and are hard to read. The script sets
`LS_COLORS` and `EZA_COLORS` for your user, with readable colors for folders
and file types. Links get a turquoise background; `ll` shows them as
`name -> target`, `lsd -l` as `name ⇒ link to target`.

`grep`, `egrep` and `fgrep` highlight what they found in bold green, as with
`alias grep='grep --color=auto'` and `GREP_COLORS='mt=1;32'` in Linux. The
script adds `--color=auto` to their shims and sets `GREP_COLORS` for your
user. In a pipe or a file, grep writes no color codes.

`less` shows colors from a pipe, for example from
`grep --color=always … | less`, instead of `ESC[` codes. For that the script
sets `LESS=-FRX -Da` for your user. `F` and `X` are what git uses when `LESS`
is not set. Short output is printed without the pager, and the screen is not
cleared on exit. `-Da` is an option of less for Windows: it passes color
codes to the console as they are. Without it, short output came out with no
color.

The script does not touch a value you set yourself. New colors appear in new
windows; cmd sometimes needs you to sign out of Windows and back in.

## Nerd Font and Windows Terminal

The script installs two fonts from the Scoop bucket `nerd-fonts`:

- `JetBrainsMono-NF` (JetBrainsMono Nerd Font) for Windows Terminal;
- `JetBrainsMono-NF-Mono` (JetBrainsMono Nerd Font Mono) for the classic
  console: every icon takes one cell.

With administrator rights the fonts are installed for all users
(`scoop install -g`). The script also adds JetBrainsMono Nerd Font Mono to
`HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Console\TrueTypeFont`. Only
then does the font appear in the console font list (window Properties >
Font). From a window without administrator rights the script asks for them
through UAC. If you refuse, it installs both fonts for your user: Windows
Terminal sees them, the console does not.

`-Update` updates the fonts for all users only when the bucket has a new
version, so UAC does not ask on every run. `-Uninstall` removes the fonts and
the console list entry; close Windows Terminal and console windows that use
the font first. A font or a list entry that the script did not add stays.

If Windows Terminal is installed, the script merges
[`themes/settings.json`](themes/settings.json) into its `settings.json`.
That brings the One Half Dark Terminal Pro colors, the Terminal Pro UI
theme, the font, copy on select and four keys. These parts change:

- top-level settings such as `defaultProfile` (cmd) and `copyOnSelect`;
- `profiles.defaults`, field by field;
- the Windows PowerShell and Command Prompt profiles, field by field;
- color schemes and themes with the same name;
- key bindings on the same keys.

Your own profiles, your other keys and `actions` stay. Before the first
merge the script copies your file to `settings.json.install-linuxtools.bak`
next to it. `-Update` merges again only when `themes/settings.json` changes,
so your own later changes in Terminal stay. `-Uninstall` puts the copy back.
If you changed the file after the script wrote it, `-Uninstall` keeps both
files and says so.

The script changes only a Windows Terminal installed in the system. That is
the Microsoft Store package and its Preview; Windows 11 and `winget` install
the same package. Where there is no Store and no `winget` (Windows 11 IoT
LTSC), [`tools/Install-WindowsTerminal.ps1`](tools/Install-WindowsTerminal.ps1)
installs that package from the latest GitHub release; `-Remove` removes it
completely. The Store one keeps its settings only after its first
start: open it once, then run `-Update`. A portable Terminal (`.portable`
next to `WindowsTerminal.exe`, for example from Scoop or from your own
folder) and one without a package are left alone. If an earlier version of
the script changed a portable one, the next run puts your file back from the
copy. A `settings.json` with
comments (`//`) is left alone: Windows PowerShell 5.1 cannot read it, and the
summary says what to do by hand.

## Far Manager

With `-WithFar` the script installs Far Manager and sets it up:

- **Plugins.** NetBox (SFTP, FTP, SCP, WebDAV, S3) and IntChecker2
  (checksums). Each comes from the latest GitHub release and is checked by
  SHA-256. ArcLite (archives) and FarColorer (syntax highlighting) come with
  Far.
- **Theme.** FarDark-2026 from
  [Phoenix-/theming-far](https://github.com/Phoenix-/theming-far). The
  theme files store colors in the wrong byte order; the script swaps them, so
  folders are blue, not orange.
- **Brighter colors.** Panel cursor `#4B5263`, editor line numbers `#275A65`,
  editor status line `#124B55`, current line in the editor `#3A3D41`.
- **Settings.** 24-bit color (VT rendering), settings saved on exit, the
  FarColorer TrueMod style. In the editor (F4): line numbers, scroll bar, auto
  indent, Tab as spaces, cursor stops at the end of a line.
- **Folder hand-over.** `far` opens in the current folder; after you quit,
  PowerShell or cmd stays in the folder Far was in, like `mc` in Linux.
- **Backspace goes one folder up** in a panel when the command line is
  empty, like in mc (a Far macro; Ctrl+PgUp does the same).
- **Desktop shortcuts.** `Far4Pwsh` opens PowerShell and `Far4CMD` opens
  cmd; both run Far. After you quit Far (F10), the window stays open in the
  folder Far was in.

The script saves the old values and `-Uninstall` puts them back. A plugin
folder or a desktop shortcut that the script did not create is left alone.
`-Update` updates Far and its plugins; it skips Far while Far is running.

When the theme author changes the theme, `-Update` installs the new version.
The script compares the git hashes of the three theme files with the ones it
installed; a change in the author's README does not count. It then applies
its own changes on top again: the byte order, the brighter colors and the
FarColorer style. Your own color changes in Far (F9 > Colors) and in
`FarDark2026.hrd` stay until such an update. The update then overwrites them
for the items that the theme sets. If the author renames `Panel.Cursor` or
`def:HorzCross`, the script says that its own colors could not be applied. If
GitHub does not answer, the installed theme stays.

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
| Far desktop shortcuts | the user's Desktop |
| PSReadLine, posh-git, PSFzf (with `-LinuxFirst`) | `WindowsPowerShell\Modules` in the user's Documents folder |
| clink start with cmd | `AutoRun` in `HKCU\Software\Microsoft\Command Processor` |
| clink keys | a marked block in `%USERPROFILE%\.inputrc` or your existing `.inputrc` |
| gdu colors | `%USERPROFILE%\.gdu.yaml` (only if you have none) |
| lsd settings | `%APPDATA%\lsd\config.yaml` |
| Execution policy | scope `CurrentUser` |
| JetBrainsMono Nerd Font (only without administrator rights) | `%LOCALAPPDATA%\Microsoft\Windows\Fonts`, `HKCU` |
| Windows Terminal settings | its `settings.json`, copy in `settings.json.install-linuxtools.bak` |
| Record of changes | `%LOCALAPPDATA%\Install-LinuxTools\state.json` |

Other users of the computer get none of this. Each user runs the script in
their own account and gets their own copy and settings. An administrator can
still start a program by its full path, for example
`C:\Users\<user>\scoop\apps\far\current\Far.exe`. The commands and settings
above are not set up for them.

Four exceptions are for the whole computer and need administrator rights.
They are the Visual C++ 2015–2022 runtime, the Npcap driver, the `mtr`
firewall rules, and the Nerd Fonts with their console list entry.
`-Uninstall` keeps the first two and removes the rest.

## Update and removal

`-Update` updates Scoop, every tool the script installed, the Far plugins and
theme, and installs tools that were added to the script later.

`-Uninstall` removes only what the script added:

- its packages;
- Scoop, if the script installed it and no other package is left in it;
- the PowerShell profile block, the cmd macros and the PowerShell modules it installed;
- clink, its start with cmd, its settings and history (`%LOCALAPPDATA%\clink`);
- the colors, the Far settings, plugins and desktop shortcuts;
- the firewall rules for `mtr`;
- the Nerd Font and the Scoop bucket `nerd-fonts`, if the script added it;
- the Windows Terminal settings: the copy goes back;
- the execution policy change.

`-Uninstall -WithFar` removes only Far: the package, its plugins, theme,
settings, desktop shortcuts and the `far` folder hand-over. `-Uninstall
-WithNmap` removes only nmap and the `nc` shim. `-Uninstall -WithClink`
removes clink completely: the package, its start with cmd, its keys in
`.inputrc`, its settings and history. A clink that was there before the
script stays. The settings and history are first copied to
`backup\clink_<date-time>` next to the script (to `%TEMP%` if that folder is
read-only). The history can hold passwords typed in commands, so `backup\` is
in `.gitignore`. To get them back, run the
script with `-WithFar` or `-WithNmap` again.

Before it changes anything, `-Uninstall` checks for a running Far and for
cmd windows with clink. They hold files, so the script stops and asks you to
close them. Run it from PowerShell. That PowerShell window holds PSReadLine
and PSFzf itself; they are removed when you close the window.

Full `-Uninstall` keeps:

- **git**: your repositories may need it. Remove it with `scoop uninstall git`.
- **Visual C++ and Npcap**: other programs may need them.

## Requirements

Windows 10 or 11 and Windows PowerShell 5.1 (built in). Internet access to
GitHub, Scoop and Microsoft. Installing Visual C++ and Npcap, the Nerd
Fonts for all users and the firewall rules for `mtr` ask for administrator
rights.

At the start of an install or `-Update` the script shows a window about these
rights, unless the window it runs in already has them:

- UAC is on: Windows will ask for the rights. A standard user needs an
  administrator's password there.
- UAC is off, and the user is not an administrator: Windows cannot give the
  rights at all, so the script skips these steps and lists them at the end.

OK continues, Cancel stops without changes. An administrator with UAC off
sees no window.

Tested on two machines. On Windows 11, under an account without
administrator rights, these work:

- install with every option, `-Update`, `-Uninstall` and `-Uninstall` of
  each add-on;
- the `Far4Pwsh` and `Far4CMD` shortcuts;
- grey hints in PowerShell and in cmd with clink, posh-git, fzf, oh-my-posh;
- `mtr`, `nmap` and `nping` through gsudo;
- the `far` folder hand-over in PowerShell and cmd.

## License

[MIT](LICENSE)
