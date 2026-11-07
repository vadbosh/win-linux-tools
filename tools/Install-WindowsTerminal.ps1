<#
.SYNOPSIS
    Install the latest Windows Terminal from GitHub as a system package, or
    remove it completely. Works without Microsoft Store and winget, for
    example on Windows 11 IoT LTSC.

.DESCRIPTION
    Install: the script takes the latest release of microsoft/terminal from
    the GitHub API, downloads its "PreinstallKit" zip and checks its SHA-256
    against the digest GitHub publishes. The kit holds the Windows Terminal
    package (.msixbundle), its license and the Microsoft.UI.Xaml dependency
    for each processor architecture. The script installs the dependency for
    this computer's architecture, then Windows Terminal, with
    Add-AppxPackage. This is the same package as the one from Microsoft
    Store. If the same or a newer version is installed, nothing is done.

    With -AllUsers the package is also provisioned for all users
    (Add-AppxProvisionedPackage). That needs administrator rights.

    -Remove removes Windows Terminal completely: the package for this user
    (Windows also deletes its settings folder), the provisioned package for
    all users if there is one, the dependencies this script installed if no
    other package uses them, and the "default terminal" choice if it points
    to Windows Terminal.

    A portable Windows Terminal (from Scoop, or from your own folder with a
    .portable file) is a separate program: this script neither installs nor
    removes it.

.PARAMETER Remove
    Remove Windows Terminal completely instead of installing it.

.PARAMETER AllUsers
    Install for all users (or, with -Remove, also remove the package
    provisioned for all users). Needs administrator rights.

.PARAMETER Help
    Show a short help. --help, -h and /? do the same.

.PARAMETER Rest
    Not an option. It catches --help, /? and unknown arguments, so that the
    script can show the help instead of an error.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-WindowsTerminal.ps1

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-WindowsTerminal.ps1 -Remove
#>
[CmdletBinding()]
param(
    [switch]$Remove,
    [switch]$AllUsers,
    # Не для запуска руками: так скрипт помечает свой второй запуск через UAC
    [Parameter(DontShow)] [switch]$Elevated,
    [switch]$Help,
    # --help, /? и всё остальное, чего PowerShell не узнал как ключ
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)] [string[]]$Rest
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
# Windows PowerShell 5.1 по умолчанию может не предлагать TLS 1.2 - GitHub без него не отвечает
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

if ($Help -or $Rest) {
    $helpWords = @('--help', '-help', '--h', '-h', '/?', '/h', '/help', '-?', '?', 'help')
    $unknown = @($Rest | Where-Object { $_ -and $helpWords -notcontains $_ })
    if ($unknown.Count) { Write-Host "Unknown argument: $($unknown -join ' ')`n" -ForegroundColor Red }
    Write-Host @'
Install-WindowsTerminal.ps1 - install the latest Windows Terminal from GitHub
as a system package, or remove it completely. No Microsoft Store or winget
needed (for example on Windows 11 IoT LTSC).

Usage:
    .\Install-WindowsTerminal.ps1              install or update, this user
    .\Install-WindowsTerminal.ps1 -AllUsers    also for all users (admin)
    .\Install-WindowsTerminal.ps1 -Remove      remove completely
If running scripts is blocked, or in cmd:
    powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-WindowsTerminal.ps1 [...]

The download is checked against the SHA-256 that GitHub publishes. The same
or a newer installed version is left as it is. -Remove also removes the
dependencies this script installed and resets the "default terminal" choice
if it points to Windows Terminal. A portable Windows Terminal (Scoop, your
own folder) is not touched.
After the install, open Windows Terminal once; then Install-LinuxTools.ps1
-Update can apply its settings.
Full help:  Get-Help .\Install-WindowsTerminal.ps1 -Full
'@
    exit $(if ($unknown.Count) { 1 } else { 0 })
}

