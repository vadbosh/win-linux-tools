<#
.SYNOPSIS
    Separate Linux command-line tools for Windows 10/11, installed with Scoop:
    install, update, and full removal. No winget, no BusyBox.

.DESCRIPTION
    What is installed, and where it comes from:

      Commands                        Scoop package         Source
      ------------------------------  --------------------  --------------------------------
      ls cat head tail wc cut sort    uutils-coreutils      github.com/uutils/coreutils
      uniq tr tee du cp mv rm ... 89                        (Rust, GNU-compatible options)
      find xargs                      uutils-findutils      github.com/uutils/findutils
      grep egrep fgrep                grep                  GNU grep
      awk gawk                        gawk                  GNU awk
      sed                             sed                   GNU sed
      less                            less                  github.com/jftuga/less-Windows
      jq                              jq                    github.com/jqlang/jq
      rg                              ripgrep               github.com/BurntSushi/ripgrep
      fd                              fd                    github.com/sharkdp/fd
      ugrep ug                        ugrep                 github.com/Genivia/ugrep
      bat  (cat with highlighting)    bat                   github.com/sharkdp/bat
      eza  exa  (ls)                  eza                   github.com/eza-community/eza
      dust  gdu  (du)  duf (df)       dust, gdu, duf        github.com/bootandy/dust, dundee/gdu, muesli/duf
      btm  (top)  procs  (ps)         bottom, procs         github.com/ClementTsang/bottom, dalance/procs
      gsudo  (sudo)                   gsudo                 github.com/gerardog/gsudo
      xh  xhs  (HTTP requests)        xh                    github.com/ducaale/xh
      curl                            curl                  curl.se (Windows' own curl.exe stays)
      wget                            wget                  eternallybored.org/misc/wget (+ cacert)
      lsd  (ll = lsd -lha ...)        lsd                   github.com/lsd-rs/lsd
      far              (-WithFar)     far                   farmanager.com; with ArcLite, FarColorer
        Far plugin NetBox (SFTP...)   -                     github.com/michaellukashov/Far-NetBox
        Far plugin IntChecker2        -                     github.com/lazyhamster/IntChecker
        Far theme FarDark-2026        -                     github.com/Phoenix-/theming-far
        (with FarColorer scheme)
      which                           which                 GnuWin32 which
      dig host                        bind                  ISC BIND 9.16 (the last one for Windows)
      trip  (= mtr)                   trippy                github.com/fujiapple852/trippy
      whois                           whois (own manifest)  github.com/likexian/whois
      nmap ncat (= nc) (-WithNmap)    nmap                  nmap.org; needs the Npcap driver
      tree                            -                     already in Windows (tree.com)

    The script reads from the programs which Visual C++ runtime they need,
    and installs Microsoft Visual C++ 2015-2022 of that architecture from
    Microsoft, after it checks the signature. It does this right after it
    installs each package. mtr, nc and ll are Scoop shims that run trip,
    ncat and lsd -lha --group-directories-first --date "+%F %R:%S"
    --icon never - in PowerShell and cmd, also without -LinuxFirst. For nmap it opens the Npcap
    installer. At the end it lists, step by step, what it could not install.
    Without Visual C++ 2015-2022 x64 most tools do not start. If the script
    cannot install it, it stops before it changes anything else.

    Each run writes its full output to a log next to the script:
    Install-LinuxTools_<date-time>.log.

    The script records what it changes in
    %LOCALAPPDATA%\Install-LinuxTools\state.json. -Uninstall uses that file
    and removes only what the script added: its packages except git, the
    shims mtr, nc, ll, Scoop (if the script installed it and Scoop has no
    other packages), the PowerShell profile blocks, its part of the cmd
    AutoRun, LS_COLORS and EZA_COLORS, the lsd config.yaml, and the
    execution policy change. In Far it removes its plugins NetBox and
    IntChecker2, the FarColorer scheme and the far folder macro, and puts
    back the Far settings, theme and FarColorer style it saved before the
    change. System components that the script installed stay: Visual C++
    and Npcap. Other programs can need them. git stays too: it can be in use
    for your own repositories (remove it with: scoop uninstall git).

.PARAMETER LinuxFirst
    Also make the Linux names win: ls, cat, find, sort, rm, curl, wget... open the Linux
    tools in PowerShell (profile) and in cmd (doskey macros, loaded by
    AutoRun; with clink they work after | and & too).

.PARAMETER WithFar
    Also install Far Manager with its plugins, theme and settings. Without it
    Far is not installed. Run the script with -WithFar at any time to add Far;
    the other options do not need to be repeated.

.PARAMETER WithNmap
    Also install nmap and ncat (nc), with the Npcap driver. Without it nmap is
    not installed. Like -WithFar, it can be added at any time.

.PARAMETER Update
    Update Scoop and everything installed, and install the tools that were
    added to this script later. Far and nmap are updated if they are
    installed; -Update does not add them.

.PARAMETER Uninstall
    Remove everything that this script added.

.PARAMETER Help
    Show a short help. --help, -h and /? do the same.

.PARAMETER Rest
    Not an option. It catches --help, /? and unknown arguments, so that the
    script can show the help instead of an error.

.EXAMPLE
    .\Install-LinuxTools.ps1 -LinuxFirst
.EXAMPLE
    .\Install-LinuxTools.ps1 -Update
.EXAMPLE
    .\Install-LinuxTools.ps1 -Uninstall
#>

[CmdletBinding(DefaultParameterSetName = 'Install')]
param(
    [Parameter(ParameterSetName = 'Install')] [switch] $LinuxFirst,
    # С -Uninstall: удалить только Far и/или nmap
    [Parameter(ParameterSetName = 'Install')] [Parameter(ParameterSetName = 'Uninstall')] [switch] $WithFar,
    [Parameter(ParameterSetName = 'Install')] [Parameter(ParameterSetName = 'Uninstall')] [switch] $WithNmap,
    [Parameter(ParameterSetName = 'Install')] [Parameter(ParameterSetName = 'Uninstall')] [switch] $WithClink,
    [Parameter(ParameterSetName = 'Update', Mandatory = $true)] [switch] $Update,
    [Parameter(ParameterSetName = 'Uninstall', Mandatory = $true)] [switch] $Uninstall,
    # без набора параметров: справка выводится и вместе с любым режимом
    [switch] $Help,
    # --help, /? и всё остальное, чего PowerShell не узнал как ключ
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)] [string[]] $Rest
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
# Windows PowerShell 5.1 по умолчанию может не предлагать TLS 1.2 - GitHub и
# Microsoft без него не отвечают
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

# --- справка -------------------------------------------------------------------
function Show-Usage {
    # Справка кусками разного цвета: блок про -LinuxFirst выделен, потому что
    # без него ls, rm, find, curl... в PowerShell и cmd - не Linux-утилиты
    $c = 'Cyan'; $y = 'Yellow'; $g = 'Green'
    Write-Host 'Install-LinuxTools.ps1 - separate Linux command-line tools for Windows 10/11, installed with Scoop' -ForegroundColor $c
    Write-Host @'

Usage in PowerShell:
    .\Install-LinuxTools.ps1 [option]
If running scripts is blocked, or in cmd:
    powershell -ExecutionPolicy Bypass -File .\Install-LinuxTools.ps1 [option]

Options:
  (none)         Install the tools. Tools that are already installed stay as they are.
'@
    Write-Host '  -LinuxFirst    Install, and make the Linux names win (see below).' -ForegroundColor $y
    Write-Host @'
  -WithFar       Also install Far Manager with its plugins and theme.
  -WithNmap      Also install nmap and ncat (nc) with the Npcap driver.
  -WithClink     Also install clink: bash-like editing in cmd, grey hints
                 from history (Right arrow accepts), Up/Down search history
                 by the typed start, Tab cycles matches, macros after | and &.
                 Without these two options Far and nmap are not installed.
                 Add either one at any time, for example:
                   .\Install-LinuxTools.ps1 -WithFar
                 Nothing installed earlier is removed, and the other options
                 do not need to be repeated.
  -Update        Update Scoop and the tools that this script installed, and install
                 the tools that were added to this script later.
  -Uninstall     Remove everything that this script added. git stays:
                 remove it with  scoop uninstall git
  -Uninstall -WithFar, -Uninstall -WithNmap, -Uninstall -WithClink
                 Remove only Far (with its plugins, theme and settings),
                 only nmap or only clink. Everything else stays.
  -Help, --help  Show this help.
'@
    Write-Host "`nDO YOU NEED -LinuxFirst?" -ForegroundColor $y
    Write-Host @'
  Without it, some names do NOT open the Linux tools:
  - PowerShell: ls cat cp mv rm sort tee echo kill pwd sleep curl wget are
    PowerShell's own aliases. "ls -la" fails, "rm -rf dir" does not work.
  - PowerShell and cmd: find sort whoami hostname timeout more curl are
    Windows programs: the system PATH comes before Scoop.
  With -LinuxFirst these names open the Linux tools: PowerShell gets a block
  in its profile, cmd gets doskey macros (with clink also after | and &).
  PowerShell also gets grey hints from history (Right arrow accepts), git
  branch and changes in the prompt (posh-git), Ctrl+R fuzzy history and
  Ctrl+T file search (fzf, PSFzf): the script installs fzf from Scoop and
  PSReadLine, posh-git, PSFzf from PSGallery for that. cmd without
  clink has no such hints: F8 completes from history, F7 lists it.
  Scripts (.ps1) do not load the profile and are not affected.
  -Uninstall removes both.
'@
    Write-Host '  Use it if you type Linux commands by hand:  .\Install-LinuxTools.ps1 -LinuxFirst' -ForegroundColor $g
    Write-Host @'

If the tools need the Visual C++ runtime or the Npcap driver, the script
installs them. At the end it lists, step by step, what it could not do.

Tools: ls cat head tail wc cut sort uniq tr tee du... (uutils-coreutils),
find xargs, grep, awk, sed, less, jq, which, rg (ripgrep), ugrep (ug), fd,
lsd, eza (exa), bat, dust, gdu, duf, btm (bottom), procs, gsudo, dig host,
trip, xh, curl, wget, whois. Windows' own curl.exe stays; with -LinuxFirst
the name curl opens the new one.
Add-ons: -WithNmap - nmap ncat; -WithFar - Far Manager with the NetBox and
IntChecker2 plugins, the dark FarDark-2026 theme and its editor colors (the
script also turns on VT rendering and the FarColorer TrueMod style).
Short names, in PowerShell and cmd, also without -LinuxFirst:
  mtr  runs trip through gsudo (asks for admin rights)     nc  runs ncat
  nmap, nping (with -WithNmap) also run through gsudo
  far  (with -WithFar) opens in the current folder, and when you quit it the
       shell stays in the folder Far was in - like mc (PowerShell and cmd).
       Backspace in a Far panel (empty command line) goes one folder up.
       The desktop also gets two shortcuts, Far4Pwsh and Far4CMD: they open
       PowerShell or cmd and run far, so after you quit Far the window stays
       open in the folder Far was in.
  ll   runs lsd -lha --group-directories-first --date "+%F %R:%S" --icon never
File colors in ll, eza, ls, fd: LS_COLORS and EZA_COLORS (readable folders
and file types), set for your user unless you already have your own.
Full table with sources:  Get-Help .\Install-LinuxTools.ps1 -Full

Log of each run, next to the script:  Install-LinuxTools_<date-time>.log
What the script added:                %LOCALAPPDATA%\Install-LinuxTools\state.json
'@
}

if ($Help -or $Rest) {
    $helpWords = @('--help', '-help', '--h', '-h', '/?', '/h', '/help', '-?', '?', 'help')
    $unknown = @($Rest | Where-Object { $_ -and $helpWords -notcontains $_ })
    if ($unknown.Count) { Write-Host "Unknown argument: $($unknown -join ' ')`n" -ForegroundColor Red }
    Show-Usage
    exit $(if ($unknown.Count) { 1 } else { 0 })
}

