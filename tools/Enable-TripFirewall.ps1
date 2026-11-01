<#
.SYNOPSIS
    Allow ICMP replies in Windows Defender Firewall, so that trip (mtr)
    shows the hops. Works without Install-LinuxTools.ps1.

.DESCRIPTION
    trip waits for ICMP replies on a raw socket. Windows Defender Firewall
    drops inbound ICMP, so trip sends probes and shows no hops, over ICMP
    and over TCP alike. tracert still works: it does not use a raw socket.

    The script adds two inbound Allow rules for any program, for reply
    types only:

      InstallLinuxTools-trip-ICMPv4   ICMPv4 0, 3, 11 (Echo Reply,
                                      Destination Unreachable, Time Exceeded)
      InstallLinuxTools-trip-ICMPv6   ICMPv6 129 (Echo Reply)

    Echo Request (ICMPv4 8) stays closed: the computer still does not answer
    ping. A rule for trip.exe alone does not work: Windows does not match
    ICMP on a raw socket to a program.

    The rule names are the same as in Install-LinuxTools.ps1. That script
    sees rules made here as already present and does not touch them, and
    its -Uninstall does not remove them. Remove them with -Remove.

    Needs administrator rights. With UAC off, an administrator's PowerShell
    already has them; otherwise the script asks for them through UAC.
    trip itself also needs administrator rights on Windows.

.PARAMETER Remove
    Remove the two rules instead of adding them.

.PARAMETER Help
    Show a short help. --help, -h and /? do the same.

.PARAMETER Rest
    Not an option. It catches --help, /? and unknown arguments, so that the
    script can show the help instead of an error.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\Enable-TripFirewall.ps1

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\Enable-TripFirewall.ps1 -Remove
#>
[CmdletBinding()]
param(
    [switch]$Remove,
    # Не для запуска руками: так скрипт помечает свой второй запуск через UAC
    [Parameter(DontShow)] [switch]$Elevated,
    [switch]$Help,
    # --help, /? и всё остальное, чего PowerShell не узнал как ключ
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)] [string[]]$Rest
)

$ErrorActionPreference = 'Stop'

if ($Help -or $Rest) {
    $helpWords = @('--help', '-help', '--h', '-h', '/?', '/h', '/help', '-?', '?', 'help')
    $unknown = @($Rest | Where-Object { $_ -and $helpWords -notcontains $_ })
    if ($unknown.Count) { Write-Host "Unknown argument: $($unknown -join ' ')`n" -ForegroundColor Red }
    Write-Host @'
Enable-TripFirewall.ps1 - allow ICMP replies in Windows Defender Firewall, so
that trip (mtr) shows the hops. Works without Install-LinuxTools.ps1.

Usage:
    .\Enable-TripFirewall.ps1            add the two rules
    .\Enable-TripFirewall.ps1 -Remove    remove them
If running scripts is blocked, or in cmd:
    powershell -NoProfile -ExecutionPolicy Bypass -File .\Enable-TripFirewall.ps1 [-Remove]

Rules (inbound, Allow, any program, all profiles):
    InstallLinuxTools-trip-ICMPv4   ICMPv4 0, 3, 11 (Echo Reply,
                                    Destination Unreachable, Time Exceeded)
    InstallLinuxTools-trip-ICMPv6   ICMPv6 129 (Echo Reply)
Echo Request stays closed: the computer still does not answer ping.

Needs administrator rights: without them the script asks through UAC.
trip itself also needs administrator rights on Windows.
Install-LinuxTools.ps1 leaves these rules alone, and its -Uninstall does
not remove them: use -Remove.
Full help:  Get-Help .\Enable-TripFirewall.ps1 -Full
'@
    exit $(if ($unknown.Count) { 1 } else { 0 })
}

# Те же имена и типы, что в Install-LinuxTools.ps1 ($TripRules): правка там -
# правка здесь.
$Rules = [ordered]@{
    'InstallLinuxTools-trip-ICMPv4' = @{ Protocol = 'ICMPv4'; IcmpType = @('0', '3', '11') }
    'InstallLinuxTools-trip-ICMPv6' = @{ Protocol = 'ICMPv6'; IcmpType = @('129') }
}

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    return ([Security.Principal.WindowsPrincipal]$id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Без прав - тот же скрипт ещё раз, через UAC, и ждать его
if (-not (Test-Admin)) {
    if (-not $PSCommandPath) {
        Write-Host 'Run this from an administrator PowerShell.' -ForegroundColor Red
        exit 1
    }
    Write-Host 'Administrator rights needed: Windows asks for them now.'
    $a = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-Elevated')
    if ($Remove) { $a += '-Remove' }
    try {
        $p = Start-Process -FilePath 'powershell.exe' -ArgumentList $a -Verb RunAs -Wait -PassThru
    } catch {
        Write-Host "Not started: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
    exit $p.ExitCode
}

$failed = 0
foreach ($name in $Rules.Keys) {
    $r = $Rules[$name]
    $exists = [bool](Get-NetFirewallRule -Name $name -ErrorAction SilentlyContinue)
    try {
        if ($Remove) {
            if ($exists) { Remove-NetFirewallRule -Name $name; Write-Host "  OK   removed: $name" -ForegroundColor Green }
            else { Write-Host "  --   not there: $name" }
        } elseif ($exists) {
            Write-Host "  OK   already there: $name" -ForegroundColor Green
        } else {
            New-NetFirewallRule -Name $name -DisplayName "Install-LinuxTools: trip (mtr) $($r.Protocol) replies" `
                -Group 'Install-LinuxTools' -Direction Inbound -Protocol $r.Protocol -IcmpType $r.IcmpType `
                -Action Allow -Profile Any | Out-Null
            Write-Host "  OK   added: $name ($($r.Protocol) $($r.IcmpType -join ', '))" -ForegroundColor Green
        }
    } catch {
        Write-Host "  !!   ${name}: $($_.Exception.Message)" -ForegroundColor Yellow
        $failed++
    }
}

if (-not $Remove -and -not $failed) { Write-Host "`nNow try:  trip 8.8.8.8   (from an administrator window)" }
# Окно, открытое через UAC, закрылось бы сразу - вывод никто бы не увидел
if ($Elevated) { Read-Host "`nPress Enter to close this window" | Out-Null }
exit $(if ($failed) { 1 } else { 0 })
