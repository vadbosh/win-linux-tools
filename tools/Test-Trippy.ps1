<#
.SYNOPSIS
    Diagnostics for trip (mtr): why it starts but shows no replies.

.DESCRIPTION
    Read-only by default. Collects into one text file: Windows and UAC
    settings, the trip binary and the mtr shim, the route to the target,
    network adapters (VPN/TUN included), VPN processes, firewall profiles,
    firewall rules for ICMP and for trip.exe, security products, ping,
    tracert, and short trip runs over ICMP, TCP and through the mtr shim.

    -RuleTest runs trip over ICMP and over TCP 443, each time with one
    temporary inbound ICMPv4 Allow rule for any program: first for all
    ICMPv4 (the control: it is known to work), then only for types 0, 3
    and 11 (Echo Reply, Destination Unreachable, Time Exceeded). A rule for
    trip.exe alone does not work: ICMP that comes to a raw socket is not
    matched by -Program. Each rule is named WLT_TRIPDIAG_* and is removed
    right after its runs, even if a run fails.

    -FirewallOff also runs trip with Windows Defender Firewall turned off
    for all profiles, and turns back on every profile that was on before,
    even if the run fails. While it is off, the machine is open to the
    network.

    Run it from an elevated PowerShell (with UAC off, any PowerShell of an
    administrator is elevated). Send the file it names at the end.

.PARAMETER Target
    IPv4 address or host name to trace. Default 8.8.8.8.

.PARAMETER RuleTest
    Also run trip with temporary firewall rules (see above).

.PARAMETER FirewallOff
    Also run trip with the firewall off (see above).

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Test-Trippy.ps1

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\Test-Trippy.ps1 -RuleTest -FirewallOff
#>
[CmdletBinding()]
param(
    [string]$Target = '8.8.8.8',
    [switch]$RuleTest,
    [switch]$FirewallOff
)

$ErrorActionPreference = 'Continue'
$ScoopRoot = if ($env:SCOOP) { $env:SCOOP } else { Join-Path $env:USERPROFILE 'scoop' }
$Log = Join-Path $env:TEMP ('trip-diag-{0:yyyyMMdd-HHmmss}.txt' -f (Get-Date))

# Секция: заголовок и вывод блока - на экран и в файл. stderr программ
# (в 5.1 это ErrorRecord) пишется как текст сообщения.
function Write-Section([string]$Title, [scriptblock]$Body) {
    $head = "`r`n== $Title"
    Write-Host $head -ForegroundColor Cyan
    Add-Content -LiteralPath $Log -Value $head -Encoding UTF8
    $out = try {
        & $Body 2>&1 | ForEach-Object {
            if ($_ -is [System.Management.Automation.ErrorRecord]) { $_.Exception.Message } else { $_ }
        } | Out-String -Width 220
    } catch {
        "ERROR: $($_.Exception.Message)"
    }
    $out = "$out".TrimEnd()
    if (-not $out) { $out = '(nothing)' }
    Write-Host $out
    Add-Content -LiteralPath $Log -Value $out -Encoding UTF8
}

# Таблицу trip пишет в UTF-8, а 5.1 читает вывод программ в кодировке
# консоли (cp866) - рамка превращалась в "тФМтФА". На время вызова - UTF-8.
function Invoke-Utf8([scriptblock]$Cmd) {
    $enc = [Console]::OutputEncoding
    try {
        [Console]::OutputEncoding = [Text.Encoding]::UTF8
        & $Cmd
        "exit=$LASTEXITCODE"
    } finally {
        [Console]::OutputEncoding = $enc
    }
}