$Repo     = 'microsoft/terminal'
$PkgName  = 'Microsoft.WindowsTerminal'
$StateDir = Join-Path $env:LOCALAPPDATA 'Install-WindowsTerminal'
$StateFile = Join-Path $StateDir 'state.json'
# "Терминал по умолчанию" (Параметры > Для разработчиков > Терминал): GUID
# Windows Terminal в HKCU\Console\%%Startup. После удаления Terminal они бы
# указывали в пустоту - вернуть "Windows решает" (нули)
$DelegKey      = 'HKCU:\Console\%%Startup'
$DelegConsole  = '{2EACA947-7F5F-4CFA-BA87-8F7FBEEFBE69}'
$DelegTerminal = '{E12CFF52-A866-4C77-9A90-F570A7AA2C6B}'
$DelegNone     = '{00000000-0000-0000-0000-000000000000}'

function Ok   { param([string] $Text) Write-Host "  OK   $Text" -ForegroundColor Green }
function Warn { param([string] $Text) Write-Host "  !!   $Text" -ForegroundColor Yellow }
function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    return ([Security.Principal.WindowsPrincipal]$id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
function Test-UacOff {
    $v = (Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name EnableLUA -ErrorAction SilentlyContinue).EnableLUA
    return ($null -ne $v -and [int]$v -eq 0)
}
function Finish {
    param([int] $Code)
    if ($Elevated) { Read-Host "`nPress Enter to close this window" | Out-Null }
    exit $Code
}
function Get-State {
    if (Test-Path -LiteralPath $StateFile) { return (Get-Content -LiteralPath $StateFile -Raw | ConvertFrom-Json) }
    return [PSCustomObject]@{ Deps = @() }
}
function Save-State {
    param($State)
    if (-not (Test-Path -LiteralPath $StateDir)) { New-Item -ItemType Directory -Force -Path $StateDir | Out-Null }
    $State | ConvertTo-Json | Set-Content -LiteralPath $StateFile -Encoding UTF8
}
function Get-Arch {
    switch ($env:PROCESSOR_ARCHITECTURE) { 'AMD64' { 'x64' } 'ARM64' { 'arm64' } 'x86' { if ($env:PROCESSOR_ARCHITEW6432 -eq 'AMD64') { 'x64' } else { 'x86' } } default { 'x64' } }
}

# -AllUsers без прав: тот же скрипт через UAC; при выключенном UAC у обычного
# пользователя - сказать, что нельзя
if ($AllUsers -and -not (Test-Admin)) {
    if (Test-UacOff) {
        Write-Host "User Account Control (UAC) is off, and $env:USERNAME is not an administrator:" -ForegroundColor Red
        Write-Host 'Windows cannot give administrator rights to this user. Run without -AllUsers, or as an administrator.' -ForegroundColor Red
        exit 1
    }
    if (-not $PSCommandPath) { Write-Host 'Run this from an administrator PowerShell.' -ForegroundColor Red; exit 1 }
    Write-Host 'Administrator rights needed for -AllUsers: Windows asks for them now.'
    $a = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-AllUsers', '-Elevated')
    if ($Remove) { $a += '-Remove' }
    try { $p = Start-Process -FilePath 'powershell.exe' -ArgumentList $a -Verb RunAs -Wait -PassThru }
    catch { Write-Host "Not started: $($_.Exception.Message)" -ForegroundColor Red; exit 1 }
    exit $p.ExitCode
}

# =============================================================================
#  -Remove: полностью
# =============================================================================
if ($Remove) {
    if (Get-Process WindowsTerminal -ErrorAction SilentlyContinue | Where-Object { $_.Path -like '*\WindowsApps\*' }) {
        Write-Host 'Windows Terminal is running. Close all its windows and run the script again (from a plain PowerShell window).' -ForegroundColor Red
        Finish 1
    }
    $state = Get-State
    $failed = 0
    $pk = @(Get-AppxPackage -Name $PkgName -ErrorAction SilentlyContinue)
    if (-not $pk.Count) { Write-Host "  --   $PkgName is not installed for $env:USERNAME" }
    foreach ($p in $pk) {
        try { Remove-AppxPackage -Package $p.PackageFullName; Ok "removed: $($p.Name) $($p.Version) (with its settings)" }
        catch { Warn "$($p.Name) $($p.Version) not removed: $($_.Exception.Message)"; $failed++ }
    }
    if ($AllUsers) {
        foreach ($pp in @(Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq $PkgName })) {
            try { Remove-AppxProvisionedPackage -Online -PackageName $pp.PackageName | Out-Null; Ok "removed for all users: $($pp.PackageName)" }
            catch { Warn "provisioned $($pp.PackageName) not removed: $($_.Exception.Message)"; $failed++ }
        }
        foreach ($p in @(Get-AppxPackage -AllUsers -Name $PkgName -ErrorAction SilentlyContinue)) {
            try { Remove-AppxPackage -Package $p.PackageFullName -AllUsers; Ok "removed for every user: $($p.PackageFullName)" }
            catch { Warn "$($p.PackageFullName) not removed for all users: $($_.Exception.Message)"; $failed++ }
        }
    } elseif (Get-Command Get-AppxProvisionedPackage -ErrorAction SilentlyContinue) {
        # Без прав список provisioned не читается - только подсказка
        if (Test-Admin) {
            if (@(Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq $PkgName }).Count) {
                Warn 'Windows Terminal is also provisioned for all users: run with -Remove -AllUsers to remove that too'
            }
        }
    }
    # Зависимости, которые поставил этот скрипт: если их держит другой
    # пакет, Windows не даст удалить - тогда остаются
    $left = @()
    foreach ($d in @($state.Deps | Where-Object { $_ })) {
        $dp = @(Get-AppxPackage -Name $d -ErrorAction SilentlyContinue)
        foreach ($p in $dp) {
            try { Remove-AppxPackage -Package $p.PackageFullName; Ok "removed: $($p.Name) $($p.Version) (installed by this script)" }
            catch { Write-Host "  --   $($p.Name) kept: another package uses it"; $left += $d }
        }
    }
    # Терминал по умолчанию
    $dc = (Get-ItemProperty -LiteralPath $DelegKey -Name DelegationConsole -ErrorAction SilentlyContinue).DelegationConsole
    $dt = (Get-ItemProperty -LiteralPath $DelegKey -Name DelegationTerminal -ErrorAction SilentlyContinue).DelegationTerminal
    if ($dc -eq $DelegConsole -or $dt -eq $DelegTerminal) {
        Set-ItemProperty -LiteralPath $DelegKey -Name DelegationConsole -Value $DelegNone
        Set-ItemProperty -LiteralPath $DelegKey -Name DelegationTerminal -Value $DelegNone
        Ok 'default terminal: back to "Let Windows decide" (it was Windows Terminal)'
    }
    $data = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe'
    if (-not @(Get-AppxPackage -Name $PkgName -ErrorAction SilentlyContinue).Count -and (Test-Path -LiteralPath $data)) {
        Remove-Item -LiteralPath $data -Recurse -Force -ErrorAction SilentlyContinue
        if (Test-Path -LiteralPath $data) { Warn "not removed: $data" } else { Ok "removed: $data" }
    }
    if ($left.Count) { $state.Deps = $left; Save-State $state }
    elseif (Test-Path -LiteralPath $StateDir) { Remove-Item -LiteralPath $StateDir -Recurse -Force -ErrorAction SilentlyContinue }
    Finish $(if ($failed) { 1 } else { 0 })
}