$Home2     = Join-Path $env:LOCALAPPDATA 'Install-LinuxTools'
$StateFile = Join-Path $Home2 'state.json'
$WhoisJson = Join-Path $Home2 'whois.json'
$MacroFile = Join-Path $Home2 'cmd-macros.txt'
$ScoopRoot = if ($env:SCOOP) { $env:SCOOP } else { Join-Path $env:USERPROFILE 'scoop' }
$ShimDir   = Join-Path $ScoopRoot 'shims'
$LogFile   = Join-Path $PSScriptRoot ('Install-LinuxTools_{0}.log' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
$Begin     = '# >>> Install-LinuxTools: Linux commands first >>>'
$End       = '# <<< Install-LinuxTools <<<'
$CmdKey    = 'HKCU:\Software\Microsoft\Command Processor'
$Docs      = [Environment]::GetFolderPath('MyDocuments')
# Профили обеих PowerShell: Windows PowerShell 5.1 и PowerShell 7
$Profiles  = @((Join-Path $Docs 'WindowsPowerShell\profile.ps1'), (Join-Path $Docs 'PowerShell\profile.ps1'))
$VcPage    = 'https://learn.microsoft.com/cpp/windows/latest-supported-vc-redist'

# Имена, которые в PowerShell заняты псевдонимами, а в cmd - программами
# Windows или встроенными командами; при -LinuxFirst они ведут на Linux-утилиты
# curl и wget в PowerShell 5.1 - псевдонимы Invoke-WebRequest; curl.exe есть и в
# System32 (владелец TrustedInstaller): его скрипт не трогает, только имя ведёт
# на curl из Scoop
$PsNames  = @('ls', 'cat', 'cp', 'mv', 'rm', 'rmdir', 'mkdir', 'sort', 'tee', 'echo', 'kill', 'pwd',
              'find', 'whoami', 'hostname', 'timeout', 'more', 'sleep', 'curl', 'wget')
$CmdNames = @('find', 'sort', 'whoami', 'hostname', 'timeout', 'more', 'mkdir', 'rmdir', 'curl')

# Что проверяется в конце, с каким ключом версии и из какого пакета Scoop
$Checks = [ordered]@{
    ls = '--version'; cat = '--version'; wc = '--version'; sort = '--version'; find = '--version'
    xargs = '--version'; grep = '--version'; awk = '--version'; sed = '--version'; less = '--version'
    rg = '--version'; fd = '--version'; lsd = '--version'; ll = '--version'
    ugrep = '--version'; bat = '--version'; eza = '--version'; dust = '--version'; gdu = '--version'; duf = '--version'
    btm = '--version'; procs = '--version'; xh = '--version'; sudo = '--version'
    curl = '--version'; wget = '--version'
    jq = '--version'; which = '--version'; dig = '-v'; trip = '--version'; whois = '--version'
    nmap = '--version'; ncat = '--version'; mtr = '--version'; nc = '--version'
}
$ToolPkg = @{
    ls = 'uutils-coreutils'; cat = 'uutils-coreutils'; wc = 'uutils-coreutils'; sort = 'uutils-coreutils'
    find = 'uutils-findutils'; xargs = 'uutils-findutils'; grep = 'grep'; awk = 'gawk'; sed = 'sed'
    less = 'less'; jq = 'jq'; which = 'which'; dig = 'bind'; trip = 'trippy'; whois = 'whois'
    rg = 'ripgrep'; fd = 'fd'; lsd = 'lsd'; ll = 'lsd'; far = 'far'
    ugrep = 'ugrep'; bat = 'bat'; eza = 'eza'; dust = 'dust'; gdu = 'gdu'; duf = 'duf'
    btm = 'bottom'; procs = 'procs'; xh = 'xh'; sudo = 'gsudo'   # gsudo даёт ярлык Scoop с именем sudo
    curl = 'curl'; wget = 'wget'
    nmap = 'nmap'; ncat = 'nmap'; mtr = 'trippy'; nc = 'nmap'
}
# Короткие имена-ярлыки Scoop: имя -> утилита
# Args - строка ключей, которую ярлык подставляет перед ключами пользователя
$Aliases = [ordered]@{
    mtr = @{ Tool = 'trip'; Args = ''; Elevate = $true }
    nc  = @{ Tool = 'ncat'; Args = '' }
    ll  = @{ Tool = 'lsd';  Args = '-lha --group-directories-first --date "+%F %R:%S" --icon never' }
}
# Ярлыки пакетов, которым без прав администратора не работать (raw-сокеты):
# скрипт пускает их через gsudo - только если пакет поставил он сам
$ElevateShims = [ordered]@{ nmap = 'nmap'; nping = 'nmap' }
# Ярлык far - с путём ".": Far открывается в текущей папке, как mc в Linux.
# Без пути Far открывает папки, где закрылся в прошлый раз (они сохраняются с
# настройками). Командная строка Far: far [ключи] [путь_активной [путь_пассивной]]
$AllPkgs = @('uutils-coreutils', 'uutils-findutils', 'grep', 'gawk', 'sed', 'less', 'jq', 'which', 'ripgrep', 'fd', 'lsd',
             'ugrep', 'bat', 'eza', 'dust', 'gdu', 'duf', 'bottom', 'procs', 'gsudo',
             'far', 'bind', 'trippy', 'xh', 'curl', 'wget', 'whois', 'nmap', 'clink', 'fzf')

# Far Manager: плагины с GitHub - последний релиз, файл x64, SHA-256 из поля
# digest в GitHub API. ArcLite и FarColorer уже входят в сам Far.
$FarPlugins = @(
    @{ Name = 'NetBox';      Repo = 'michaellukashov/Far-NetBox'; Asset = '^NetBox\.x64\.[\d.]+\.7z$' }
    @{ Name = 'IntChecker2'; Repo = 'lazyhamster/IntChecker';     Asset = '^IntChecker2_Far3_x64_[\d.]+\.7z$' }
)
# Тема FarDark-2026 (github.com/Phoenix-/theming-far, MIT): файлы закреплены
# на коммите, проверка - git blob SHA-1 из GitHub API (проверено 2026-10-30)
$FarTheme = @{
    Name  = 'FarDark-2026'
    Base  = 'https://raw.githubusercontent.com/Phoenix-/theming-far/f0bb86da98905119a884ead8453542a97e932cae'
    Files = [ordered]@{
        'themes/FarDark-2026/FarDark2026.farconfig'  = 'e91b0bfcaecbc2c8e565ef9b9a1353b963739a72'
        'themes/FarDark-2026/Highlighting.farconfig' = 'b5b4bd529f69ccd9a4a42a164b58cabccd1558c3'
    }
    # Подсветка синтаксиса в редакторе (F4): схема для FarColorer
    Colorer = @{ Path = 'themes/FarDark-2026/Colorer.hrd'; Sha = '385336d7b4ab845f16fe0cd4cbe2455238f0390d'; Scheme = 'FarDark2026' }
}
# Подсветка текущей строки (крест FarColorer) - элемент def:HorzCross схемы.
# В схеме темы #2A2A2A на фоне редактора #1F1F1F - на части мониторов не видно.
# Цвет в .hrd - обычный #RRGGBB (порядок BGR тут не нужен).
$ColorerCrossBack = '#3A3D41'
$ColorerBegin = '<!-- Install-LinuxTools:begin -->'
$ColorerEnd   = '<!-- Install-LinuxTools:end -->'
# Свои цвета поверх темы: ключ цвета Far -> Back (фон) и/или Text (текст),
# #RRGGBB; в Far уходят в его порядке (BGR). Ключа нет в теме - он
# добавляется. Имена ключей - far/palette.cpp.
#   Panel.Cursor(.Selected) - курсор на панели: в теме #2A2A2A, почти не виден;
#                        #3A3D41 тоже оказался тускловат на части мониторов
#   Editor.LineNumbers - номера строк: в теме нет, Far рисует серым по синему
#   Editor.Status      - верхняя строка редактора (путь, Col, Ch): в теме
#                        акцентный синий #0078D4
$FarColorOverrides = [ordered]@{
    'Panel.Cursor'          = @{ Back = '#4B5263' }
    'Panel.Cursor.Selected' = @{ Back = '#4B5263' }
    'Editor.LineNumbers'    = @{ Back = '#275A65'; Text = '#CCCCCC' }
    'Editor.Status'         = @{ Back = '#124B55' }
}
# Ревизия того, что скрипт делает с темой. Тема с ревизией меньше этой
# импортируется заново один раз: 1 - цвета в порядке BGR, 2 - курсор ярче,
# 3 - цвет номеров строк, 4 - верхняя строка редактора, 5 - курсор ещё ярче.
$FarThemeRev = 5
$FarMarker = '.install-linuxtools'   # файл в папке плагина: её положил этот скрипт, в нём версия

# Библиотеки Visual C++ по имени DLL. 2015-2022 скрипт ставит сам с прямой
# ссылки Microsoft; у старых прямых ссылок нет - только страница загрузки.
# Ссылки - со страницы $VcPage (проверено 2026-10-29).
$Redists = @(
    @{ Re = '^(vcruntime140(_1)?|msvcp140(_\w+)?|concrt140|vccorlib140|vcomp140)\.dll$'; Name = 'Microsoft Visual C++ 2015-2022'; Auto = $true }
    @{ Re = '^msv(cr|cp)120\.dll$'; Name = 'Microsoft Visual C++ 2013'; Page = 'https://support.microsoft.com/topic/update-for-visual-c-2013-redistributable-package-d8ccd6a5-4e26-c290-517b-8da6cfdf4f10' }
    @{ Re = '^msv(cr|cp)110\.dll$'; Name = 'Microsoft Visual C++ 2012 Update 4'; Page = 'https://www.microsoft.com/download/details.aspx?id=30679' }
    @{ Re = '^msv(cr|cp)100\.dll$'; Name = 'Microsoft Visual C++ 2010 SP1'; Page = 'https://www.microsoft.com/download/details.aspx?id=26999' }
    @{ Re = '^msv(cr|cp)90\.dll$';  Name = 'Microsoft Visual C++ 2008 SP1'; Page = 'https://www.microsoft.com/download/details.aspx?id=26368' }
)

# --- вывод: лог, предупреждения, шаги руками, итог ---------------------------
# Предупреждения видны по ходу и ещё раз в конце, каждое один раз. Шаги
# руками копятся молча и выводятся только в итоге - по порядку, с командой.
$script:Warnings = New-Object System.Collections.Generic.List[string]
$script:Steps    = New-Object System.Collections.Generic.List[object]
$script:Notes    = New-Object System.Collections.Generic.List[string]
$script:LogUsed  = $null
$script:Changed  = $false      # PATH или профиль поменялись - нужно новое окно
$script:Fixed    = @{}         # утилита -> что для неё поставлено автоматически
$script:FarDone  = @()         # что поставлено в Far - для итога
$script:VcFailed = @()         # разрядности Visual C++, которые поставить не вышло - второй раз не пробовать

function Say  { param([string] $Text) Write-Host "`n$Text" -ForegroundColor Cyan }
function Ok   { param([string] $Text) Write-Host "  OK   $Text" -ForegroundColor Green }
function Warn {
    param([string] $Text)
    Write-Host "  !!   $Text" -ForegroundColor Yellow
    if (-not $script:Warnings.Contains($Text)) { $script:Warnings.Add($Text) }
}
# Шаг руками. $Order - место в списке: 10 библиотеки, 20 драйвер, 80
# перепроверка, 90 новое окно. Одинаковый заголовок второй раз не добавляется.
function Add-Step {
    param([int] $Order, [string] $Title, [string[]] $Lines = @())
    if (@($script:Steps | Where-Object { $_.Title -eq $Title }).Count) { return }
    $script:Steps.Add([PSCustomObject]@{ Order = $Order; Title = $Title; Lines = $Lines })
}
function Add-Note { param([string] $Text) if (-not $script:Notes.Contains($Text)) { $script:Notes.Add($Text) } }

# Лог - рядом со скриптом; папка только для чтения - в %TEMP%
function Start-Log {
    foreach ($f in @($LogFile, (Join-Path $env:TEMP (Split-Path -Leaf $LogFile)))) {
        try { Start-Transcript -LiteralPath $f -ErrorAction Stop | Out-Null; $script:LogUsed = $f; break } catch { }
    }
    if (-not $script:LogUsed) { Warn 'Could not write a log file, neither next to the script nor in %TEMP%.' }
    elseif ($script:LogUsed -ne $LogFile) { Warn "The script folder is not writable - log is in $script:LogUsed" }
}

# Итог. $Sections - список @{ Title; Items; Color; Tail }; пустые не печатаются
function Finish {
    param([int] $Code = 0, [object[]] $Sections = @(), [object[]] $Installed = @())
    Write-Host "`n======================== SUMMARY ========================" -ForegroundColor Cyan
    foreach ($s in $Sections) {
        $items = @($s.Items | Where-Object { $_ })
        if ($items.Count) { Write-Host ("{0} ({1}): {2}{3}" -f $s.Title, $items.Count, ($items -join ', '), $s.Tail) -ForegroundColor $s.Color }
    }
    # Полный список команд - когда установка прошла без ошибок
    if ($Installed.Count) {
        Write-Host "`nInstalled commands, by Scoop package:" -ForegroundColor Green
        foreach ($i in $Installed) {
            $line = "  $($i.Package):"; $pad = ' ' * 6
            foreach ($c in $i.Commands) {
                if (($line.Length + $c.Length + 1) -gt 100) { Write-Host $line; $line = $pad + $c }
                else { $line += " $c" }
            }
            Write-Host $line
        }
    }
    # Перепроверка нужна, только если остались шаги про библиотеки или драйвер
    if (@($script:Steps | Where-Object { $_.Order -lt 80 }).Count -and $Code -eq 0) {
        Add-Step 80 'When the steps above are done, check again:' @('.\Install-LinuxTools.ps1 -Update')
    }
    if ($script:Steps.Count) {
        Write-Host "`nTO DO BY HAND, in this order:" -ForegroundColor Magenta
        $i = 0
        foreach ($s in @($script:Steps | Sort-Object Order)) {
            $i++; Write-Host "  $i. $($s.Title)" -ForegroundColor Magenta
            foreach ($l in $s.Lines) { Write-Host "       $l" }
        }
    } else { Write-Host "`nNothing to do by hand." -ForegroundColor Green }
    if ($script:Notes.Count) {
        Write-Host "`nRemember:" -ForegroundColor Cyan
        foreach ($n in $script:Notes) { Write-Host "  $n" }
    }
    if ($script:Warnings.Count) {
        Write-Host "`nWarnings ($($script:Warnings.Count)):" -ForegroundColor Yellow
        foreach ($w in $script:Warnings) { Write-Host "  !!   $w" -ForegroundColor Yellow }
    }
    if ($script:LogUsed) {
        Write-Host "`nLog: $script:LogUsed"
        try { Stop-Transcript | Out-Null } catch { }
    }
    exit $Code
}

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    return ([Security.Principal.WindowsPrincipal]$id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
# PATH этого окна - заново из реестра: Scoop пишет его в реестр
function Update-SessionPath {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path', 'User')
}
# Запуск установщика: из окна администратора - сразу, иначе через UAC.
# Отказ в окне UAC - исключение; тогда $null
function Start-Elevated {
    param([string] $File, [string[]] $Arguments = @())
    $a = @{ FilePath = $File; Wait = $true; PassThru = $true }
    if ($Arguments.Count) { $a.ArgumentList = $Arguments }
    if (-not (Test-Admin)) { $a.Verb = 'RunAs' }
    try { return (Start-Process @a) } catch { Warn "$(Split-Path -Leaf $File) did not start: $($_.Exception.Message)"; return $null }
}
function Test-Signature {
    param([string] $File, [string] $Publisher)
    $sig = Get-AuthenticodeSignature -LiteralPath $File
    if ($sig.Status -eq 'Valid' -and $sig.SignerCertificate.Subject -match $Publisher) { return $true }
    Warn "$(Split-Path -Leaf $File): signature $($sig.Status), signer '$($sig.SignerCertificate.Subject)' - expected $Publisher; not started"
    return $false
}

# --- DLL: какие нужны программе и каких нет -----------------------------------
# Системная папка для программы данной разрядности. 32-битная PowerShell
# видит вместо System32 папку SysWOW64 - тогда Sysnative.
function Get-SysDir {
    param([string] $Arch)
    $os64 = [Environment]::Is64BitOperatingSystem
    if ($Arch -eq 'x86' -and $os64) { return (Join-Path $env:SystemRoot 'SysWOW64') }
    if ($os64 -and -not [Environment]::Is64BitProcess) { return (Join-Path $env:SystemRoot 'Sysnative') }
    return (Join-Path $env:SystemRoot 'System32')
}
function Test-VcRuntime { param([string] $Arch) return (Test-Path -LiteralPath (Join-Path (Get-SysDir $Arch) 'vcruntime140.dll')) }

# Разрядность и таблица импорта PE-файла (.exe/.dll): какие DLL он грузит
function Get-PeImports {
    param([string] $Path)
    $b = [IO.File]::ReadAllBytes($Path)
    $pe = [BitConverter]::ToInt32($b, 0x3C)
    if ($pe -le 0 -or $pe + 24 -gt $b.Length -or [BitConverter]::ToUInt32($b, $pe) -ne 0x4550) { return $null }
    $machine = [BitConverter]::ToUInt16($b, $pe + 4)
    $nSec    = [BitConverter]::ToUInt16($b, $pe + 6)
    $optSize = [BitConverter]::ToUInt16($b, $pe + 20)
    $opt     = $pe + 24
    $dirs    = $opt + $(if ([BitConverter]::ToUInt16($b, $opt) -eq 0x20b) { 112 } else { 96 })
    $sec     = $opt + $optSize
    $toOff = {
        param([uint32] $Rva)
        for ($i = 0; $i -lt $nSec; $i++) {
            $s = $sec + 40 * $i
            $va = [BitConverter]::ToUInt32($b, $s + 12)
            $size = [Math]::Max([BitConverter]::ToUInt32($b, $s + 8), [BitConverter]::ToUInt32($b, $s + 16))
            if ($Rva -ge $va -and $Rva -lt $va + $size) { return [int]($Rva - $va + [BitConverter]::ToUInt32($b, $s + 20)) }
        }
        return -1
    }
    $dlls = @()
    $impRva = [BitConverter]::ToUInt32($b, $dirs + 8)
    if ($impRva) {
        $o = & $toOff $impRva
        while ($o -ge 0 -and $o + 20 -le $b.Length) {
            $nameRva = [BitConverter]::ToUInt32($b, $o + 12)
            if (-not $nameRva) { break }
            $n = & $toOff $nameRva
            if ($n -lt 0) { break }
            $e = [Array]::IndexOf($b, [byte]0, $n)
            $dlls += [Text.Encoding]::ASCII.GetString($b, $n, $e - $n)
            $o += 20
        }
    }
    $arch = switch ($machine) { 0x14c { 'x86' } 0x8664 { 'x64' } 0xAA64 { 'arm64' } default { 'unknown' } }
    return [PSCustomObject]@{ Arch = $arch; Dlls = $dlls }
}
# Есть ли DLL там, где её ищет Windows: папка программы, системная папка
# нужной разрядности, папка Windows, PATH (кроме системных - их разрядность
# уже учтена). api-ms-win-* - не файлы, а наборы функций Windows.
# Visual C++ 2005/2008 лежат не в System32, а в WinSxS.
function Test-Dll {
    param([string] $Name, [string] $Arch, [string] $ExeDir)
    if ($Name -match '^(api|ext)-ms-') { return $true }
    $where = @($ExeDir, (Get-SysDir $Arch), $env:SystemRoot) +
             @($env:Path -split ';' | Where-Object { $_ -and $_ -notlike "$env:SystemRoot*" })
    foreach ($d in $where) { if (Test-Path -LiteralPath (Join-Path $d $Name)) { return $true } }
    if ($Name -match '^msv(cr|cp)(80|90)\.dll$') {
        $a = if ($Arch -eq 'x86') { 'x86' } else { 'amd64' }
        if (Get-ChildItem -Path (Join-Path $env:SystemRoot 'WinSxS') -Filter "${a}_microsoft.vc$($Matches[2]).crt_*" -Directory -ErrorAction SilentlyContinue) { return $true }
    }
    return $false
}
# Каких DLL не хватает программе - и DLL из её папки, которые грузятся вместе с ней
function Get-MissingDlls {
    param([string] $Exe)
    $dir = Split-Path -Parent $Exe
    $info = Get-PeImports $Exe
    if (-not $info) { return $null }
    $missing = @(); $seen = @{}; $queue = @($Exe)
    while ($queue.Count) {
        $f = $queue[0]; $queue = @($queue | Select-Object -Skip 1)
        $pe = Get-PeImports $f
        if (-not $pe) { continue }
        foreach ($d in $pe.Dlls) {
            $k = $d.ToLower()
            if ($seen[$k]) { continue }
            $seen[$k] = $true
            if (-not (Test-Dll $d $info.Arch $dir)) { $missing += $k }
            elseif (Test-Path -LiteralPath (Join-Path $dir $d)) { $queue += (Join-Path $dir $d) }
        }
    }
    return [PSCustomObject]@{ Arch = $info.Arch; Missing = $missing }
}
# Настоящий .exe за ярлыком Scoop: shims\<name>.shim, строка path = "..."
# Ярлык, пущенный через gsudo (path = gsudo.exe, args = "<программа>" …),
# возвращает настоящую программу - для проверки DLL и версии
function Get-ShimTarget {
    param([string] $Name)
    $shim = Join-Path $ShimDir "$Name.shim"
    if (-not (Test-Path -LiteralPath $shim)) { return $null }
    $text = Get-Content -LiteralPath $shim -Raw
    $m = [regex]::Match($text, 'path\s*=\s*"?([^"\r\n]+)"?')
    if (-not $m.Success) { return $null }
    $path = $m.Groups[1].Value.Trim()
    if ((Split-Path -Leaf $path) -ieq 'gsudo.exe') {
        $a = [regex]::Match($text, 'args\s*=\s*"([^"]+)"')
        if ($a.Success) { return $a.Groups[1].Value }
    }
    return $path
}
function Test-ShimElevated {
    param([string] $Name)
    $shim = Join-Path $ShimDir "$Name.shim"
    return ((Test-Path -LiteralPath $shim) -and (Get-Content -LiteralPath $shim -Raw) -match 'gsudo\.exe')
}
# Настоящий gsudo.exe: у пакета gsudo ярлык Scoop называется sudo
function Get-GsudoExe {
    $t = Get-ShimTarget 'sudo'
    if ($t -and (Split-Path -Leaf $t) -ieq 'gsudo.exe' -and (Test-Path -LiteralPath $t)) { return $t }
    $p = Join-Path $ScoopRoot 'apps\gsudo\current\gsudo.exe'
    if (Test-Path -LiteralPath $p) { return $p }
    return $null
}
# .shim: path и args. С gsudo - path = gsudo.exe, программа первой в args
function Write-Shim {
    param([string] $Shim, [string] $Target, [string] $ArgLine, [string] $Gsudo)
    $lines = if ($Gsudo) { @("path = `"$Gsudo`"", ("args = `"$Target`" $ArgLine").TrimEnd()) }
             else { @("path = `"$Target`"") + $(if ($ArgLine) { "args = $ArgLine" } else { @() }) }
    [IO.File]::WriteAllLines($Shim, [string[]]$lines)     # UTF-8 без BOM, как пишет сам Scoop
}

# --- установка недостающего -----------------------------------------------------
# Visual C++ 2015-2022: прямая ссылка Microsoft, проверка подписи, тихая
# установка. Коды: 0 - готово, 3010 - готово, нужна перезагрузка, 1638 -
# уже стоит версия новее.
function Install-VcRedist {
    param([string] $Arch, $State)
    if (Test-VcRuntime $Arch) { return $true }
    if ($script:VcFailed -contains $Arch) { return $false }
    $script:VcFailed += $Arch     # снимается ниже, если установка удалась
    $url = "https://aka.ms/vc14/vc_redist.$Arch.exe"
    $file = Join-Path $env:TEMP "vc_redist.$Arch.exe"
    Write-Host "  ...  Visual C++ 2015-2022 ${Arch}: downloading $url"
    try { Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $file -TimeoutSec 300 }
    catch { Warn "Visual C++ 2015-2022 ${Arch}: download failed - $($_.Exception.Message)"; return $false }
    if (-not (Test-Signature $file 'O=Microsoft Corporation')) { Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue; return $false }
    Write-Host "  ...  Visual C++ 2015-2022 ${Arch}: installing (Windows may ask for administrator rights)"
    $p = Start-Elevated $file @('/install', '/quiet', '/norestart')
    Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue
    if (-not $p) { return $false }
    if ($p.ExitCode -eq 3010) { Add-Step 15 'Restart Windows: the Visual C++ installer asks for it' }
    if (@(0, 3010, 1638) -notcontains $p.ExitCode) { Warn "Visual C++ 2015-2022 ${Arch}: installer exit code $($p.ExitCode)"; return $false }
    if (-not (Test-VcRuntime $Arch)) { Warn "Visual C++ 2015-2022 ${Arch}: installer finished, but vcruntime140.dll is still missing"; return $false }
    Ok "Visual C++ 2015-2022 $Arch installed"
    $script:VcFailed = @($script:VcFailed | Where-Object { $_ -ne $Arch })
    $State.SystemInstalled = @($State.SystemInstalled) + "Visual C++ 2015-2022 $Arch"; Save-State $State
    return $true
}
function Add-VcStep {
    param([string] $Arch, [string[]] $Tools)
    $url = "https://aka.ms/vc14/vc_redist.$Arch.exe"
    Add-Step 10 "Install Microsoft Visual C++ 2015-2022 $Arch. Without it, these do not start: $($Tools -join ', ')" @(
        "Download and run:  $url",
        "Microsoft page:    $VcPage")
}

# Npcap: драйвер для nmap. Его установщик лежит в пакете nmap. Тихая установка
# есть только в платной Npcap OEM - поэтому окно установщика, кнопки - руками.
function Install-Npcap {
    param($State)
    if (Get-Service -Name npcap -ErrorAction SilentlyContinue) { Ok 'Npcap driver is installed'; return }
    $exe = Join-Path (scoop prefix nmap 6>$null) 'npcap.exe'
    $manual = @("In an administrator window:  & '$exe'", 'Or download it from https://npcap.com/#download')
    if (-not (Test-Path -LiteralPath $exe)) { Add-Step 20 'Install the Npcap driver. Without it, nmap cannot scan.' @('Download it from https://npcap.com/#download'); return }
    if (-not (Test-Signature $exe 'Nmap Software|Insecure\.Com')) { Add-Step 20 'Install the Npcap driver. Without it, nmap cannot scan.' $manual; return }
    Write-Host '  ...  Npcap: its installer opens now - press I Agree, Install, Next, Finish' -ForegroundColor Magenta
    $null = Start-Elevated $exe
    if (Get-Service -Name npcap -ErrorAction SilentlyContinue) {
        Ok 'Npcap driver installed'
        $State.SystemInstalled = @($State.SystemInstalled) + 'Npcap'; Save-State $State
    } else { Add-Step 20 'Install the Npcap driver. Without it, nmap cannot scan.' $manual }
}

# --- состояние: что добавил скрипт ------------------------------------------
function Get-State {
    $d = [ordered]@{ ScoopInstalledByUs = $false; Packages = @(); ExecPolicyBefore = $null
                     ProfileBlock = $false; CmdAutoRunSet = $false; SystemInstalled = @(); Shims = @()
                     FarTheme = $false; FarColorer = $false; FarVtBefore = $null
                     FarColorerBefore = $null; FarThemeBgr = $false; FarThemeRev = 0 }
    $s = if (Test-Path -LiteralPath $StateFile) { Get-Content -LiteralPath $StateFile -Raw | ConvertFrom-Json } else { [PSCustomObject]@{} }
    foreach ($k in $d.Keys) { if (-not $s.PSObject.Properties[$k]) { $s | Add-Member -NotePropertyName $k -NotePropertyValue $d[$k] } }
    return $s
}
function Save-State {
    param($State)
    if (-not (Test-Path $Home2)) { New-Item -ItemType Directory -Force -Path $Home2 | Out-Null }
    $State | ConvertTo-Json | Set-Content -LiteralPath $StateFile -Encoding UTF8
}

# --- Scoop -------------------------------------------------------------------
# Что стоит - по списку Scoop, а не по коду возврата: scoop - PowerShell-скрипт
function Get-ScoopInstalled { return @(scoop list 6>$null | ForEach-Object { $_.Name }) }
function Install-ScoopPackage {
    param([string] $Name, [string] $Source, $State, [switch] $NoUpdateScoop)
    if ((Get-ScoopInstalled) -contains $Name) {
        if (@($State.Packages) -contains $Name) { Ok "$Name - installed" } else { Ok "$Name - already installed (left alone on -Uninstall)" }
        Repair-PackageDlls $Name $State; return
    }
    Write-Host "  ...  $Name"
    $before = Get-ScoopInstalled
    $what = if ($Source) { $Source } else { $Name }
    if ($NoUpdateScoop) { scoop install $what --no-update-scoop } else { scoop install $what }
    $after = Get-ScoopInstalled
    if ($after -contains $Name) {
        Ok $Name; $script:Changed = $true
        # Записать и зависимости, которые Scoop поставил вместе с пакетом (7zip для far)
        foreach ($n in @($after | Where-Object { $before -notcontains $_ })) {
            if (@($State.Packages) -notcontains $n) { $State.Packages = @($State.Packages) + $n }
            if ($n -ne $Name) { Ok "$n - installed by Scoop as a dependency of $Name" }
        }
        Save-State $State
        Repair-PackageDlls $Name $State -Hints
    } else { Warn "$Name - NOT installed, see the scoop messages above or in the log" }
}
# Каких библиотек не хватает утилитам - по самим .exe, сгруппировано:
# "<Visual C++>|<arch>" или "?|<arch>" -> @{ Redist; Arch; Tools; Dlls }
function Get-DllNeeds {
    param([string[]] $Tools)
    $need = @{}
    foreach ($t in $Tools) {
        $target = Get-ShimTarget $t
        $diag = if ($target -and (Test-Path -LiteralPath $target)) { Get-MissingDlls $target } else { $null }
        if (-not $diag -or -not $diag.Missing.Count) { continue }
        foreach ($dll in $diag.Missing) {
            $rd = $Redists | Where-Object { $dll -match $_.Re } | Select-Object -First 1
            $key = if ($rd) { "$($rd.Name)|$($diag.Arch)" } else { "?|$($diag.Arch)" }
            if (-not $need[$key]) { $need[$key] = @{ Redist = $rd; Arch = $diag.Arch; Tools = @(); Dlls = @() } }
            if ($need[$key].Tools -notcontains $t) { $need[$key].Tools += $t }
            if ($need[$key].Dlls -notcontains $dll) { $need[$key].Dlls += $dll }
        }
    }
    return $need
}
# Visual C++ 2015-2022, которой не хватает утилитам, - поставить сразу
function Install-NeededVc {
    param($Need, $State)
    foreach ($x in @($Need.Values | Where-Object { $_.Redist -and $_.Redist.Auto -and $script:VcFailed -notcontains $_.Arch })) {
        Write-Host "  ..   $($x.Tools -join ', ') ($($x.Arch)): missing $($x.Dlls -join ', ')"
        if (Install-VcRedist $x.Arch $State) { foreach ($t in $x.Tools) { $script:Fixed[$t] = "Visual C++ 2015-2022 $($x.Arch)" } }
    }
}
# Сразу после установки пакета: библиотеки его утилит, и разбор подсказок
# "... suggests installing ..." - прямо под строкой Scoop, а не в конце
function Repair-PackageDlls {
    param([string] $Pkg, $State, [switch] $Hints)
    $tools = @($ToolPkg.Keys | Where-Object { $ToolPkg[$_] -eq $Pkg })
    $need = Get-DllNeeds $tools
    Install-NeededVc $need $State
    if (-not $Hints) { return }
    $mf = Join-Path $ScoopRoot "apps\$Pkg\current\manifest.json"
    if (-not (Test-Path -LiteralPath $mf)) { return }
    $sug = (Get-Content -LiteralPath $mf -Raw | ConvertFrom-Json).suggest
    if (-not $sug) { return }
    $left  = @($need.Values | ForEach-Object { $_.Tools } | Where-Object { -not $script:Fixed[$_] })
    $fixed = @($tools | Where-Object { $script:Fixed[$_] } | ForEach-Object { $script:Fixed[$_] } | Select-Object -Unique)
    foreach ($v in @($sug.PSObject.Properties | ForEach-Object { @($_.Value) })) {
        if ($v -match 'vcredist') {
            $verdict = if ($left.Count) { 'libraries are still missing - see TO DO BY HAND at the end' }
                       elseif ($fixed.Count) { "the script installed what the programs load: $($fixed -join ', ')" }
                       else { 'not needed: the libraries that the programs load are present' }
            # nmap собран в Visual C++ 2019 и требует vc_redist.x86 (nmap.org/book/inst-windows.html);
            # подсказка vcredist2008 в манифесте Scoop устарела
            if ($Pkg -eq 'nmap' -and $v -match 'vcredist2008') { $verdict = "outdated hint, nmap needs Visual C++ 2015-2022 x86 (nmap.org/book/inst-windows.html); $verdict" }
        } else { $verdict = "not needed: an optional separate program (to install it: scoop install $v)" }
        Write-Host "  --   Scoop hint '$v' for ${Pkg}: $verdict" -ForegroundColor Cyan
    }
}

# mtr, nc, ll - ярлыки Scoop на trip, ncat и lsd с ключами: работают в
# PowerShell, cmd и clink без -LinuxFirst. Чужой ярлык с тем же именем не
# трогается. Строку args скрипт пишет в .shim сам: так ключ с пробелом
# ("+%F %R:%S") доходит до программы одним аргументом, в кавычках.
function Add-AliasShims {
    param($State)
    foreach ($n in $Aliases.Keys) {
        $a = $Aliases[$n]
        $target = Get-ShimTarget $a.Tool
        if (-not $target) { continue }
        $shim = Join-Path $ShimDir "$n.shim"
        $ours = @($State.Shims) -contains $n
        if ((Test-Path -LiteralPath $shim) -and -not $ours) { Ok "$n - a shim with this name already exists, left alone"; continue }
        if (-not (Test-Path -LiteralPath $shim)) { scoop shim add $n $target 6>$null | Out-Null }
        if (-not (Test-Path -LiteralPath $shim)) { Warn "$n - could not create the shim for $($a.Tool)"; continue }
        $gs = if ($a.Elevate) { Get-GsudoExe } else { $null }
        Write-Shim $shim $target $a.Args $gs
        if (-not $ours) { $State.Shims = @($State.Shims) + $n; Save-State $State; $script:Changed = $true }
        Ok ("$n -> $(if ($gs) { 'gsudo ' })$($a.Tool) $($a.Args)").Trim()
        if ($a.Elevate -and -not $gs) { Warn "$n runs $($a.Tool) without gsudo (gsudo not found): start it in an administrator window" }
    }
    # Ярлыки пакетов (nmap, nping) - через gsudo, если пакет поставил скрипт.
    # scoop update nmap вернёт обычный ярлык; -Update скрипта повысит снова.
    $gs = Get-GsudoExe
    foreach ($n in $ElevateShims.Keys) {
        $shim = Join-Path $ShimDir "$n.shim"
        if (-not (Test-Path -LiteralPath $shim) -or @($State.Packages) -notcontains $ElevateShims[$n]) { continue }
        if (Test-ShimElevated $n) { Ok "$n -> gsudo $n"; continue }
        if (-not $gs) { Warn "$n runs without gsudo (gsudo not found): start it in an administrator window"; continue }
        $text = Get-Content -LiteralPath $shim -Raw
        $argLine = ([regex]::Match($text, 'args\s*=\s*([^\r\n]*)')).Groups[1].Value.Trim()
        Write-Shim $shim (Get-ShimTarget $n) $argLine $gs
        Ok "$n -> gsudo $n (asks for administrator rights itself)"
    }
    # far: всегда с "." - если Far поставил скрипт
    $shim = Join-Path $ShimDir 'far.shim'
    if ((Test-Path -LiteralPath $shim) -and @($State.Packages) -contains 'far') {
        if ((Get-Content -LiteralPath $shim -Raw) -match '(?m)^args\s*=\s*"\."\s*$') { Ok 'far -> opens in the current folder' }
        else { Write-Shim $shim (Get-ShimTarget 'far') '"."' $null; Ok 'far -> opens in the current folder (like mc)'; $script:Changed = $true }
    }
}

# --- Far Manager: плагины и тема -------------------------------------------------
# Папки Far из Scoop: профиль (Profile) Scoop сохраняет между обновлениями -
# туда и кладутся плагины: Far грузит и плагины из папки Plugins профиля
function Get-FarPaths {
    $dir = "$(scoop prefix far 6>$null)".Trim()
    if (-not $dir -or -not (Test-Path -LiteralPath (Join-Path $dir 'Far.exe'))) { return $null }
    return [PSCustomObject]@{ Exe = (Join-Path $dir 'Far.exe'); Plugins = (Join-Path $dir 'Profile\Plugins') }
}
function Test-FarRunning { return [bool](Get-Process -Name far -ErrorAction SilentlyContinue) }
# Far.exe -import/-export: ждать не дольше минуты
function Invoke-Far {
    param([string] $Exe, [string[]] $Arguments)
    $p = Start-Process -FilePath $Exe -ArgumentList $Arguments -PassThru -WindowStyle Hidden
    if (-not $p.WaitForExit(60000)) { try { $p.Kill() } catch { }; return -1 }
    return $p.ExitCode
}
function Expand-7z {
    param([string] $File, [string] $Dest)
    $7z = Join-Path $ShimDir '7z.exe'
    if (-not (Test-Path -LiteralPath $7z)) { return $false }
    & $7z x -y "-o$Dest" $File 2>&1 | Out-Null
    return ($LASTEXITCODE -eq 0)
}
function Get-GitBlobSha {
    param([string] $File)
    $b = [IO.File]::ReadAllBytes($File)
    $h = [Text.Encoding]::ASCII.GetBytes("blob $($b.Length)`0")
    $sha = [Security.Cryptography.SHA1]::Create()
    return (($sha.ComputeHash([byte[]]($h + $b)) | ForEach-Object { $_.ToString('x2') }) -join '')
}
# Плагин: последний релиз на GitHub, файл x64, проверка SHA-256, распаковка в
# Profile\Plugins\<имя>. Папку без метки скрипта (чужую) не трогает.
function Install-FarPlugin {
    param($Plugin, $Far)
    $dest = Join-Path $Far.Plugins $Plugin.Name
    $mark = Join-Path $dest $FarMarker
    if ((Test-Path -LiteralPath $dest) -and -not (Test-Path -LiteralPath $mark)) { Ok "Far plugin $($Plugin.Name) - already there, left alone"; return }
    try {
        $rel = Invoke-RestMethod -Uri "https://api.github.com/repos/$($Plugin.Repo)/releases/latest" -TimeoutSec 30
    } catch { Warn "Far plugin $($Plugin.Name): GitHub did not answer - $($_.Exception.Message)"; return }
    $asset = @($rel.assets | Where-Object { $_.name -match $Plugin.Asset }) | Select-Object -First 1
    if (-not $asset) { Warn "Far plugin $($Plugin.Name): no x64 file in release $($rel.tag_name)"; return }
    if ((Test-Path -LiteralPath $mark) -and (Get-Content -LiteralPath $mark -Raw).Trim() -eq $rel.tag_name) {
        Ok "Far plugin $($Plugin.Name) $($rel.tag_name) - up to date"; $script:FarDone += "$($Plugin.Name) $($rel.tag_name)"; return
    }
    if ("$($asset.digest)" -notmatch '^sha256:([0-9a-f]{64})$') { Warn "Far plugin $($Plugin.Name): GitHub gives no SHA-256 for $($asset.name) - not installed"; return }
    $want = $Matches[1]
    $tmp = Join-Path $env:TEMP "ilt-$($Plugin.Name)-$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    try {
        $file = Join-Path $tmp $asset.name
        Write-Host "  ...  Far plugin $($Plugin.Name) $($rel.tag_name): $($asset.browser_download_url)"
        Invoke-WebRequest -UseBasicParsing -Uri $asset.browser_download_url -OutFile $file -TimeoutSec 300
        $got = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLower()
        if ($got -ne $want) { Warn "Far plugin $($Plugin.Name): SHA-256 does not match ($got, expected $want) - not installed"; return }
        $x = Join-Path $tmp 'x'
        if (-not (Expand-7z $file $x)) { Warn "Far plugin $($Plugin.Name): 7-Zip could not unpack $($asset.name)"; return }
        # Архив с одной папкой внутри - взять её содержимое
        $items = @(Get-ChildItem -LiteralPath $x -Force)
        $src = if ($items.Count -eq 1 -and $items[0].PSIsContainer) { $items[0].FullName } else { $x }
        if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }
        New-Item -ItemType Directory -Force -Path $dest | Out-Null
        Copy-Item -Path (Join-Path $src '*') -Destination $dest -Recurse -Force
        Set-Content -LiteralPath $mark -Value $rel.tag_name -Encoding ASCII
        Ok "Far plugin $($Plugin.Name) $($rel.tag_name) -> $dest (SHA-256 checked)"
        $script:FarDone += "$($Plugin.Name) $($rel.tag_name)"
    } catch { Warn "Far plugin $($Plugin.Name): $($_.Exception.Message)" }
    finally { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
}
# Тема: один раз. Перед импортом - экспорт всех настроек Far в резервную
# копию: -Uninstall вернёт из неё прежние цвета и настройки.
# Far хранит цвет как COLORREF: AABBGGRR. Файлы темы записаны как AARRGGBB
# (FF4FC1FF - голубые папки #4FC1FF): Far показывал их оранжевыми (#FFC14F),
# синий акцент #0078D4 - оранжевым #D47800. Проверено на Windows 2026-10-30.
# Перед импортом красный и синий меняются местами; цвета с флагом
# fgindex/bgindex - номера палитры консоли, а не RGB, их не трогать.
function Convert-ThemeColors {
    param([string] $File)
    $doc = [xml](Get-Content -LiteralPath $File -Raw -Encoding UTF8)
    foreach ($n in @($doc.SelectNodes('//*[@foreground or @background]'))) {
        $flags = " $($n.GetAttribute('flags')) "
        foreach ($pair in @(@('foreground', 'fgindex'), @('background', 'bgindex'))) {
            $v = $n.GetAttribute($pair[0])
            if ($flags -match " $($pair[1]) ") { continue }
            if ($v -match '^([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})$') {
                $n.SetAttribute($pair[0], ($Matches[1] + $Matches[4] + $Matches[3] + $Matches[2]).ToUpper())
            }
        }
    }
    # Свои цвета ($FarColorOverrides) - в раздел цветов, там же, где Panel.Cursor
    $bgrOf = { param($rgb) if ($rgb -match '^#([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})$') { ('FF' + $Matches[3] + $Matches[2] + $Matches[1]).ToUpper() } }
    $anchor = $doc.SelectSingleNode("//object[@name='Panel.Cursor']")
    if ($anchor) {
        foreach ($name in $FarColorOverrides.Keys) {
            $o = $FarColorOverrides[$name]
            $n = $doc.SelectSingleNode("//object[@name='$name']")
            if (-not $n) { $n = $doc.CreateElement('object'); $n.SetAttribute('name', $name); $n.SetAttribute('flags', 'inherit'); [void]$anchor.ParentNode.AppendChild($n) }
            $flags = " $($n.GetAttribute('flags')) "
            if ($o.Back) { $n.SetAttribute('background', (& $bgrOf $o.Back)); if ($flags -match ' bgindex ') { $n.SetAttribute('flags', ($flags -replace ' bgindex ', ' ').Trim()) } }
            if ($o.Text) { $flags = " $($n.GetAttribute('flags')) "; $n.SetAttribute('foreground', (& $bgrOf $o.Text)); if ($flags -match ' fgindex ') { $n.SetAttribute('flags', ($flags -replace ' fgindex ', ' ').Trim()) } }
        }
    }
    $doc.Save($File)
}
# Тема: один раз. Перед первым импортом - экспорт всех настроек Far в
# резервную копию: -Uninstall вернёт из неё прежние цвета и настройки.
# Тема, поставленная прежней версией скрипта (FarThemeRev меньше $FarThemeRev),
# импортируется заново один раз; резервная копия не меняется.
function Install-FarTheme {
    param($Far, $State)
    if ($State.FarTheme -and [int]$State.FarThemeRev -ge $FarThemeRev) { Ok "Far theme $($FarTheme.Name) - already applied"; $script:FarDone += "theme $($FarTheme.Name)"; return }
    $tmp = Join-Path $env:TEMP "ilt-theme-$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    try {
        $files = @()
        foreach ($f in $FarTheme.Files.Keys) {
            $out = Join-Path $tmp (Split-Path -Leaf $f)
            Invoke-WebRequest -UseBasicParsing -Uri "$($FarTheme.Base)/$f" -OutFile $out -TimeoutSec 60
            if ((Get-GitBlobSha $out) -ne $FarTheme.Files[$f]) { Warn "Far theme: $(Split-Path -Leaf $f) does not match its git hash - theme not applied"; return }
            Convert-ThemeColors $out
            $files += $out
        }
        if (-not (Test-Path $Home2)) { New-Item -ItemType Directory -Force -Path $Home2 | Out-Null }
        $backup = Join-Path $Home2 'far-before.farconfig'
        if (-not $State.FarTheme) {
            if ((Invoke-Far $Far.Exe @('-export', "`"$backup`"")) -ne 0 -or -not (Test-Path -LiteralPath $backup)) {
                Warn 'Far theme: could not back up the current Far settings - theme not applied'; return
            }
        }
        foreach ($f in $files) {
            if ((Invoke-Far $Far.Exe @('-import', "`"$f`"")) -ne 0) { Warn "Far theme: Far did not import $(Split-Path -Leaf $f)"; return }
        }
        $fixOnly = [bool]$State.FarTheme
        $State.FarTheme = $true; $State.FarThemeBgr = $true; $State.FarThemeRev = $FarThemeRev; Save-State $State
        if ($fixOnly) { Ok "Far theme $($FarTheme.Name): re-imported (colors in Far's order, own colors: $(@($FarColorOverrides.Keys) -join ', '))" }
        else { Ok "Far theme $($FarTheme.Name) applied (previous settings saved: $backup)" }
        $script:FarDone += "theme $($FarTheme.Name)"
    } catch { Warn "Far theme: $($_.Exception.Message)" }
    finally { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
}
# Схема FarColorer: .hrd в Plugins\FarColorer\base\hrd\rgb и запись в
# catalog.xml перед </hrd-sets>, между своими метками. FarColorer лежит в
# папке программы, а scoop update far её заменяет - поэтому ставится при
# каждом запуске, повторно запись не дублируется.
function Get-ColorerPaths {
    param($Far)
    $base = Join-Path (Split-Path -Parent $Far.Exe) 'Plugins\FarColorer\base'
    return [PSCustomObject]@{
        Catalog = (Join-Path $base 'catalog.xml')
        Hrd     = (Join-Path $base "hrd\rgb\$($FarTheme.Colorer.Scheme).hrd")
    }
}
function Remove-ColorerBlock {
    param([string] $Text)
    return [regex]::Replace($Text, "(?s)\r?\n[ \t]*$([regex]::Escape($ColorerBegin)).*?$([regex]::Escape($ColorerEnd))", '')
}
function Install-FarColorerScheme {
    param($Far, $State)
    $c = Get-ColorerPaths $Far
    if (-not (Test-Path -LiteralPath $c.Catalog)) { Warn "FarColorer not found ($($c.Catalog)) - editor syntax colors not installed"; return }
    $tmp = Join-Path $env:TEMP "ilt-hrd-$([guid]::NewGuid().ToString('N')).hrd"
    try {
        Invoke-WebRequest -UseBasicParsing -Uri "$($FarTheme.Base)/$($FarTheme.Colorer.Path)" -OutFile $tmp -TimeoutSec 60
        if ((Get-GitBlobSha $tmp) -ne $FarTheme.Colorer.Sha) { Warn 'FarColorer scheme: Colorer.hrd does not match its git hash - not installed'; return }
        $dir = Split-Path -Parent $c.Hrd
        if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
        # Подсветка строки ярче: back у def:HorzCross и def:VertCross
        $hrd = [IO.File]::ReadAllText($tmp)
        $hrd = [regex]::Replace($hrd, '(<assign\s+name="def:(?:Horz|Vert)Cross"[^>]*?\bback=")#[0-9A-Fa-f]{6}', "`${1}$ColorerCrossBack")
        [IO.File]::WriteAllText($c.Hrd, $hrd)
        $name = $FarTheme.Colorer.Scheme
        $text = Remove-ColorerBlock ([IO.File]::ReadAllText($c.Catalog))
        if ($text -notmatch '(\s*)</hrd-sets>') { Warn "FarColorer scheme: no </hrd-sets> in $($c.Catalog) - not registered"; return }
        $block = @("        $ColorerBegin",
                   "        <hrd class=`"rgb`" name=`"$name`" description=`"$name (theming-far)`">",
                   "            <location link=`"hrd/rgb/$name.hrd`"/>",
                   '        </hrd>',
                   "        $ColorerEnd") -join "`r`n"
        $text = [regex]::Replace($text, '(\s*)</hrd-sets>', { param($m) "`r`n$block$($m.Groups[1].Value)</hrd-sets>" }, 1)
        [IO.File]::WriteAllText($c.Catalog, $text)
        Ok "FarColorer scheme $name -> $($c.Hrd) (git hash checked), registered in catalog.xml"
        $script:FarDone += "editor colors $name"
        if (-not $State.FarColorer) { $State.FarColorer = $true; Save-State $State }
        Enable-FarColorerScheme $Far $State
    } catch { Warn "FarColorer scheme: $($_.Exception.Message)" }
    finally { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
}
function Remove-FarColorerScheme {
    param($Far)
    $c = Get-ColorerPaths $Far
    $done = $false
    if (Test-Path -LiteralPath $c.Catalog) {
        $text = [IO.File]::ReadAllText($c.Catalog)
        $new = Remove-ColorerBlock $text
        if ($new -ne $text) { [IO.File]::WriteAllText($c.Catalog, $new); $done = $true }
    }
    if (Test-Path -LiteralPath $c.Hrd) { Remove-Item -LiteralPath $c.Hrd -Force -ErrorAction SilentlyContinue; $done = $true }
    if ($done) { Ok 'removed: FarColorer scheme'; return 'FarColorer scheme' }
    return $null
}
# Настройки Far из раздела generalconfig: Interface.VirtualTerminalRendering
# (VT-вывод: без него Far сводит 24-битные цвета темы к 16 цветам консоли) и
# System.AutoSaveSetup (по умолчанию false: без Shift+F9 настройки при выходе
# не сохраняются - far/config.cpp). Файл для -import собирается из выгрузки
# самого Far (-export): тот же корень и тот же раздел, в разделе - одна
# настройка. Формат строки проверен на Far 3.0.6699 (2026-10-30):
# <setting key="Interface" name="VirtualTerminalRendering" type="qword" value="0000000000000001"/>
function Get-FarSetting {
    param($Far, [string] $Key, [string] $Name)
    $exp = Join-Path $env:TEMP "ilt-far-$([guid]::NewGuid().ToString('N')).farconfig"
    try {
        if ((Invoke-Far $Far.Exe @('-export', "`"$exp`"")) -ne 0 -or -not (Test-Path -LiteralPath $exp)) { return $null }
        $doc = [xml](Get-Content -LiteralPath $exp -Raw -Encoding UTF8)
        $node = $doc.SelectSingleNode("//setting[@key='$Key' and @name='$Name']")
        return [PSCustomObject]@{ Doc = $doc; Node = $node; Value = $(if ($node) { $node.value } else { $null }) }
    } catch { return $null }
    finally { Remove-Item -LiteralPath $exp -Force -ErrorAction SilentlyContinue }
}
function Set-FarSetting {
    param($Far, $Current, [string] $Key, [string] $Name, [string] $Value)
    $doc = $Current.Doc
    $root = $doc.DocumentElement
    $sec = if ($Current.Node) { $Current.Node.ParentNode } else { $root.SelectSingleNode('generalconfig') }
    if (-not $sec) { return $false }
    foreach ($c in @($root.ChildNodes)) { if ($c -ne $sec) { [void]$root.RemoveChild($c) } }
    foreach ($c in @($sec.ChildNodes)) { [void]$sec.RemoveChild($c) }
    $n = $doc.CreateElement('setting')
    foreach ($a in @(@('key', $Key), @('name', $Name), @('type', 'qword'), @('value', $Value))) { $n.SetAttribute($a[0], $a[1]) }
    [void]$sec.AppendChild($n)
    $file = Join-Path $env:TEMP "ilt-far-set-$([guid]::NewGuid().ToString('N')).farconfig"
    try {
        $doc.Save($file)
        if ((Invoke-Far $Far.Exe @('-import', "`"$file`"")) -ne 0) { return $false }
    } finally { Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue }
    $after = Get-FarSetting $Far $Key $Name
    return ($after -and $after.Value -eq $Value)
}
# Задать qword-настройку один раз; прежнее значение - в state.json для отката.
# Значения нет в выгрузке - у Far значение по умолчанию: Default (far/config.cpp).
$On = '0000000000000001'; $Off = '0000000000000000'
$FarSettings = [ordered]@{
    VT       = @{ Key = 'Interface'; Name = 'VirtualTerminalRendering'; Default = $Off; Value = $On
                  Manual = 'Turn on VT rendering in Far: F9 > Options > Interface settings > [x] Use Virtual Terminal for rendering > OK, then Shift+F9 to save' }
    AutoSave = @{ Key = 'System'; Name = 'AutoSaveSetup'; Default = $Off; Value = $On
                  Manual = 'Turn on saving settings on exit in Far: F9 > Options > System settings > [x] Auto save setup > OK, then Shift+F9' }
    # Редактор (F4); всё это - и в F9 > Options > Editor settings
    LineNumbers = @{ Key = 'Editor'; Name = 'ShowLineNumbers'; Default = $Off; Value = $On
                  Manual = 'Editor line numbers: F9 > Options > Editor settings > [x] Show line numbers' }
    ScrollBar   = @{ Key = 'Editor'; Name = 'ShowScrollBar'; Default = $Off; Value = $On
                  Manual = 'Editor scrollbar: F9 > Options > Editor settings > [x] Show scrollbar' }
    AutoIndent  = @{ Key = 'Editor'; Name = 'AutoIndent'; Default = $Off; Value = $On
                  Manual = 'Editor auto indent: F9 > Options > Editor settings > [x] Auto indent' }
    BeyondEOL   = @{ Key = 'Editor'; Name = 'EditorCursorBeyondEOL'; Default = $On; Value = $Off
                  Manual = 'Editor cursor stops at end of line: F9 > Options > Editor settings > [ ] Cursor beyond end of line' }
    # 1 = EXPAND_NEWTABS: новая табуляция - пробелами; старые табуляции в файле не трогаются
    ExpandTabs  = @{ Key = 'Editor'; Name = 'ExpandTabs'; Default = $Off; Value = $On
                  Manual = 'Editor Tab as spaces: F9 > Options > Editor settings > Expand tabs: Expand newly entered tabs to spaces' }
}
function Enable-FarSetting {
    param($Far, $State, [string] $Id)
    $s = $FarSettings[$Id]
    $prop = "Far${Id}Before"
    if (-not $State.PSObject.Properties[$prop]) { $State | Add-Member -NotePropertyName $prop -NotePropertyValue $null }
    if ($State.$prop) { Ok "Far $($s.Key).$($s.Name) - already handled"; return }
    $cur = Get-FarSetting $Far $s.Key $s.Name
    if (-not $cur) { Add-Step 50 $s.Manual; return }
    $before = if ($cur.Value) { $cur.Value } else { $s.Default }
    if ($before -eq $s.Value) {
        Ok "Far $($s.Key).$($s.Name) - already $([int]('0x' + $s.Value))"
    } elseif (Set-FarSetting $Far $cur $s.Key $s.Name $s.Value) {
        Ok "Far $($s.Key).$($s.Name) = $([int]('0x' + $s.Value))"; $script:FarDone += "$($s.Key).$($s.Name)"
    } else { Add-Step 50 $s.Manual; return }
    $State.$prop = $before; Save-State $State
}
function Restore-FarSetting {
    param($Far, $State, [string] $Id)
    $s = $FarSettings[$Id]
    $before = $State."Far${Id}Before"
    if (-not $before -or $before -eq $s.Value) { return $null }
    $cur = Get-FarSetting $Far $s.Key $s.Name
    if (-not $cur -or $cur.Value -eq $before) { return $null }
    if (Set-FarSetting $Far $cur $s.Key $s.Name $before) { Ok "Far $($s.Key).$($s.Name) set back to $([int]('0x' + $before))"; return "Far $($s.Key).$($s.Name)" }
    Warn "Far $($s.Key).$($s.Name): could not set it back to $([int]('0x' + $before))"
    return $null
}
# Настройки FarColorer тоже выгружаются Far (-export) - формат проверен на
# 3.0.6699 (2026-10-30):
#   <раздел><plugin guid="D2F36B62-..."><hierarchicalconfig>
#     <key name="D2F36B62-..." description="FarColorer">
#       <value name="TrueMod" type="qword" value="0000000000000001"/>
#       <value name="HrdNameTm" type="text" value="FarDark2026"/>
# Раздел(ы) с <plugin> берутся из выгрузки; в файле для -import остаются
# только они, а в них - один FarColorer с нужными значениями.
$ColorerGuid = 'D2F36B62-A470-418D-83A3-ED7A3710E5B5'
function Get-FarExport {
    param($Far)
    $exp = Join-Path $env:TEMP "ilt-far-$([guid]::NewGuid().ToString('N')).farconfig"
    try {
        if ((Invoke-Far $Far.Exe @('-export', "`"$exp`"")) -ne 0 -or -not (Test-Path -LiteralPath $exp)) { return $null }
        return [xml](Get-Content -LiteralPath $exp -Raw -Encoding UTF8)
    } catch { return $null }
    finally { Remove-Item -LiteralPath $exp -Force -ErrorAction SilentlyContinue }
}
# Что скрипт задаёт в FarColorer. CrossDraw/CrossStyle - подсветка текущей
# строки ("крест"), src/FarEditor.h: CrossDraw 0 выкл, 1 всегда, 2 если
# включено в схеме; CrossStyle 1 столбец, 2 строка, 3 оба
$ColorerWanted = [ordered]@{
    TrueMod    = @('qword', '0000000000000001')
    HrdNameTm  = @('text',  $FarTheme.Colorer.Scheme)
    CrossDraw  = @('qword', '0000000000000001')
    CrossStyle = @('qword', '0000000000000002')
}
function Get-ColorerValues {
    param($Doc)
    $out = @{}
    foreach ($n in $ColorerWanted.Keys) {
        $v = $Doc.DocumentElement.SelectSingleNode("pluginsconfig/plugin[@guid='$ColorerGuid']/hierarchicalconfig/key/value[@name='$n']")
        $out[$n] = if ($v) { $v.value } else { $null }
    }
    return $out
}
# $Values: имя -> @(тип, значение)
function Set-ColorerValues {
    param($Far, $Doc, [hashtable] $Values)
    # Far при -import читает настройки плагинов только из farconfig/pluginsconfig
    # (far/configdb.cpp, config_provider::Import). Узлы plugin есть и в
    # pluginhotkeys, а в свежем профиле pluginsconfig пуст - искать раздел по
    # //plugin нельзя: настройки уходили не туда. В файле импорта - только он.
    $root = $Doc.DocumentElement
    $pc = $root.SelectSingleNode('pluginsconfig')
    if (-not $pc) { $pc = $Doc.CreateElement('pluginsconfig') }
    foreach ($c in @($root.ChildNodes)) { [void]$root.RemoveChild($c) }
    [void]$root.AppendChild($pc)
    foreach ($c in @($pc.ChildNodes)) { [void]$pc.RemoveChild($c) }
    $pl = $Doc.CreateElement('plugin'); $pl.SetAttribute('guid', $ColorerGuid)
    $hc = $Doc.CreateElement('hierarchicalconfig')
    $k = $Doc.CreateElement('key'); $k.SetAttribute('name', $ColorerGuid); $k.SetAttribute('description', 'FarColorer')
    foreach ($name in $Values.Keys) {
        $v = $Doc.CreateElement('value')
        $v.SetAttribute('name', $name); $v.SetAttribute('type', $Values[$name][0]); $v.SetAttribute('value', $Values[$name][1])
        [void]$k.AppendChild($v)
    }
    [void]$hc.AppendChild($k); [void]$pl.AppendChild($hc); [void]$pc.AppendChild($pl)
    $file = Join-Path $env:TEMP "ilt-far-colorer-$([guid]::NewGuid().ToString('N')).farconfig"
    try {
        $Doc.Save($file)
        if ((Invoke-Far $Far.Exe @('-import', "`"$file`"")) -ne 0) { return $false }
    } finally { Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue }
    $after = Get-FarExport $Far
    if (-not $after) { return $false }
    $got = Get-ColorerValues $after
    foreach ($name in $Values.Keys) { if ($got[$name] -ne $Values[$name][1]) { return $false } }
    return $true
}
function Enable-FarColorerScheme {
    param($Far, $State)
    $name = $FarTheme.Colorer.Scheme
    $manual = "Turn on the editor syntax colors: in Far press Alt+Shift+F9 > FarColorer, tick [x] TrueMod Enabled, in 'TrueMod color style' pick '$name (theming-far)', set [x] Cross with style 'horizontal', press OK"
    $doc = Get-FarExport $Far
    if (-not $doc) { Add-Step 50 $manual; return }
    $before = Get-ColorerValues $doc
    $todo = [ordered]@{}
    foreach ($k in $ColorerWanted.Keys) { if ($before[$k] -ne $ColorerWanted[$k][1]) { $todo[$k] = $ColorerWanted[$k] } }
    if (-not $todo.Count) {
        Ok "FarColorer: TrueMod, style $name, current line highlight - already on"
    } elseif (Set-ColorerValues $Far $doc $todo) {
        Ok "FarColorer: $(@($todo.Keys) -join ', ') set (TrueMod, style $name, current line highlight)"
        $script:FarDone += "editor style $name"
    } else { Add-Step 50 $manual; return }
    # Прежние значения для отката: по каждому ключу один раз
    if (-not $State.FarColorerBefore) { $State.FarColorerBefore = [PSCustomObject]@{} }
    foreach ($k in $ColorerWanted.Keys) {
        if (-not $State.FarColorerBefore.PSObject.Properties[$k]) {
            $State.FarColorerBefore | Add-Member -NotePropertyName $k -NotePropertyValue $before[$k]
        }
    }
    Save-State $State
}
function Enable-FarVt {
    param($Far, $State)
    foreach ($id in $FarSettings.Keys) { Enable-FarSetting $Far $State $id }
}
function Install-FarExtras {
    param($State)
    $far = Get-FarPaths
    if (-not $far) { return }
    if (Test-FarRunning) {
        Warn 'Far Manager is running - plugins and theme are not installed. Close Far and run the script again.'
        # Ярлыкам запущенный Far не мешает
        if (@($State.Packages) -contains 'far') { Install-FarDesktopLink $State }
        return
    }
    foreach ($p in $FarPlugins) { Install-FarPlugin $p $far }
    Install-FarTheme $far $State
    Install-FarColorerScheme $far $State
    Enable-FarVt $far $State
    if (@($State.Packages) -contains 'far') { Install-FarLastDir $far $State; Install-FarDesktopLink $State }
}
# Ярлыки Far на рабочем столе: Far4Pwsh (PowerShell) и Far4CMD (cmd). Оба
# запускают не Far.exe, а оболочку: после выхода из Far (F10) окно остаётся,
# и оболочка - в папке, где был Far. Far.exe напрямую закрыл бы окно вместе с
# собой. PowerShell зовёт функцию far из профиля. В cmd макрос doskey far
# срабатывает только на набранное руками, не на /k, поэтому ярлык cmd сам
# выполняет те же команды, что макрос (Set-CmdMacros). Значок - из
# scoop\apps\far\current\Far.exe: путь current Scoop переводит на новую
# версию. Ярлык с тем же именем, но не наш (нет в State.FarDesktopLinks), не
# трогается. "Far Manager.lnk" - имя до 2026-10-31 (State.FarDesktopLink).
$FarLegacyLink = 'Far Manager.lnk'
function Get-FarDesktopLinks {
    $f = '%TEMP%\far-lastdir.txt'
    $cmdArgs = "/k set `"FAR_LASTDIR_FILE=$f`" & del `"$f`" 2>nul & `"$ShimDir\far.exe`" & set `"FAR_LASTDIR_FILE=`" & if exist `"$f`" for /f `"usebackq delims=`" %d in (`"$f`") do cd /d `"%d`""
    return [ordered]@{
        'Far4Pwsh.lnk' = @{ Exe = 'System32\WindowsPowerShell\v1.0\powershell.exe'; Args = '-NoExit -Command far'; Desc = 'Far Manager in PowerShell (Install-LinuxTools)' }
        'Far4CMD.lnk'  = @{ Exe = 'System32\cmd.exe'; Args = $cmdArgs; Desc = 'Far Manager in cmd (Install-LinuxTools)' }
    }
}
function Install-FarDesktopLink {
    param($State)
    $far = Join-Path $ScoopRoot 'apps\far\current\Far.exe'
    if (-not (Test-Path -LiteralPath $far)) { return }
    $desk = [Environment]::GetFolderPath('Desktop')
    if (-not $State.PSObject.Properties['FarDesktopLinks']) { $State | Add-Member -NotePropertyName FarDesktopLinks -NotePropertyValue @() }
    # Старый ярлык скрипта - заменяется двумя новыми. Свой он, если так
    # записано в state.json или в его описании стоит метка скрипта
    # (Description 'Far Manager (Install-LinuxTools)'): запись могла пропасть
    # при -Uninstall -WithFar и повторной установке.
    $old = Join-Path $desk $FarLegacyLink
    if (Test-Path -LiteralPath $old) {
        $desc = try { (New-Object -ComObject WScript.Shell).CreateShortcut($old).Description } catch { '' }
        if ($State.FarDesktopLink -or $desc -like '*(Install-LinuxTools)*') {
            Remove-Item -LiteralPath $old -Force -ErrorAction SilentlyContinue
            if (-not (Test-Path -LiteralPath $old)) { Ok "removed old desktop shortcut: $old" }
        }
    }
    if ($State.PSObject.Properties['FarDesktopLink']) { $State.PSObject.Properties.Remove('FarDesktopLink'); Save-State $State }
    $links = Get-FarDesktopLinks
    foreach ($name in $links.Keys) {
        $lnk = Join-Path $desk $name
        $ours = @($State.FarDesktopLinks) -contains $name
        if ((Test-Path -LiteralPath $lnk) -and -not $ours) { Ok "desktop shortcut - yours is there, left alone: $lnk"; continue }
        $l = $links[$name]
        try {
            $sc = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk)
            $sc.TargetPath = Join-Path $env:SystemRoot $l.Exe
            $sc.Arguments = $l.Args
            $sc.WorkingDirectory = $env:USERPROFILE
            $sc.IconLocation = "$far,0"
            $sc.Description = $l.Desc
            $sc.Save()
        } catch { Warn "desktop shortcut $name not created: $($_.Exception.Message)"; continue }
        if (-not $ours) { $State.FarDesktopLinks = @($State.FarDesktopLinks) + $name; Save-State $State }
        Ok "desktop shortcut: $lnk"
    }
}
function Remove-FarDesktopLink {
    param($State)
    $desk = [Environment]::GetFolderPath('Desktop')
    $names = @($State.FarDesktopLinks | Where-Object { $_ })
    $old = Join-Path $desk $FarLegacyLink
    if (Test-Path -LiteralPath $old) {
        $desc = try { (New-Object -ComObject WScript.Shell).CreateShortcut($old).Description } catch { '' }
        if ($State.FarDesktopLink -or $desc -like '*(Install-LinuxTools)*') { $names += $FarLegacyLink }
    }
    $done = @()
    foreach ($name in $names) {
        $lnk = Join-Path $desk $name
        if (Test-Path -LiteralPath $lnk) { Remove-Item -LiteralPath $lnk -Force -ErrorAction SilentlyContinue }
        if (Test-Path -LiteralPath $lnk) { Warn "could not remove $lnk"; continue }
        Ok "removed: $lnk"; $done += "desktop shortcut $name"
    }
    return $done
}
# Выход из Far - в папку, где закрылся Far (как mc-wrapper в Linux). Программа
# не может сменить папку оболочки, из которой её запустили, поэтому:
# 1) макрос Far на событие exitfar (EventGroups в plugins/luamacro/utils.lua)
#    пишет путь активной панели в файл из переменной FAR_LASTDIR_FILE;
# 2) обёртка far - функция в профиле PowerShell и макрос doskey в cmd -
#    задаёт эту переменную, запускает Far и после выхода делает cd.
# Панель плагина (архив, SFTP) не настоящая папка - тогда ничего не пишется.
# В том же файле - Backspace на панели при пустой командной строке: на папку
# вверх, как в mc (CmdLine.Empty - plugins/luamacro/api.lua). Набранная
# команда стирается, как обычно.
$FarLastDirMacro = @'
-- Install-LinuxTools: on exit write the active panel folder for the shell wrapper "far"
Event {
  group = "ExitFAR";
  description = "Install-LinuxTools: save the last folder for the shell";
  action = function()
    local f = win.GetEnv("FAR_LASTDIR_FILE")
    if not f or f == "" or APanel.Plugin then return end
    local h = io.open(f, "w")
    if h then h:write(APanel.Path); h:close() end
  end;
}

-- Install-LinuxTools: Backspace in a panel with an empty command line goes one folder up, like mc
Macro {
  area = "Shell"; key = "BS";
  description = "Install-LinuxTools: one folder up (Ctrl+PgUp)";
  condition = function() return CmdLine.Empty end;
  action = function() Keys("CtrlPgUp") end;
}
'@
$FarBegin = '# >>> Install-LinuxTools: far opens and leaves in the current folder >>>'
$FarEnd   = '# <<< Install-LinuxTools: far <<<'
function Get-FarMacroFile { param($Far) return (Join-Path (Split-Path -Parent $Far.Plugins) 'Macros\scripts\Install-LinuxTools.lua') }
function Remove-FarProfileBlock {
    foreach ($p in $Profiles) {
        if (-not (Test-Path -LiteralPath $p)) { continue }
        $text = Get-Content -LiteralPath $p -Raw
        $new = [regex]::Replace($text, "(?s)\r?\n*$([regex]::Escape($FarBegin)).*?$([regex]::Escape($FarEnd))\r?\n?", "`r`n")
        if ($new -ne $text) { Set-Content -LiteralPath $p -Value $new.TrimEnd() -Encoding UTF8; Ok "PowerShell far function removed: $p" }
    }
}
function Install-FarLastDir {
    param($Far, $State)
    $mf = Get-FarMacroFile $Far
    $dir = Split-Path -Parent $mf
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    [IO.File]::WriteAllText($mf, $FarLastDirMacro.Replace("`r`n", "`n"))
    $lines = @($FarBegin,
        'function far {',
        '    $f = Join-Path $env:TEMP "far-lastdir-$PID.txt"',
        '    Remove-Item -LiteralPath $f -ErrorAction SilentlyContinue',
        '    $env:FAR_LASTDIR_FILE = $f',
        "    try { & '$ShimDir\far.exe' @args } finally { Remove-Item Env:FAR_LASTDIR_FILE -ErrorAction SilentlyContinue }",
        '    if (Test-Path -LiteralPath $f) {',
        '        $d = (Get-Content -LiteralPath $f -Raw -Encoding UTF8).Trim(); Remove-Item -LiteralPath $f',
        '        if ($d -and (Test-Path -LiteralPath $d)) { Set-Location -LiteralPath $d }',
        '    }',
        '}',
        $FarEnd)
    Remove-FarProfileBlock
    foreach ($p in $Profiles) {
        $pd = Split-Path -Parent $p
        if (-not (Test-Path $pd)) { New-Item -ItemType Directory -Force -Path $pd | Out-Null }
        $text = if (Test-Path -LiteralPath $p) { Get-Content -LiteralPath $p -Raw } else { '' }
        Set-Content -LiteralPath $p -Value (("$text".TrimEnd() + "`r`n`r`n" + ($lines -join "`r`n")).TrimStart() + "`r`n") -Encoding UTF8
    }
    if (-not $State.FarLastDir) { $State | Add-Member -NotePropertyName FarLastDir -NotePropertyValue $true -Force; Save-State $State; $script:Changed = $true }
    Ok 'far: after you quit Far, the shell stays in the folder Far was in (PowerShell and cmd)'
}
function Remove-FarLastDir {
    param($Far, $State)
    if (-not $State.FarLastDir) { return $null }
    if ($Far) { Remove-Item -LiteralPath (Get-FarMacroFile $Far) -Force -ErrorAction SilentlyContinue }
    Remove-FarProfileBlock
    Ok 'removed: far folder hand-over (Far macro, PowerShell function)'
    return 'far folder hand-over'
}

# Откат: свои папки плагинов (с меткой) и прежние настройки из резервной копии
function Remove-FarExtras {
    param($State)
    $far = Get-FarPaths
    if (-not $far) { return @() }
    if (Test-FarRunning) { Warn 'Far Manager is running - its plugins and theme are not rolled back. Close Far and run -Uninstall again.'; return @() }
    $done = @()
    $r = Remove-FarLastDir $far $State; if ($r) { $done += $r }
    foreach ($p in $FarPlugins) {
        $dest = Join-Path $far.Plugins $p.Name
        if (Test-Path -LiteralPath (Join-Path $dest $FarMarker)) {
            Remove-Item -LiteralPath $dest -Recurse -Force -ErrorAction SilentlyContinue
            if (Test-Path -LiteralPath $dest) { Warn "Far plugin $($p.Name) - could not remove $dest" } else { Ok "removed: Far plugin $($p.Name)"; $done += "Far plugin $($p.Name)" }
        }
    }
    if ($State.FarColorer) { $done += @(Remove-FarColorerScheme $far | Where-Object { $_ }) }
    $backup = Join-Path $Home2 'far-before.farconfig'
    if ($State.FarTheme -and (Test-Path -LiteralPath $backup)) {
        if ((Invoke-Far $far.Exe @('-import', "`"$backup`"")) -eq 0) { Ok 'Far settings restored from the backup made before the theme'; $done += 'Far theme' }
        else { Warn "Far did not import the backup $backup - colors stay as they are" }
    }
    # FarColorer: вернуть прежние TrueMod и стиль, если они были заданы до скрипта
    if ($State.FarColorerBefore) {
        $vals = @{}
        foreach ($k in $ColorerWanted.Keys) {
            $v = $State.FarColorerBefore.$k
            if ($v) { $vals[$k] = @($ColorerWanted[$k][0], $v) }
        }
        $doc = if ($vals.Count) { Get-FarExport $far } else { $null }
        if ($doc -and (Set-ColorerValues $far $doc $vals)) { Ok 'FarColorer: previous TrueMod, style and cross restored'; $done += 'FarColorer style' }
        elseif ($vals.Count) { Warn 'FarColorer: could not restore the previous style - pick it in Alt+Shift+F9 > FarColorer' }
    }
    # VT и автосохранение: вернуть значения, которые были до скрипта
    foreach ($id in $FarSettings.Keys) { $r = Restore-FarSetting $far $State $id; if ($r) { $done += $r } }
    return $done
}

# Все команды из пакетов этого скрипта - по полю bin манифестов Scoop
# (у части пакетов оно внутри architecture.64bit). Элемент bin - строка
# "путь" или список "путь, имя[, ключи]": имя команды - второе.
function Get-InstalledList {
    $ver = @{}
    foreach ($o in @(scoop list 6>$null)) { $ver[$o.Name] = $o.Version }
    $out = @()
    foreach ($pkg in $AllPkgs) {
        if (-not $ver.ContainsKey($pkg)) { continue }
        $mf = Join-Path $ScoopRoot "apps\$pkg\current\manifest.json"
        if (-not (Test-Path -LiteralPath $mf)) { continue }
        $m = Get-Content -LiteralPath $mf -Raw | ConvertFrom-Json
        $bins = @($m.bin) + @($m.architecture.'64bit'.bin) | Where-Object { $_ }
        $names = @(foreach ($b in $bins) {
            $b = @($b)
            if ($b.Count -ge 2) { $b[1] } else { ("$($b[0])" -split '[\\/]')[-1] -replace '\.[^.]+$', '' }
        }) | Sort-Object -Unique
        if ($names.Count) { $out += [PSCustomObject]@{ Package = "$pkg $($ver[$pkg])"; Commands = $names } }
    }
    return $out
}

# whois: в Scoop его нет - свой манифест на github.com/likexian/whois. Хеш -
# из .sha256, опубликованного рядом с архивом. Манифест лежит постоянно:
# scoop update whois читает его заново.
function Write-WhoisManifest {
    param([string] $Version, [string] $Hash)
    if (-not (Test-Path $Home2)) { New-Item -ItemType Directory -Force -Path $Home2 | Out-Null }
    [ordered]@{
        version = $Version; description = 'Go whois client (likexian/whois)'
        homepage = 'https://github.com/likexian/whois'; license = 'Apache-2.0'
        url = "https://github.com/likexian/whois/releases/download/v$Version/whois-windows-amd64.zip"
        hash = $Hash; extract_dir = 'whois'; bin = 'whois.exe'
    } | ConvertTo-Json | Set-Content -LiteralPath $WhoisJson -Encoding ASCII
}
function Get-WhoisLatest {
    $rel = Invoke-RestMethod -Uri 'https://api.github.com/repos/likexian/whois/releases/latest' -TimeoutSec 20
    $sumUrl = ($rel.assets | Where-Object { $_.name -eq 'whois-windows-amd64.zip.sha256' }).browser_download_url
    $hash = ((Invoke-RestMethod -Uri $sumUrl -TimeoutSec 20) -split '\s+')[0].Trim()
    return [PSCustomObject]@{ Version = $rel.tag_name.TrimStart('v'); Hash = $hash }
}

# --- PowerShell-профиль и cmd -------------------------------------------------
function Remove-ProfileBlock {
    foreach ($p in $Profiles) {
        if (-not (Test-Path -LiteralPath $p)) { continue }
        $text = Get-Content -LiteralPath $p -Raw
        $new = [regex]::Replace($text, "(?s)\r?\n*$([regex]::Escape($Begin)).*?$([regex]::Escape($End))\r?\n?", "`r`n")
        if ($new -ne $text) { Set-Content -LiteralPath $p -Value $new.TrimEnd() -Encoding UTF8; Ok "PowerShell profile block removed: $p" }
    }
}
function Add-ProfileBlock {
    # Псевдоним убирается, только если Linux-замена установлена: иначе
    # команда (например diff) пропала бы совсем
    $lines = @($Begin, "`$sb = '$ShimDir'")
    foreach ($n in $PsNames) {
        $lines += "if (Test-Path `"`$sb\$n.exe`") { if (Test-Path Alias:\$n) { Remove-Item Alias:\$n -Force }; Set-Alias -Name $n -Value `"`$sb\$n.exe`" -Scope Global }"
    }
    # Серая подсказка из истории, Right - принять (PSReadLine 2.1+)
    $lines += "if ((Get-Module PSReadLine).Version -ge [version]'2.1') { try { Set-PSReadLineOption -PredictionSource History; Set-PSReadLineOption -PredictionViewStyle InlineView } catch { } }"
    # posh-git: ветка и изменения git в приглашении; PSFzf: Ctrl+R - история,
    # Ctrl+T - файлы, через fzf
    $lines += "Import-Module posh-git -ErrorAction SilentlyContinue"
    $lines += "if (Get-Command fzf -ErrorAction SilentlyContinue) { Import-Module PSFzf -ErrorAction SilentlyContinue; if (Get-Command Set-PsFzfOption -ErrorAction SilentlyContinue) { Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r' } }"
    $lines += $End
    Remove-ProfileBlock
    foreach ($p in $Profiles) {
        $dir = Split-Path -Parent $p
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
        $text = if (Test-Path -LiteralPath $p) { Get-Content -LiteralPath $p -Raw } else { '' }
        if ($text) { Copy-Item -LiteralPath $p -Destination "$p.bak.$(Get-Date -Format yyyyMMdd-HHmmss)" }
        Set-Content -LiteralPath $p -Value (("$text".TrimEnd() + "`r`n`r`n" + ($lines -join "`r`n")).TrimStart() + "`r`n") -Encoding UTF8
        Ok "PowerShell profile: $p"
    }
    $script:Changed = $true
}

# cmd: псевдонимов нет, есть макросы doskey. AutoRun в реестре загружает их
# при каждом запуске cmd. Через тот же AutoRun обычно запускается и clink
# ("clink.bat inject --autorun"): наша часть ставится перед ним, через " & ",
# его часть не трогается. Откат вырезает из ТЕКУЩЕГО значения только нашу
# часть - clink мог переписать AutoRun после нас, и "вернуть как было"
# затёрло бы его. С clink макросы раскрываются и после | и & (doskey.enhanced).
$CmdOurs = "doskey /macrofile=`"$MacroFile`""
function Set-CmdMacros {
    param($State)
    $m = @()
    if ($State.ProfileBlock) {
        foreach ($n in $CmdNames) { if (Test-Path (Join-Path $ShimDir "$n.exe")) { $m += "$n=`"$ShimDir\$n.exe`" `$*" } }
    }
    # far: после выхода - cd в папку, где закрылся Far (её пишет макрос Far)
    if ($State.FarLastDir) {
        $f = '%TEMP%\far-lastdir.txt'
        $m += "far=set `"FAR_LASTDIR_FILE=$f`" `$T del `"$f`" 2`$Gnul `$T `"$ShimDir\far.exe`" `$* `$T set `"FAR_LASTDIR_FILE=`" `$T if exist `"$f`" for /f `"usebackq delims=`" %d in (`"$f`") do cd /d `"%d`""
    }
    if (-not (Test-Path $Home2)) { New-Item -ItemType Directory -Force -Path $Home2 | Out-Null }
    Set-Content -LiteralPath $MacroFile -Value $m -Encoding ASCII
    if (-not (Test-Path $CmdKey)) { New-Item -Path $CmdKey -Force | Out-Null }
    $cur = "$((Get-ItemProperty -Path $CmdKey -Name AutoRun -ErrorAction SilentlyContinue).AutoRun)"
    if ($cur -notlike "*$CmdOurs*") {
        $value = if ($cur.Trim()) { "$CmdOurs & $cur" } else { $CmdOurs }
        Set-ItemProperty -Path $CmdKey -Name AutoRun -Value $value
        $script:Changed = $true
    }
    $State.CmdAutoRunSet = $true; Save-State $State
    Ok "cmd macros ($($m.Count)): $MacroFile, loaded by AutoRun"
    if ($cur -match 'clink') { Ok 'clink found in AutoRun: kept, runs after the macros' }
}
function Remove-CmdMacros {
    param($State)
    if (-not $State.CmdAutoRunSet) { return }
    $cur = "$((Get-ItemProperty -Path $CmdKey -Name AutoRun -ErrorAction SilentlyContinue).AutoRun)"
    $rest = $cur.Replace("$CmdOurs & ", '').Replace($CmdOurs, '').Trim()
    if ($rest -ne $cur.Trim()) {
        if ($rest) { Set-ItemProperty -Path $CmdKey -Name AutoRun -Value $rest; Ok "cmd AutoRun: our part removed, kept: $rest" }
        else { Remove-ItemProperty -Path $CmdKey -Name AutoRun -ErrorAction SilentlyContinue; Ok 'cmd AutoRun removed (it held only our macros)' }
    }
    Remove-Item -LiteralPath $MacroFile -Force -ErrorAction SilentlyContinue
}

# --- проверка ----------------------------------------------------------------
# Запуск утилиты с ключом версии. 0xC0000135 (-1073741515) - Windows не нашла
# DLL, 0xC000007B (-1073741701) - DLL не той разрядности.
function Test-Tool {
    param([string] $Name)
    $exe = Join-Path $ShimDir "$Name.exe"
    if (-not (Test-Path $exe)) { return [PSCustomObject]@{ Command = $Name; Status = 'MISSING'; Version = '' } }
    # Через gsudo проверка вызвала бы окно UAC - запускается сама программа
    if (Test-ShimElevated $Name) { $real = Get-ShimTarget $Name; if ($real -and (Test-Path -LiteralPath $real)) { $exe = $real } }
    $out = @(& $exe $Checks[$Name] 2>&1 | ForEach-Object { "$_" } | Where-Object { $_.Trim() })
    if (@(-1073741515, -1073741701) -contains $LASTEXITCODE) { return [PSCustomObject]@{ Command = $Name; Status = 'NO DLL'; Version = '' } }
    $ver = "$($out | Select-Object -First 1)".Trim(); if ($ver.Length -gt 70) { $ver = $ver.Substring(0, 70) }
    return [PSCustomObject]@{ Command = $Name; Status = 'ok'; Version = $ver }
}
# Проверка всех утилит. Не запускается из-за DLL - выяснить по самому .exe,
# каких DLL нет; Visual C++ 2015-2022 поставить и проверить ещё раз; что
# поставить не вышло - в шаги руками.
function Invoke-Check {
    param($State, [string[]] $Skip = @())
    $rows = @(foreach ($n in $Checks.Keys) { if ($Skip -notcontains $n) { Test-Tool $n } })
    # Страховка: что не поставилось сразу после пакетов
    $need = Get-DllNeeds @($rows | Where-Object Status -eq 'NO DLL' | ForEach-Object Command)
    Install-NeededVc $need $State
    if ($script:Fixed.Count) {
        $rows = @($rows | ForEach-Object { if ($script:Fixed[$_.Command]) { Test-Tool $_.Command } else { $_ } })
    }
    # Шаги руками - только для того, что так и не запустилось
    $still = @($rows | Where-Object Status -eq 'NO DLL' | ForEach-Object Command)
    $explained = @()
    foreach ($x in @($need.Values)) {
        $tools = @($x.Tools | Where-Object { $still -contains $_ })
        if (-not $tools.Count) { continue }
        $explained += $tools
        $list = $tools -join ', '
        if (-not $x.Redist) {
            Add-Step 30 "${list}: $($x.Dlls -join ', ') missing. It is not part of Visual C++, so the script cannot install it." @('Send the log. Its path is in the last line.')
        } elseif ($x.Redist.Auto) {
            Add-VcStep $x.Arch $tools
        } else {
            $file = if ($x.Arch -eq 'x86') { 'vcredist_x86.exe' } else { 'vcredist_x64.exe' }
            Add-Step 10 "Install $($x.Redist.Name) $($x.Arch). Without it, these do not start: $list" @(
                "Download page:      $($x.Redist.Page)", "File on that page:  $file")
        }
    }
    $unknown = @($still | Where-Object { $explained -notcontains $_ })
    if ($unknown.Count) {
        Add-Step 30 "$($unknown -join ', ') do not start, and the script could not find which DLL is missing" @('Send the log. Its path is in the last line.')
    }
    $rows | Format-Table -AutoSize | Out-String -Width 200 | Write-Host
    return $rows
}
function Get-CheckSections {
    param($Rows)
    return @(
        @{ Title = 'Working';         Color = 'Green'; Items = @($Rows | Where-Object Status -eq 'ok'      | ForEach-Object Command) }
        @{ Title = 'Do not start';    Color = 'Red';   Items = @($Rows | Where-Object Status -eq 'NO DLL'  | ForEach-Object Command); Tail = ' - libraries are missing, see the steps below' }
        @{ Title = 'Far Manager';     Color = 'Green'; Items = @($script:FarDone | Select-Object -Unique) }
        @{ Title = 'Not installed';   Color = 'Red';   Items = @($Rows | Where-Object Status -eq 'MISSING' | ForEach-Object Command); Tail = ' - the reason is in the warnings' }
    )
}
function Add-UsageNotes {
    param($Rows, $State)
    # Far и nmap ставятся только по -WithFar/-WithNmap: чего нет - как добавить
    $have = Get-ScoopInstalled
    if ($have -notcontains 'far')  { Add-Note 'Far Manager is not installed. To add it:  .\Install-LinuxTools.ps1 -WithFar' }
    if ($have -notcontains 'nmap') { Add-Note 'nmap, ncat are not installed. To add them:  .\Install-LinuxTools.ps1 -WithNmap' }
    if (@($Rows | Where-Object { @('trip', 'nmap') -contains $_.Command -and $_.Status -eq 'ok' }).Count) {
        Add-Note 'mtr, nmap and nping ask for administrator rights themselves (through gsudo): they need raw network access. trip without "mtr" does not.'
    }
    if ($have -contains 'curl' -and -not $State.ProfileBlock) {
        Add-Note 'curl and wget from Scoop: without -LinuxFirst "curl" is still Windows'' own (C:\Windows\System32\curl.exe), and in PowerShell 5.1 "curl"/"wget" are Invoke-WebRequest. Run with -LinuxFirst to make them open the new ones.'
    }
    if ($have -contains 'gsudo') {
        # Scoop даёт gsudo ярлык 'sudo'; на Windows 11 со включённым своим sudo
        # тот стоит в системном PATH раньше - надёжное имя gsudo
        Add-Note 'Run a command as administrator in the same window:  gsudo <command>  (on Windows 11 "sudo" may open Windows'' own sudo)'
    }
    Add-Note 'Update later:  .\Install-LinuxTools.ps1 -Update'
    Add-Note 'Remove all:    .\Install-LinuxTools.ps1 -Uninstall'
    if ($script:Changed) { Add-Step 90 'Open a new PowerShell or cmd window: old windows do not see the new commands' }
}

# Шаги 2 и 3: все пакеты скрипта. Уже стоящие пропускаются, поэтому -Update
# через эту же функцию доставляет пакеты, добавленные в скрипт позже.
# git нужен самому Scoop. `scoop install` перед каждым пакетом проверяет, не
# устарел ли Scoop, и запускает scoop-update.ps1, а тот без git обрывается:
# "Scoop uses Git to update itself. Run 'scoop install git' and try again." -
# сообщение перед каждой утилитой, и -Update ничего не обновляет. Поэтому git
# ставится сразу после Scoop, до первой утилиты. Bucket main, скачанный без
# git архивом, Scoop при первом `scoop update` сам переводит на git.
function Assert-Git {
    param($State)
    $g = Get-Command git -ErrorAction SilentlyContinue
    if ($g) { Ok "git: $($g.Source) (Scoop needs it for updates)"; return }
    Write-Host '  ...  git - Scoop needs it to update itself and the package lists'
    # --no-update-scoop: иначе scoop install сначала пробует обновить Scoop -
    # а без git это и есть то самое сообщение
    Install-ScoopPackage 'git' $null $State -NoUpdateScoop
    Update-SessionPath
}

# Цвета имён файлов для lsd (ll), eza, ls (uutils), fd - переменная
# LS_COLORS, колонки eza - EZA_COLORS. Без LS_COLORS типы файлов идут цветами
# палитры консоли, а синий там - тёмный #0037DA: папки почти не видны. На
# Windows lsd читает именно LS_COLORS (README lsd, "custom color schemes for
# Windows"). Цвета - из палитры Linux-машины пользователя
# (~/.config/lscolors.sh, 2026-10-30), но не вся она: переменная окружения
# пользователя длиннее 2047 знаков до новых окон не доходит - Проводник
# пересобирает окружение с расчётом на 2048 знаков (статья Microsoft "Error
# messages after you change the 2047 character limit in an environment
# variable"). Полная палитра - 16 000 знаков; здесь типы файлов и частые
# расширения Windows (1835 знаков), плюс exe/cmd/ps1/msi цветом программ.
# Ссылки (ln) - не подчёркнутый зелёный, как на Linux, а плашка: тёмный текст
# на бирюзовом фоне. В Windows ссылки-папки (C:\Users\All Users и т.п.) иначе
# не отличить: ll на них показывает саму ссылку, а не содержимое.
$LsColorsValue = 'di=1;38;2;127;187;179:ln=1;38;2;30;30;30;48;2;78;201;176:or=1;38;2;230;126;128:ex=1;38;2;167;192;128:pi=38;2;230;152;117:so=38;2;230;152;117:bd=38;2;219;188;127:cd=38;2;219;188;127;1:ow=38;2;219;188;127;1:tw=38;2;127;187;179:st=38;2;127;187;179:fi=0:no=0:*.7z=38;2;230;152;117:*.zip=38;2;230;152;117:*.rar=38;2;230;152;117:*.tar=38;2;230;152;117:*.gz=38;2;230;152;117:*.tgz=38;2;230;152;117:*.xz=38;2;230;152;117:*.bz2=38;2;230;152;117:*.zst=38;2;230;152;117:*.cab=38;2;230;152;117:*.iso=38;2;230;152;117:*.jar=38;2;230;152;117:*.png=38;2;214;153;182:*.jpg=38;2;214;153;182:*.jpeg=38;2;214;153;182:*.gif=38;2;214;153;182:*.bmp=38;2;214;153;182:*.svg=38;2;214;153;182:*.ico=38;2;214;153;182:*.webp=38;2;214;153;182:*.mp4=38;2;127;187;179:*.mkv=38;2;127;187;179:*.avi=38;2;127;187;179:*.mov=38;2;127;187;179:*.mp3=38;2;131;192;146;1:*.wav=38;2;131;192;146;1:*.flac=38;2;131;192;146;1:*.ogg=38;2;131;192;146;1:*.pdf=38;2;127;187;179:*.doc=38;2;127;187;179:*.docx=38;2;127;187;179:*.xls=38;2;127;187;179:*.xlsx=38;2;127;187;179:*.ppt=38;2;127;187;179:*.pptx=38;2;127;187;179:*.md=38;2;255;95;215:*.txt=38;2;211;198;170:*.csv=38;2;127;187;179:*.py=38;2;131;192;146:*.js=38;2;131;192;146;1:*.ts=38;2;131;192;146;1:*.go=38;2;131;192;146:*.rs=38;2;131;192;146:*.c=38;2;131;192;146:*.cpp=38;2;131;192;146:*.h=38;2;131;192;146:*.cs=38;2;131;192;146:*.java=38;2;131;192;146;1:*.sql=38;2;131;192;146:*.html=38;2;230;152;117;1:*.css=38;2;131;192;146;1:*.json=38;2;95;175;255:*.yaml=38;2;95;215;215:*.yml=38;2;95;215;215:*.toml=38;2;219;188;127:*.xml=38;2;219;188;127:*.ini=1:*.sh=38;2;167;192;128:*.bat=38;2;167;192;128:*.pem=38;2;230;126;128;3:*.p12=38;2;230;126;128;3:*.log=38;2;122;132;120:*.tmp=38;2;122;132;120:*.bak=38;2;122;132;120:*.dll=38;2;122;132;120:*.exe=1;38;2;167;192;128:*.cmd=1;38;2;167;192;128:*.ps1=1;38;2;167;192;128:*.msi=1;38;2;167;192;128'
$EzaColorsValue = 'oc=38;2;122;132;120:ur=38;2;219;188;127:uw=38;2;230;126;128:ux=38;2;167;192;128:ue=38;2;167;192;128:gr=38;2;219;188;127:gw=38;2;230;126;128:gx=38;2;167;192;128:tr=38;2;219;188;127:tw=38;2;230;126;128:tx=38;2;167;192;128:su=38;2;214;153;182:sf=38;2;214;153;182:xa=38;2;133;146;137:nb=38;2;157;169;160:nk=38;2;131;192;146:nm=38;2;219;188;127:ng=38;2;230;152;117:nt=38;2;230;126;128:sb=38;2;133;146;137:uu=38;2;219;188;127:uR=38;2;230;152;117:un=38;2;157;169;160:gu=38;2;157;169;160:gR=38;2;157;169;160:gn=38;2;157;169;160:da=38;2;127;187;179:ga=38;2;167;192;128:gm=38;2;219;188;127:gd=38;2;230;126;128:gv=38;2;214;153;182:gt=38;2;131;192;146:gi=38;2;122;132;120:gc=1;38;2;230;126;128:lc=38;2;133;146;137:lm=38;2;133;146;137:in=38;2;133;146;137:bl=38;2;133;146;137:df=38;2;133;146;137:ds=38;2;133;146;137:hd=38;2;157;169;160:lp=38;2;131;192;146:xx=38;2;122;132;120'
# Переменная окружения пользователя: ставится, только если своей нет;
# State.<Name>Set - что её поставил скрипт (для отката)
function Set-UserEnvColors {
    param($State, [string] $Name, [string] $Value)
    $flag = "${Name}Set" -replace '_', ''
    if ($Value.Length -gt 2047) { Warn "$Name not set: $($Value.Length) characters, Windows passes at most 2047 to new windows"; return }
    $cur = [Environment]::GetEnvironmentVariable($Name, 'User')
    if ($cur -and -not $State.$flag) { Ok "$Name - your own value is set, left alone"; return }
    if ($cur -eq $Value) { Ok "$Name - set"; return }
    [Environment]::SetEnvironmentVariable($Name, $Value, 'User')
    Set-Item -Path "Env:$Name" -Value $Value
    $State | Add-Member -NotePropertyName $flag -NotePropertyValue $true -Force; Save-State $State
    $script:Changed = $true
    Ok "$Name set (new windows)"
}
# lsd: подпись у ссылки - '.\'  ⇒ link to  C:\ProgramData. Параметр
# symlink-arrow (doc/samples/config-sample.yaml lsd). lsd ищет config.yaml в
# %USERPROFILE%\.config\lsd, потом в %APPDATA%\lsd; есть свой - не трогать.
$LsdConfigFile = Join-Path $env:APPDATA 'lsd\config.yaml'
$LsdConfigText = "# Install-LinuxTools: lsd settings`nsymlink-arrow: `"$([char]0x21D2) link to`"`n"
function Set-LsdConfig {
    param($State)
    $own = @((Join-Path $env:USERPROFILE '.config\lsd\config.yaml'), $LsdConfigFile) | Where-Object { Test-Path -LiteralPath $_ }
    if ($own -and -not $State.LsdConfig) { Ok "lsd config - your own file is there, left alone: $($own[0])"; return }
    $dir = Split-Path -Parent $LsdConfigFile
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    [IO.File]::WriteAllText($LsdConfigFile, $LsdConfigText)     # UTF-8 без BOM
    if (-not $State.LsdConfig) { $State | Add-Member -NotePropertyName LsdConfig -NotePropertyValue $true -Force; Save-State $State }
    Ok "lsd: links shown as  name $([char]0x21D2) link to target"
}
function Set-LsColors {
    param($State)
    Set-UserEnvColors $State 'LS_COLORS' $LsColorsValue
    Set-UserEnvColors $State 'EZA_COLORS' $EzaColorsValue
    if ((Get-ScoopInstalled) -contains 'lsd') { Set-LsdConfig $State }
}
function Remove-LsColors {
    param($State)
    $done = @()
    foreach ($n in 'LS_COLORS', 'EZA_COLORS') {
        $flag = "${n}Set" -replace '_', ''
        if (-not $State.$flag) { continue }
        [Environment]::SetEnvironmentVariable($n, $null, 'User')
        Ok "removed: $n"; $done += $n
    }
    if ($State.LsdConfig -and (Test-Path -LiteralPath $LsdConfigFile)) {
        Remove-Item -LiteralPath $LsdConfigFile -Force -ErrorAction SilentlyContinue
        Ok "removed: $LsdConfigFile"; $done += 'lsd config'
    }
    return $done
}

# Серая подсказка из истории в PowerShell (-LinuxFirst): PSReadLine
# PredictionSource History - с версии 2.1, а Windows PowerShell 5.1 приходит
# с 2.0.0. Свежий PSReadLine - с PSGallery для текущего пользователя
# (Documents\WindowsPowerShell\Modules, в PSModulePath раньше встроенного),
# как велит README PSReadLine. Ставит отдельный powershell.exe -NoProfile:
# скрипт мог быть запущен из pwsh 7 со своей папкой модулей. Свой PSReadLine
# 2.1+ не трогается. State.PSReadLine - поставленные скриптом версии.
$WinPs   = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$PsModDir = Join-Path $Docs 'WindowsPowerShell\Modules'
# Модули PSGallery для -LinuxFirst: имя -> минимальная версия, которой
# достаточно (свой модуль не ниже неё не трогается). posh-git - ветка и
# изменения git в приглашении, Tab по командам git; PSFzf - Ctrl+R (история)
# и Ctrl+T (файлы) через fzf (пакет Scoop fzf).
$GalleryModules = [ordered]@{ 'PSReadLine' = '2.1'; 'posh-git' = '1.0'; 'PSFzf' = '2.0' }
function Get-ModVersions {
    param([string] $Name)
    $d = Join-Path $PsModDir $Name
    if (-not (Test-Path -LiteralPath $d)) { return @() }
    return @(Get-ChildItem -LiteralPath $d -Directory | ForEach-Object { try { [version]$_.Name } catch { } } | Sort-Object -Descending)
}
# Свои версии модуля: State.GalleryModules ("Имя/версия"), для PSReadLine
# ещё State.PSReadLine (так записывали версии до 2026-10-31)
function Get-OurModVersions {
    param($State, [string] $Name)
    $v = @($State.GalleryModules | Where-Object { $_ -like "$Name/*" } | ForEach-Object { $_.Split('/')[1] })
    if ($Name -eq 'PSReadLine') { $v += @($State.PSReadLine | Where-Object { $_ }) }
    return $v
}
function Install-GalleryModule {
    param($State, [string] $Name, [version] $Min)
    if (-not $State.PSObject.Properties['GalleryModules']) { $State | Add-Member -NotePropertyName GalleryModules -NotePropertyValue @() }
    $before = Get-ModVersions $Name
    if ($before.Count -and $before[0] -ge $Min -and -not (Get-OurModVersions $State $Name).Count) { Ok "$Name $($before[0]) - yours, left alone"; return }
    $dir = (Join-Path $PsModDir $Name).Replace("'", "''")
    $cmd = "[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072; `$ProgressPreference = 'SilentlyContinue'; " +
           "Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Scope CurrentUser -Force | Out-Null; " +
           "`$v = (Find-Module $Name -Repository PSGallery -ErrorAction Stop).Version; " +
           "if (-not (Test-Path (Join-Path '$dir' `$v))) { Install-Module $Name -RequiredVersion `$v -Repository PSGallery -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop }"
    Write-Host "  ...  $Name from PSGallery"
    $eap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try { $out = (& $WinPs -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command $cmd 2>&1 | Out-String).Trim() }
    finally { $ErrorActionPreference = $eap }
    $after = Get-ModVersions $Name
    if (-not $after.Count -or $after[0] -lt $Min) {
        Warn "$Name not installed: $out"
        Add-Step 60 "$Name for PowerShell: in Windows PowerShell run  Install-Module $Name -Repository PSGallery -Scope CurrentUser -Force  then open a new window"
        return
    }
    $new = @($after | Where-Object { $before -notcontains $_ } | ForEach-Object { "$Name/$_" })
    if ($new.Count) { $State.GalleryModules = @(@($State.GalleryModules | Where-Object { $_ }) + $new); Save-State $State; $script:Changed = $true; Ok "$Name $($after[0]) installed (new windows)" }
    else { Ok "$Name $($after[0]) - up to date" }
}
# Серая подсказка из истории (PSReadLine 2.1+: Windows PowerShell 5.1
# приходит с 2.0.0), posh-git, fzf + PSFzf - для -LinuxFirst. Модули ставит
# отдельный powershell.exe -NoProfile в Documents\WindowsPowerShell\Modules
# (как велят README PSReadLine и posh-git): скрипт мог быть запущен из pwsh 7.
function Install-ShellModules {
    param($State)
    Install-ScoopPackage 'fzf' $null $State
    foreach ($n in $GalleryModules.Keys) { Install-GalleryModule $State $n ([version]$GalleryModules[$n]) }
}
function Remove-ShellModules {
    param($State)
    $done = @()
    foreach ($n in $GalleryModules.Keys) {
        foreach ($v in @(Get-OurModVersions $State $n)) {
            $d = Join-Path (Join-Path $PsModDir $n) $v
            if (Test-Path -LiteralPath $d) { Remove-Item -LiteralPath $d -Recurse -Force -ErrorAction SilentlyContinue }
            if (Test-Path -LiteralPath $d) {
                Warn "$n $v is in use by an open PowerShell window"
                Add-Step 85 "Close all PowerShell windows, then in cmd:  rmdir /s /q `"$d`""
            } else { Ok "removed: $n $v"; $done += "$n $v" }
        }
        $md = Join-Path $PsModDir $n
        if ((Test-Path -LiteralPath $md) -and -not @(Get-ChildItem -LiteralPath $md -Force).Count) { Remove-Item -LiteralPath $md -Force -ErrorAction SilentlyContinue }
    }
    return $done
}
# clink (-WithClink): bash-подобная строка в cmd - серая подсказка из
# истории (autosuggest.enable), Tab-меню, поиск, и макросы doskey работают
# после | и &. Запуск с cmd - clink autorun install (AutoRun в HKCU) из
# apps\clink\current: путь current Scoop переводит на новую версию. Свой
# clink в AutoRun (не из пакета скрипта) не трогается.
function Get-ClinkBat { return (Join-Path $ScoopRoot 'apps\clink\current\clink.bat') }
function Get-CmdAutoRun { return "$((Get-ItemProperty -Path $CmdKey -Name AutoRun -ErrorAction SilentlyContinue).AutoRun)" }
function Install-Clink {
    param($State)
    if ((Get-CmdAutoRun) -match 'clink' -and @($State.Packages) -notcontains 'clink') { Ok 'clink - yours is already in cmd AutoRun, left alone'; return }
    Install-ScoopPackage 'clink' $null $State
    $bat = Get-ClinkBat
    if (-not (Test-Path -LiteralPath $bat)) { return }
    $eap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try {
        if ((Get-CmdAutoRun) -notmatch 'clink') { & $bat autorun install 2>&1 | Out-Null }
        & $bat set autosuggest.enable true 2>&1 | Out-Null
        # Клавиши Windows (Tab, Ctrl+F, Ctrl+M...) - как ставит установщик clink
        # с enhanced default settings
        & $bat set clink.default_bindings windows 2>&1 | Out-Null
    } finally { $ErrorActionPreference = $eap }
    if ((Get-CmdAutoRun) -notmatch 'clink') {
        Warn 'clink is installed but not started with cmd'
        Add-Step 60 "Start clink with every cmd window: in cmd run  `"$bat`" autorun install"
        return
    }
    # Свои макросы - первыми в AutoRun (clink мог переписать значение)
    if ($State.CmdAutoRunSet) { Set-CmdMacros $State }
    Set-ClinkInputrc $State
    Ok 'clink: starts with every cmd window, grey hints from history (Right arrow accepts)'
}
# Стрелки вверх/вниз в clink - история по набранному началу (как PgUp/PgDn;
# пустая строка - вся история). Tab / Shift+Tab - следующее / предыдущее
# совпадение прямо в строке, как в PowerShell и обычном cmd (без clink Tab
# показывал бы список под строкой, как bash). Блок с метками - в первом найденном
# .inputrc/_inputrc из порядка поиска clink (%CLINK_INPUTRC%, %USERPROFILE%,
# %LOCALAPPDATA%, %APPDATA%), нет такого - в %USERPROFILE%\.inputrc.
# Метка не меняется: по ней находится блок, записанный прошлыми версиями
$InputrcBegin = '# >>> Install-LinuxTools: Up/Down search history by the typed start >>>'
$InputrcEnd   = '# <<< Install-LinuxTools <<<'
function Get-InputrcFile {
    foreach ($d in @($env:CLINK_INPUTRC, $env:USERPROFILE, $env:LOCALAPPDATA, $env:APPDATA) | Where-Object { $_ }) {
        foreach ($n in '.inputrc', '_inputrc') { $f = Join-Path $d $n; if (Test-Path -LiteralPath $f) { return $f } }
    }
    return (Join-Path $env:USERPROFILE '.inputrc')
}
function Remove-InputrcBlock {
    param([string] $File)
    if (-not $File -or -not (Test-Path -LiteralPath $File)) { return }
    $text = [IO.File]::ReadAllText($File)
    $new = [regex]::Replace($text, "(?s)\r?\n*$([regex]::Escape($InputrcBegin)).*?$([regex]::Escape($InputrcEnd))\r?\n?", "`n").Trim()
    if (-not $new) { Remove-Item -LiteralPath $File -Force } else { [IO.File]::WriteAllText($File, $new + "`n") }
}
function Set-ClinkInputrc {
    param($State)
    $file = if ($State.ClinkInputrc) { $State.ClinkInputrc } else { Get-InputrcFile }
    Remove-InputrcBlock $file
    $block = @($InputrcBegin, '$if clink', '"\e[A": history-search-backward', '"\e[B": history-search-forward',
               '"\t": old-menu-complete', '"\e[Z": old-menu-complete-backward', '$endif', $InputrcEnd) -join "`n"
    $text = if (Test-Path -LiteralPath $file) { [IO.File]::ReadAllText($file).TrimEnd() + "`n`n" } else { '' }
    [IO.File]::WriteAllText($file, $text + $block + "`n")     # без BOM
    if ($State.ClinkInputrc -ne $file) { $State | Add-Member -NotePropertyName ClinkInputrc -NotePropertyValue $file -Force; Save-State $State }
    Ok "clink: Up/Down search history by the typed start, Tab cycles matches ($file)"
}
function Remove-Clink {
    param($State)
    if (@($State.Packages) -notcontains 'clink') { return @() }
    $keys = @()
    if ($State.ClinkInputrc) { Remove-InputrcBlock $State.ClinkInputrc; Ok "removed: clink keys in $($State.ClinkInputrc)"; $keys = @('clink keys'); $State.PSObject.Properties.Remove('ClinkInputrc'); Save-State $State }
    $bat = Get-ClinkBat
    if ((Test-Path -LiteralPath $bat) -and (Get-CmdAutoRun) -match 'clink') {
        $eap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        try { & $bat autorun uninstall 2>&1 | Out-Null } finally { $ErrorActionPreference = $eap }
    }
    if ((Get-CmdAutoRun) -match 'clink') { Warn 'clink is still in cmd AutoRun'; Add-Step 80 'Remove clink from cmd: in cmd run  clink autorun uninstall' ; return @() }
    Ok 'removed: clink from cmd AutoRun'
    $done = $keys + @('clink autorun')
    # Настройки и история clink (state directory из clink info): clink ставил
    # скрипт - удаляются вместе с ним. Открытые окна cmd держат файлы. Перед
    # удалением - копия в backup\clink_<дата-время> рядом со скриптом (папка
    # только для чтения - в %TEMP%); в истории могут быть пароли из команд,
    # поэтому backup\ в .gitignore.
    $data = Join-Path $env:LOCALAPPDATA 'clink'
    if (Test-Path -LiteralPath $data) {
        $copy = $null
        foreach ($root in @((Join-Path (Split-Path -Parent $LogFile) 'backup'), (Join-Path $env:TEMP 'Install-LinuxTools-backup'))) {
            $dest = Join-Path $root "clink_$(Get-Date -Format yyyyMMdd-HHmmss)"
            try {
                New-Item -ItemType Directory -Force -Path $dest -ErrorAction Stop | Out-Null
                Copy-Item -Path (Join-Path $data '*') -Destination $dest -Recurse -Force -ErrorAction Stop
                $copy = $dest; break
            } catch { Remove-Item -LiteralPath $dest -Recurse -Force -ErrorAction SilentlyContinue }
        }
        if (-not $copy) { Warn "clink settings and history not removed: could not back them up ($data)"; return $done }
        Ok "clink settings and history backed up: $copy"
        Remove-Item -LiteralPath $data -Recurse -Force -ErrorAction SilentlyContinue
        if (Test-Path -LiteralPath $data) {
            Warn "clink settings and history are in use: $data"
            Add-Step 85 "Close all cmd windows, then in PowerShell:  Remove-Item -Recurse -Force `"$data`""
        } else { Ok "removed: clink settings and history ($data)"; $done += 'clink settings and history' }
    }
    Add-Step 90 'cmd windows that are open now keep clink until you close them'
    return $done
}

# Far и nmap - по выбору: ставятся по -WithFar/-WithNmap; уже стоящие
# (выбраны раньше или поставлены не скриптом) обслуживаются как остальные.
function Install-AllPackages {
    param($State, [string] $N2 = '', [string] $N3 = '', [switch] $AddFar, [switch] $AddNmap, [switch] $AddClink)
    $have = Get-ScoopInstalled
    Say "${N2}Text and file tools"
    foreach ($p in @('uutils-coreutils', 'uutils-findutils', 'grep', 'gawk', 'sed', 'less', 'jq', 'which', 'ripgrep', 'fd', 'lsd',
                     'ugrep', 'bat', 'eza', 'dust', 'gdu', 'duf', 'bottom', 'procs', 'gsudo')) {
        Install-ScoopPackage $p $null $State
    }
    if ($AddFar -or $have -contains 'far') { Install-ScoopPackage 'far' $null $State; Install-FarExtras $State }
    else { Write-Host '  --   far not installed (add it with -WithFar)' }

    Say "${N3}Network tools"
    foreach ($p in @('bind', 'trippy', 'xh', 'curl', 'wget')) { Install-ScoopPackage $p $null $State }
    if (-not (Test-Path -LiteralPath $WhoisJson)) {
        # Проверено 2026-10-29: архив совпал с опубликованным .sha256
        Write-WhoisManifest '1.15.7' 'd310306fe99f2cf742fcbd7f4645de7827656597daee929e0e3ee9e3eda817bb'
    }
    Install-ScoopPackage 'whois' $WhoisJson $State
    if ($AddNmap -or $have -contains 'nmap') {
        Install-ScoopPackage 'nmap' $null $State
        if ((Get-ScoopInstalled) -contains 'nmap') { Install-Npcap $State }
    } else { Write-Host '  --   nmap not installed (add it with -WithNmap)' }
    if ($AddClink -or $have -contains 'clink') { Install-Clink $State }
    else { Write-Host '  --   clink not installed (add it with -WithClink)' }
    Add-AliasShims $State
    Set-LsColors $State
    Update-SessionPath
}

Start-Log

# =============================================================================
#  -Uninstall
# =============================================================================
# -Uninstall -WithFar / -WithNmap: убрать только это дополнение, остальное
# остаётся. Far - с откатом его настроек, плагинов, темы, ярлыка и обёртки far;
# nmap - с ярлыком nc. Npcap остаётся, как и при полном удалении.
if ($Uninstall -and ($WithFar -or $WithNmap -or $WithClink)) {
    $ErrorActionPreference = 'Continue'
    if (-not (Test-Path -LiteralPath $StateFile)) { Warn "Nothing recorded in $StateFile - nothing to roll back."; Finish 0 }
    $st = Get-State
    $removed = @(); $kept = @()
    Say 'Rollback'
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) { Warn 'Scoop not found - nothing to remove.'; Finish 1 }
    # Список - по одному элементу: выражение @($(if ...), ... | Where-Object)
    # в Windows PowerShell 5.1 дало пустой список при -Uninstall -WithClink
    $parts = @()
    if ($WithFar)   { $parts += 'far' }
    if ($WithNmap)  { $parts += 'nmap' }
    if ($WithClink) { $parts += 'clink' }
    Write-Host "  ...  remove only: $($parts -join ', ')"
    foreach ($p in $parts) {
        if (@($st.Packages) -notcontains $p) { Ok "$p - not installed by this script, left alone"; $kept += "$p (not installed by this script)"; continue }
        if ($p -eq 'far') {
            if (Test-FarRunning) { Warn 'far not removed: Far Manager is running. Close it and run the command again.'; continue }
            $removed += @(Remove-FarExtras $st)
            $removed += @(Remove-FarDesktopLink $st)
            if ($st.FarLastDir) { Remove-FarProfileBlock }
            # Записи о Far - прочь: следующий -WithFar поставит всё заново
            foreach ($n in @($st.PSObject.Properties.Name | Where-Object { $_ -like 'Far*' })) { $st.PSObject.Properties.Remove($n) }
            Remove-Item -LiteralPath (Join-Path $Home2 'far-before.farconfig') -Force -ErrorAction SilentlyContinue
            Save-State $st
            # Макрос far в cmd больше не нужен
            if ($st.CmdAutoRunSet) {
                if ($st.ProfileBlock) { Set-CmdMacros $st }
                else { Remove-CmdMacros $st; $st.CmdAutoRunSet = $false; Save-State $st; $removed += 'cmd macros' }
            }
        }
        if ($p -eq 'clink') { $removed += @(Remove-Clink $st) }
        if ($p -eq 'nmap' -and @($st.Shims) -contains 'nc') {
            if (Test-Path -LiteralPath (Join-Path $ShimDir 'nc.shim')) { scoop shim rm nc 6>$null | Out-Null }
            if (Test-Path -LiteralPath (Join-Path $ShimDir 'nc.shim')) { Warn 'nc - could not remove the shim' }
            else { Ok 'removed: nc'; $removed += 'nc'; $st.Shims = @($st.Shims | Where-Object { $_ -ne 'nc' }); Save-State $st }
        }
        if ((Get-ScoopInstalled) -contains $p) { scoop uninstall $p | Out-Host }
        if ((Get-ScoopInstalled) -contains $p) { Warn "$p - could not be removed, see the scoop messages above"; continue }
        Ok "removed: $p"; $removed += $p
        $st.Packages = @($st.Packages | Where-Object { $_ -ne $p }); Save-State $st
        if ($p -eq 'far' -and (Test-Path -LiteralPath (Join-Path $ScoopRoot 'persist\far'))) {
            $kept += "Far settings in $(Join-Path $ScoopRoot 'persist\far') (delete the folder to remove them)"
        }
        if ($p -eq 'nmap' -and @($st.SystemInstalled) -contains 'Npcap') { $kept += 'Npcap (system component; remove it in Windows Settings > Apps if needed)' }
    }
    Add-Step 90 'Open a new PowerShell or cmd window: old windows still have the old aliases'
    Finish 0 @(
        @{ Title = 'Removed'; Color = 'Green'; Items = $removed }
        @{ Title = 'Kept';    Color = 'Gray';  Items = $kept }
    )
}
if ($Uninstall) {
    $ErrorActionPreference = 'Continue'
    if (-not (Test-Path -LiteralPath $StateFile)) { Warn "Nothing recorded in $StateFile - nothing to roll back."; Finish 0 }
    $st = Get-State
    $removed = @(); $kept = @()
    Say 'Rollback'
    if ($st.ProfileBlock) { Remove-ProfileBlock; $removed += 'PowerShell profile block' }
    if ($st.CmdAutoRunSet) { Remove-CmdMacros $st; $removed += 'cmd macros' }
    if ($st.FarLastDir) { Remove-FarProfileBlock }
    $removed += @(Remove-FarDesktopLink $st)
    $removed += @(Remove-LsColors $st)
    $removed += @(Remove-ShellModules $st)
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        $removed += @(Remove-Clink $st)
        $removed += @(Remove-FarExtras $st)
        foreach ($n in @($st.Shims)) {
            if (Test-Path -LiteralPath (Join-Path $ShimDir "$n.shim")) { scoop shim rm $n 6>$null | Out-Null }
            if (Test-Path -LiteralPath (Join-Path $ShimDir "$n.shim")) { Warn "$n - could not remove the shim" } else { Ok "removed: $n"; $removed += $n }
        }
        # git остаётся: им могут пользоваться и для своих репозиториев
        $keepGit = @($st.Packages) -contains 'git' -and (Get-ScoopInstalled) -contains 'git'
        if ($keepGit) { Ok 'git kept'; $kept += 'git (remove it with: scoop uninstall git)' }
        foreach ($p in @($st.Packages | Where-Object { $_ -ne 'git' })) {
            if ((Get-ScoopInstalled) -contains $p) { scoop uninstall $p | Out-Host }
            if ((Get-ScoopInstalled) -contains $p) { Warn "$p - could not be removed, see the scoop messages above" }
            else { Ok "removed: $p"; $removed += $p }
        }
        $left = @(Get-ScoopInstalled | Where-Object { $_ -ne 'scoop' })
        if ($st.ScoopInstalledByUs -and -not $left.Count) {
            Write-Host '  ...  Scoop itself - answer y to "Are you sure? (yN)"' -ForegroundColor Magenta
            scoop uninstall scoop -p | Out-Host
            Ok 'Scoop removed (it was installed by this script and has no other packages)'; $removed += 'Scoop'
        } elseif ($st.ScoopInstalledByUs -and $keepGit -and $left.Count -eq 1) {
            # Остался только оставленный git: Scoop нужен ему
            $kept += 'Scoop (git lives in it; to remove both: scoop uninstall git, then scoop uninstall scoop)'
        } elseif ($st.ScoopInstalledByUs) {
            Warn "Scoop kept: it has other packages now: $($left -join ', ')"; $kept += 'Scoop (it has other packages)'
        } else { $kept += 'Scoop (it was there before this script)' }
    }
    # Системные компоненты (Visual C++, Npcap) остаются: откат убирает только
    # утилиты и связи с ними, а библиотеками и драйвером пользуются и другие программы
    foreach ($s in @($st.SystemInstalled)) { $kept += "$s (system component; remove it in Windows Settings > Apps if needed)" }
    # Scoop оставляет сохранённые данные пакетов (persist): у far там профиль с настройками
    if (@($st.Packages) -contains 'far' -and (Test-Path -LiteralPath (Join-Path $ScoopRoot 'persist\far'))) {
        $kept += "Far settings in $(Join-Path $ScoopRoot 'persist\far') (delete the folder to remove them)"
    }
    if ($st.ExecPolicyBefore) {
        Set-ExecutionPolicy -ExecutionPolicy $st.ExecPolicyBefore -Scope CurrentUser -Force -ErrorAction SilentlyContinue
        Ok "execution policy for this user restored: $($st.ExecPolicyBefore)"; $removed += 'execution policy change'
    }
    Remove-Item -LiteralPath $Home2 -Recurse -Force -ErrorAction SilentlyContinue
    Add-Step 90 'Open a new PowerShell or cmd window: old windows still have the old PATH and aliases'
    Finish 0 @(
        @{ Title = 'Removed'; Color = 'Green'; Items = $removed }
        @{ Title = 'Kept';    Color = 'Gray';  Items = $kept }
    )
}

# =============================================================================
#  -Update
# =============================================================================
if ($Update) {
    $ErrorActionPreference = 'Continue'
    $st = Get-State
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        Add-Step 10 'Install first:' @('.\Install-LinuxTools.ps1')
        Finish 1
    }
    Say 'Update'
    Assert-Git $st
    scoop update 6>$null | Out-Null; Ok 'Scoop and its package lists'
    if (@($st.Packages) -contains 'whois') {
        try {
            $w = Get-WhoisLatest
            Write-WhoisManifest $w.Version $w.Hash
            Ok "whois manifest: $($w.Version)"
        } catch { Warn "whois: could not check the latest release - $($_.Exception.Message)" }
    }
    foreach ($p in @($st.Packages)) {
        # Запущенный Far Scoop не обновит: файлы заняты
        if ($p -eq 'far' -and (Test-FarRunning)) { Warn 'far not updated: Far Manager is running. Close it and run -Update again.'; continue }
        scoop update $p | Out-Host; Ok "checked: $p"
    }
    # Пакеты, которых ещё нет (добавлены в скрипт после установки), - доставить
    Install-AllPackages $st
    if ($st.CmdAutoRunSet -or $st.FarLastDir) { Set-CmdMacros $st }   # новые утилиты могли добавить имена
    if ($st.ProfileBlock) {
        # Блок профиля из прошлых версий скрипта - без серой подсказки
        if (-not (Select-String -LiteralPath $Profiles[0] -SimpleMatch 'PSFzf' -Quiet -ErrorAction SilentlyContinue)) { Add-ProfileBlock }
        Install-ShellModules $st
    }
    Say 'Check'
    $rows = Invoke-Check $st $(if ((Get-ScoopInstalled) -notcontains 'nmap') { @('nmap', 'ncat', 'nc') } else { @() })
    Add-UsageNotes $rows $st
    $clean = -not $script:Warnings.Count -and -not @($rows | Where-Object Status -ne 'ok').Count
    Finish 0 (Get-CheckSections $rows) $(if ($clean) { Get-InstalledList } else { @() })
}

# =============================================================================
#  Установка
# =============================================================================
$st = Get-State

Say '1/5 Visual C++ 2015-2022 x64 (uutils needs it), Scoop and git'
# Без неё не запустится большая часть утилит - ставится первой; не вышло -
# остановка до любых других изменений
if (Test-VcRuntime 'x64') { Ok "Visual C++ 2015-2022 x64: $(Join-Path (Get-SysDir 'x64') 'vcruntime140.dll')" }
elseif (-not (Install-VcRedist 'x64' $st)) {
    Write-Host "`nSTOP: Visual C++ 2015-2022 x64 could not be installed automatically. Nothing else was changed." -ForegroundColor Red
    Add-VcStep 'x64' @('ls', 'cat', 'find', '... (uutils)')
    Add-Step 80 'Then run this script again:' @('.\Install-LinuxTools.ps1')
    Finish 2
}
if (Get-Command scoop -ErrorAction SilentlyContinue) {
    Ok 'Scoop already installed (left alone on -Uninstall)'
} else {
    # Установщику Scoop нужна политика RemoteSigned для текущего пользователя -
    # так велит его документация. Политика всего компьютера не меняется.
    $pol = [string](Get-ExecutionPolicy -Scope CurrentUser)
    if ($pol -notin @('RemoteSigned', 'Unrestricted', 'Bypass')) {
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        $st.ExecPolicyBefore = $pol; Save-State $st
        Ok "execution policy for this user: $pol -> RemoteSigned"
    }
    # Из окна администратора установщик по умолчанию отказывается. При
    # выключенном UAC администратор всегда с правами - тогда -RunAsAdmin,
    # как велит документация Scoop
    try {
        if (Test-Admin) {
            Write-Host '  ...  administrator window: installing Scoop with -RunAsAdmin'
            Invoke-Expression "& {$(Invoke-RestMethod -Uri 'https://get.scoop.sh')} -RunAsAdmin"
        } else {
            Invoke-RestMethod -Uri 'https://get.scoop.sh' | Invoke-Expression
        }
    } catch { Warn "Scoop installer failed: $($_.Exception.Message)" }
    Update-SessionPath
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        Add-Step 10 'Scoop did not install. Check that this address opens in a browser:' @('https://get.scoop.sh')
        Add-Step 80 'Then run this script again:' @('.\Install-LinuxTools.ps1')
        Finish 1
    }
    $st.ScoopInstalledByUs = $true; Save-State $st; $script:Changed = $true
    Ok 'Scoop installed'
}
Assert-Git $st

# Дальше - мягкий режим ошибок: в Windows PowerShell 5.1 при 'Stop' любая
# строка программы в stderr становится ошибкой и обрывает скрипт
$ErrorActionPreference = 'Continue'

Install-AllPackages $st '2/5 ' '3/5 ' -AddFar:$WithFar -AddNmap:$WithNmap -AddClink:$WithClink

Say '4/5 Linux names first (PowerShell and cmd)'
if ($LinuxFirst) {
    Add-ProfileBlock; $st.ProfileBlock = $true; Save-State $st
    Install-ShellModules $st
} else {
    Write-Host '  --   skipped (run with -LinuxFirst to make ls, cat, find, sort, mtr, nc... open the Linux tools)'
}
# Макросы cmd: Linux-имена (-LinuxFirst) и обёртка far
if ($st.ProfileBlock -or $st.FarLastDir) { Set-CmdMacros $st }

Say '5/5 Check (missing libraries are installed here)'
$rows = Invoke-Check $st $(if ((Get-ScoopInstalled) -notcontains 'nmap') { @('nmap', 'ncat', 'nc') } else { @() })
Add-UsageNotes $rows $st
$clean = -not $script:Warnings.Count -and -not @($rows | Where-Object Status -ne 'ok').Count
Finish 0 (Get-CheckSections $rows) $(if ($clean) { Get-InstalledList } else { @() })