# Одно временное входящее правило ICMPv4 Allow для любой программы, прогоны
# trip по ICMP и по TCP 443, удаление правила. Правило с -Program не
# работает: ICMP, пришедший на raw-сокет, по программе не сопоставляется
# (проверено на Win11 2026-11-01).
function Test-WithRule([string]$RuleName, [string[]]$IcmpType) {
    $extra = @{}
    if ($IcmpType) { $extra.IcmpType = $IcmpType }
    $what = if ($IcmpType) { "ICMPv4 types $($IcmpType -join ',')" } else { 'all ICMPv4' }
    try {
        New-NetFirewallRule -Name $RuleName -DisplayName $RuleName -Direction Inbound -Protocol ICMPv4 `
            -Action Allow -Profile Any @extra -ErrorAction Stop | Out-Null
        Write-Section "trip ICMP with rule $RuleName ($what)" {
            Invoke-Utf8 { & $Trip $Ip -m pretty -C 3 -t 8 }
        }
        Write-Section "trip TCP 443 with rule $RuleName ($what)" {
            Invoke-Utf8 { & $Trip $Ip --tcp -P 443 -m pretty -C 3 -t 8 }
        }
    } catch {
        $msg = $_.Exception.Message
        Write-Section "rule $RuleName ($what)" { "ERROR: $msg" }
    } finally {
        Remove-NetFirewallRule -Name $RuleName -ErrorAction SilentlyContinue
    }
}

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    return ([Security.Principal.WindowsPrincipal]$id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Цель: Find-NetRoute и trip получают IPv4-адрес, не имя.
$Ip = $null
if ([System.Net.IPAddress]::TryParse($Target, [ref]$null)) {
    $Ip = $Target
} else {
    try {
        $Ip = [System.Net.Dns]::GetHostAddresses($Target) |
            Where-Object { $_.AddressFamily -eq 'InterNetwork' } |
            Select-Object -First 1 | ForEach-Object { $_.IPAddressToString }
    } catch { }
}
if (-not $Ip) {
    Write-Host "Cannot resolve '$Target' to an IPv4 address." -ForegroundColor Red
    exit 1
}

$Trip = Join-Path $ScoopRoot 'apps\trippy\current\trip.exe'
if (-not (Test-Path -LiteralPath $Trip)) {
    $c = Get-Command trip.exe -ErrorAction SilentlyContinue
    $Trip = if ($c) { $c.Source } else { $null }
}

Write-Section 'system' {
    $os = Get-CimInstance Win32_OperatingSystem
    $uac = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -ErrorAction SilentlyContinue
    [pscustomobject]@{
        Date                       = (Get-Date).ToString('s')
        OS                         = "$($os.Caption) $($os.Version)"
        PowerShell                 = "$($PSVersionTable.PSVersion)"
        User                       = "$env:USERDOMAIN\$env:USERNAME"
        Elevated                   = Test-Admin
        EnableLUA                  = $uac.EnableLUA
        ConsentPromptBehaviorAdmin = $uac.ConsentPromptBehaviorAdmin
        Target                     = "$Target ($Ip)"
    } | Format-List
}

Write-Section 'trip binary and mtr shim' {
    if (-not $Trip) { 'trip.exe not found'; return }
    "trip:    $Trip"
    $cur = Join-Path $ScoopRoot 'apps\trippy\current'
    if (Test-Path -LiteralPath $cur) { "current: $((Get-Item -LiteralPath $cur).Target)" }
    & $Trip --version
    $shim = Join-Path $ScoopRoot 'shims\mtr.shim'
    if (Test-Path -LiteralPath $shim) { "--- $shim"; Get-Content -LiteralPath $shim } else { "no $shim" }
}

Write-Section "route to $Ip" {
    Find-NetRoute -RemoteIPAddress $Ip | Format-List InterfaceAlias, IPAddress, DestinationPrefix, NextHop, RouteMetric
}

Write-Section 'adapters that are up' {
    Get-NetAdapter | Where-Object Status -eq 'Up' |
        Format-Table Name, InterfaceDescription, LinkSpeed -AutoSize
    # Не Get-NetIPConfiguration: внутри он зовёт sort, а профиль -LinuxFirst
    # подменяет этот псевдоним на sort.exe - ошибка "unexpected argument '-D'".
    Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.PrefixOrigin -ne 'WellKnown' } |
        Format-Table InterfaceAlias, IPAddress, PrefixLength, PrefixOrigin -AutoSize
    Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
        Format-Table InterfaceAlias, NextHop, RouteMetric -AutoSize
}

Write-Section 'VPN / TUN' {
    Get-NetAdapter -IncludeHidden -ErrorAction SilentlyContinue |
        Where-Object { $_.InterfaceDescription -match 'TAP|TUN|Wintun|WireGuard|sing|VPN|Hiddify|OpenVPN|Tailscale|ZeroTier|Clash|Nekoray' } |
        Format-Table Name, InterfaceDescription, Status -AutoSize
    Get-Process -ErrorAction SilentlyContinue |
        Where-Object { $_.ProcessName -match '^(sing-box|hiddify|wireguard|openvpn|v2ray|xray|clash|mihomo|nekoray|nekobox|tailscaled|zerotier)' } |
        Format-Table ProcessName, Id, Path -AutoSize
}

# ActiveStore - то, что действует: локальные правила вместе с правилами
# групповой политики. AllowInboundRules = False или AllowLocalFirewallRules =
# False (политика) - и любое своё Allow-правило не действует.
Write-Section 'firewall profiles (effective, ActiveStore)' {
    Get-NetFirewallProfile -PolicyStore ActiveStore |
        Format-List Name, Enabled, DefaultInboundAction, DefaultOutboundAction, AllowInboundRules,
                    AllowLocalFirewallRules, NotifyOnListen, LogBlocked, LogFileName
}

Write-Section 'firewall rules for trip.exe (Block wins over Allow)' {
    Get-NetFirewallApplicationFilter -All -PolicyStore ActiveStore | Where-Object { $_.Program -match 'trip' } | ForEach-Object {
        $prog = $_.Program
        $_ | Get-NetFirewallRule | Select-Object Name, DisplayName, Enabled, Direction, Action, Profile,
            @{ n = 'Program'; e = { $prog } }
    } | Format-Table -AutoSize -Wrap
}

Write-Section 'enabled inbound ICMP rules' {
    Get-NetFirewallPortFilter -All -PolicyStore ActiveStore | Where-Object { $_.Protocol -match '^(ICMPv4|ICMPv6|1|58)$' } | ForEach-Object {
        $proto = $_.Protocol; $type = $_.IcmpType
        $_ | Get-NetFirewallRule |
            Where-Object { $_.Enabled -eq 'True' -and $_.Direction -eq 'Inbound' } |
            Select-Object Name, DisplayName, Action, Profile,
                @{ n = 'Protocol'; e = { $proto } }, @{ n = 'IcmpType'; e = { $type -join ',' } }
    } | Format-Table -AutoSize -Wrap
}

Write-Section 'security products' {
    foreach ($cls in 'AntiVirusProduct', 'FirewallProduct') {
        Get-CimInstance -Namespace root/SecurityCenter2 -ClassName $cls -ErrorAction SilentlyContinue |
            Select-Object @{ n = 'Class'; e = { $cls } }, displayName, pathToSignedProductExe
    }
}

Write-Section "ping $Ip" { ping -n 2 $Ip }

Write-Section "tracert $Ip" { tracert -d -h 8 -w 1000 $Ip }

if ($Trip) {
    Write-Section "trip ICMP (direct)" {
        Invoke-Utf8 { & $Trip $Ip -m pretty -C 3 -t 8 }
    }
    Write-Section "trip TCP 443 (direct)" {
        Invoke-Utf8 { & $Trip $Ip --tcp -P 443 -m pretty -C 3 -t 8 }
    }
    Write-Section "trip ICMP verbose (direct)" {
        Invoke-Utf8 { & $Trip $Ip -m pretty -C 1 -t 3 -v --log-format compact }
    }
}

if (Get-Command mtr -ErrorAction SilentlyContinue) {
    Write-Section "mtr (shim, through gsudo)" {
        Invoke-Utf8 { mtr $Ip -m pretty -C 3 -t 8 }
    }
}

if ($RuleTest -and $Trip) {
    Write-Host "`r`nTemporary firewall rules WLT_TRIPDIAG_*: each is removed right after its run." -ForegroundColor Yellow
    Test-WithRule 'WLT_TRIPDIAG_ANY' $null
    Test-WithRule 'WLT_TRIPDIAG_TYPES' @('0', '3', '11')
    Write-Section 'WLT_TRIPDIAG_* rules left (must be nothing)' {
        Get-NetFirewallRule -Name 'WLT_TRIPDIAG_*' -ErrorAction SilentlyContinue | Format-Table Name, Enabled -AutoSize
    }
}

if ($FirewallOff -and $Trip) {
    Write-Host "`r`nFirewall OFF for the next run. It is turned back on right after." -ForegroundColor Yellow
    $wasOn = @(Get-NetFirewallProfile | Where-Object { $_.Enabled -eq 'True' } | ForEach-Object { $_.Name })
    try {
        Set-NetFirewallProfile -All -Enabled False
        Write-Section "trip ICMP with firewall OFF" {
            Invoke-Utf8 { & $Trip $Ip -m pretty -C 3 -t 8 }
        }
    } finally {
        if ($wasOn.Count) { Set-NetFirewallProfile -Name $wasOn -Enabled True }
        Write-Section 'firewall profiles after the test' {
            Get-NetFirewallProfile | Format-Table Name, Enabled -AutoSize
        }
    }
}

Write-Host "`r`nSaved: $Log" -ForegroundColor Green