# =============================================================================
#  Установка
# =============================================================================
Write-Host 'Windows Terminal: the latest release on GitHub...'
$rel = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" -Headers @{ 'User-Agent' = 'Install-WindowsTerminal' } -TimeoutSec 30
$ver = $rel.tag_name.TrimStart('v')
$asset = @($rel.assets | Where-Object { $_.name -match '_PreinstallKit\.zip$' }) | Select-Object -First 1
if (-not $asset) { Write-Host "Release $($rel.tag_name) has no PreinstallKit zip - nothing installed." -ForegroundColor Red; Finish 1 }
$have = Get-AppxPackage -Name $PkgName -ErrorAction SilentlyContinue | Sort-Object { [version]$_.Version } | Select-Object -Last 1
if ($have -and [version]$have.Version -ge [version]$ver) {
    Ok "$PkgName $($have.Version) is installed (latest on GitHub: $ver) - nothing to do"
    Finish 0
}
$tmp = Join-Path $env:TEMP "Install-WindowsTerminal-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$failed = $false
try {
    $zip = Join-Path $tmp $asset.name
    Write-Host "  ...  downloading $($asset.name) ($([math]::Round($asset.size / 1MB)) MB)"
    Invoke-WebRequest -UseBasicParsing -Uri $asset.browser_download_url -OutFile $zip -TimeoutSec 600
    if ($asset.digest -match '^sha256:([0-9a-fA-F]{64})$') {
        $sum = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash
        if ($sum -ne $Matches[1].ToUpper()) { throw "SHA-256 does not match GitHub's digest - nothing installed" }
        Ok 'SHA-256 matches the digest GitHub publishes'
    } else { Warn 'GitHub gives no digest for this file - the download is not checked' }
    $kit = Join-Path $tmp 'kit'
    Expand-Archive -LiteralPath $zip -DestinationPath $kit -Force
    $arch = Get-Arch
    $bundle = Get-ChildItem -LiteralPath $kit -Filter '*.msixbundle' | Select-Object -First 1
    $lic = Get-ChildItem -LiteralPath $kit -Filter '*_License*.xml' | Select-Object -First 1
    $deps = @(Get-ChildItem -LiteralPath $kit -Filter '*.appx' | Where-Object { $_.Name -match "_$([regex]::Escape($arch))__" })
    if (-not $bundle) { throw 'no .msixbundle in the kit - nothing installed' }
    $state = Get-State
    # Зависимости: та же или новее уже стоит - Windows отвечает ошибкой, это нормально
    foreach ($d in $deps) {
        $name = ($d.Name -split '_')[0]
        $before = @(Get-AppxPackage -Name $name -ErrorAction SilentlyContinue).Count
        try { Add-AppxPackage -Path $d.FullName; Ok "dependency: $($d.Name)" }
        catch { Write-Host "  --   dependency $name - already there (or newer)" }
        if (-not $before -and @(Get-AppxPackage -Name $name -ErrorAction SilentlyContinue).Count -and @($state.Deps) -notcontains $name) {
            $state.Deps = @(@($state.Deps | Where-Object { $_ }) + $name); Save-State $state
        }
    }
    Add-AppxPackage -Path $bundle.FullName -ForceApplicationShutdown
    $now = Get-AppxPackage -Name $PkgName -ErrorAction SilentlyContinue | Sort-Object { [version]$_.Version } | Select-Object -Last 1
    if (-not $now) { throw 'Windows Terminal is not installed - see the messages above' }
    Ok "$PkgName $($now.Version) installed for $env:USERNAME"
    if ($AllUsers) {
        $dp = @($deps | ForEach-Object { $_.FullName })
        $pa = @{ Online = $true; PackagePath = $bundle.FullName }
        if ($dp.Count) { $pa.DependencyPackagePath = $dp }
        if ($lic) { $pa.LicensePath = $lic.FullName } else { $pa.SkipLicense = $true }
        try { Add-AppxProvisionedPackage @pa | Out-Null; Ok 'provisioned for all users (new users get it at their first sign-in)' }
        catch { Warn "not provisioned for all users: $($_.Exception.Message)"; $failed = $true }
    }
    Write-Host "`nOpen Windows Terminal once (wt), then Install-LinuxTools.ps1 -Update can apply its settings."
    $sc = Join-Path $env:USERPROFILE 'scoop\apps\windows-terminal'
    if (Test-Path -LiteralPath $sc) { Warn "a portable Windows Terminal from Scoop is also here ($sc); remove it with: scoop uninstall windows-terminal -p" }
} catch {
    Write-Host "Not installed: $($_.Exception.Message)" -ForegroundColor Red
    $failed = $true
} finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
Finish $(if ($failed) { 1 } else { 0 })
