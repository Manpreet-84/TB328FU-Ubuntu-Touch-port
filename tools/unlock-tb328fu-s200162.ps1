[CmdletBinding()]
param(
    [ValidateSet('Unlock', 'Recover')]
    [string]$Action = 'Unlock',
    [string]$AssetDir = (Join-Path $PSScriptRoot 'unlock-assets'),
    [string]$BackupDir,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$assets = @{
    Spd     = Join-Path $AssetDir 'spd_dump.exe'
    Fdl1    = Join-Path $AssetDir 'fdl1-dl.bin'
    Fdl2    = Join-Path $AssetDir 'fdl2-dl.bin'
    Cboot   = Join-Path $AssetDir 'fdl2-cboot.bin'
    Unlock  = Join-Path $AssetDir 'spl-unlock-fu.bin'
}
$expected = @{
    'spd_dump.exe'       = '0C8EE50CF6B5DEAD2499C48B4693F7A4E55F8215DD21C9372145D887436C369B'
    'fdl1-dl.bin'        = 'A9CF547C81893023F0FC1CC919CBD4055BFC398A9007AFCBBA5607B76333383E'
    'fdl2-dl.bin'        = '3802B0FDDFB8B7E9708974F260E957F784C6EB087C9AC737D352139067AC30C0'
    'fdl2-cboot.bin'     = '5FEA2B735FDB818EA29C4404A1EFA86A7E195E4629EA634AA6273A0150EBF73F'
    'spl-unlock-fu.bin'  = 'B7B74548C7E54DD039BFEE6789372E28D769C2B29F6EEF1E3E19D9A91C2F7DEC'
}

function Stop-With([string]$Message) { throw "STOP: $Message" }

function Assert-Assets {
    if ($DryRun) { return }
    foreach ($name in $expected.Keys) {
        $path = Join-Path $AssetDir $name
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            Stop-With "missing $path"
        }
        $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash
        if ($actual -ne $expected[$name]) {
            Stop-With "$name is not the tested file (SHA-256 $actual)"
        }
    }
}

function Enter-Brom([string]$Purpose) {
    Write-Host "`nNEXT: $Purpose" -ForegroundColor Cyan
    Write-Host 'Power the tablet fully OFF. Do NOT use adb reboot autodloader.' -ForegroundColor Yellow
    Write-Host 'Unplug USB. Press Enter here, then hold Volume Down while plugging USB in.'
    if (-not $DryRun) { [void](Read-Host) }
}

function Invoke-Spd([string[]]$Tail, [string]$Fdl2 = $assets.Fdl2, [switch]$AllowFailure) {
    $args = @('--wait', '300', '--stage', '0', 'exec_addr', '0x3ee8',
              'fdl', $assets.Fdl1, '0x5500', 'fdl', $Fdl2,
              '0x9efffe00', 'exec') + $Tail
    if ($DryRun) {
        Write-Host ('DRYRUN: spd_dump.exe ' + ($args -join ' '))
        return
    }
    & $assets.Spd @args
    if ($LASTEXITCODE -ne 0 -and -not $AllowFailure) {
        Stop-With "spd_dump failed with exit code $LASTEXITCODE"
    }
}

function Invoke-UnlockSpl {
    $args = @('--wait', '300', '--stage', '0', 'exec_addr', '0x3ee8',
              'fdl', $assets.Unlock, '0x5500')
    if ($DryRun) {
        Write-Host ('DRYRUN: spd_dump.exe ' + ($args -join ' '))
        return
    }
    & $assets.Spd @args
    Write-Host 'A USB/send failure here can be normal because control leaves FDL.' -ForegroundColor Yellow
}

function Assert-File([string]$Path, [long]$Size) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { Stop-With "missing $Path" }
    if ((Get-Item -LiteralPath $Path).Length -ne $Size) { Stop-With "wrong size: $Path" }
}

function Test-AllZero([string]$Path) {
    $bytes = [IO.File]::ReadAllBytes($Path)
    -not ($bytes | Where-Object { $_ -ne 0 } | Select-Object -First 1)
}

function Restore-Stock([string]$Dir) {
    $uboot = Join-Path $Dir 'uboot_b-original.bin'
    $misc = Join-Path $Dir 'misc-original.bin'
    $miscdata = Join-Path $Dir 'miscdata-original.bin'
    if (-not $DryRun) {
        Assert-File $uboot 3145728
        Assert-File $misc 1048576
        Assert-File $miscdata 1048576
    }
    Enter-Brom 'restore this tablet''s original uboot_b, misc and miscdata'
    Invoke-Spd @('write_part', 'uboot_b', $uboot,
                 'write_part', 'miscdata', $miscdata,
                 'write_part', 'misc', $misc, 'firstmode', '0', 'reset')
    Write-Host 'Stock critical partitions restored. No SPL was changed.' -ForegroundColor Green
}

Assert-Assets

if ($Action -eq 'Recover') {
    if (-not $BackupDir) { Stop-With '-BackupDir is required for recovery' }
    Restore-Stock (Resolve-Path -LiteralPath $BackupDir).Path
    exit 0
}

if (-not $DryRun) {
    if (-not (Get-Command adb -ErrorAction SilentlyContinue)) { Stop-With 'adb is not installed or not in PATH' }
    $state = (& adb get-state 2>$null).Trim()
    if ($state -ne 'device') { Stop-With 'start stock Android, enable USB debugging, and authorize this PC' }
    $identity = ((& adb shell getprop ro.product.model),
                 (& adb shell getprop ro.product.device),
                 (& adb shell getprop ro.build.version.incremental)) -join ' '
    if ($identity -notmatch 'TB328FU' -or $identity -notmatch 'S200162') {
        Stop-With "tested only on TB328FU S200162; device reported: $identity"
    }
    Write-Host "Verified: $identity" -ForegroundColor Green
    Write-Host 'This unlock factory-resets Android and temporarily writes uboot_b.' -ForegroundColor Yellow
    if ((Read-Host 'Type UNLOCK TB328FU to continue') -cne 'UNLOCK TB328FU') { Stop-With 'cancelled' }
}

if (-not $BackupDir) {
    $BackupDir = Join-Path $PSScriptRoot ('tb328fu-unlock-backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
}
if (-not $DryRun) { New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null }

Enter-Brom 'make mandatory critical-partition backups'
Invoke-Spd @('path', $BackupDir,
             'read_part', 'splloader', '0', '256K', 'splloader-original.bin',
             'read_part', 'uboot_b', '0', '3M', 'uboot_b-original.bin',
             'read_part', 'misc', '0', '1M', 'misc-original.bin',
             'read_part', 'miscdata', '0', '1M', 'miscdata-original.bin',
             'partition_list', (Join-Path $BackupDir 'partition-stock.xml'), 'reset')

if (-not $DryRun) {
    Assert-File (Join-Path $BackupDir 'splloader-original.bin') 262144
    Assert-File (Join-Path $BackupDir 'uboot_b-original.bin') 3145728
    Assert-File (Join-Path $BackupDir 'misc-original.bin') 1048576
    Assert-File (Join-Path $BackupDir 'miscdata-original.bin') 1048576
    $magic = [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes((Join-Path $BackupDir 'splloader-original.bin')), 0, 4)
    if ($magic -ne 'DHTB') { Stop-With 'stock splloader backup lacks DHTB magic' }
    $before = Join-Path $BackupDir 'unlock-record-before.bin'
    [IO.File]::WriteAllBytes($before, [IO.File]::ReadAllBytes((Join-Path $BackupDir 'miscdata-original.bin'))[8192..8255])
    if (-not (Test-AllZero $before)) { Stop-With 'unlock record is already non-zero; device may already be unlocked' }
    Get-ChildItem -LiteralPath $BackupDir -File | Get-FileHash -Algorithm SHA256 |
        ForEach-Object { "$($_.Hash)  $([IO.Path]::GetFileName($_.Path))" } |
        Set-Content -Encoding ASCII (Join-Path $BackupDir 'SHA256SUMS.txt')
    $script = $MyInvocation.MyCommand.Path
    "@echo off`r`npowershell -ExecutionPolicy Bypass -File `"$script`" -Action Recover -AssetDir `"$AssetDir`" -BackupDir `"%~dp0`"`r`npause`r`n" |
        Set-Content -Encoding ASCII (Join-Path $BackupDir 'RECOVER-NOW.cmd')
}

Enter-Brom 'RAM-only cboot compatibility test (no partition write)'
Invoke-Spd -Fdl2 $assets.Cboot -Tail @('path', $BackupDir,
    'partition_list', (Join-Path $BackupDir 'partition-cboot.xml'), 'reset')
if (-not $DryRun) {
    $stock = (Get-FileHash -Algorithm SHA256 (Join-Path $BackupDir 'partition-stock.xml')).Hash
    $cboot = (Get-FileHash -Algorithm SHA256 (Join-Path $BackupDir 'partition-cboot.xml')).Hash
    if ($stock -ne $cboot) { Stop-With 'cboot partition table differs from stock; recovery files are untouched' }
}

Enter-Brom 'temporarily write tested cboot to uboot_b'
Invoke-Spd @('write_part', 'uboot_b', $assets.Cboot, 'reset')
Write-Host "Recovery launcher: $BackupDir\RECOVER-NOW.cmd" -ForegroundColor Yellow

Enter-Brom 'run the FU unlock writer from RAM'
Invoke-UnlockSpl
if (-not $DryRun) {
    Write-Host 'Wait for Android or the Lenovo screen. Then power fully off.' -ForegroundColor Cyan
    [void](Read-Host 'Press Enter only when ready for the final clean BROM connection')
}

$record = Join-Path $BackupDir 'unlock-record.bin'
$readback = Join-Path $BackupDir 'uboot_b-restored-readback.bin'
$recordCheck = Join-Path $BackupDir 'unlock-record-final.bin'
Enter-Brom 'capture the device-specific unlock record and restore stock partitions'
Invoke-Spd @('path', $BackupDir,
             'read_part', 'miscdata', '8192', '64', 'unlock-record.bin',
             'write_part', 'uboot_b', (Join-Path $BackupDir 'uboot_b-original.bin'),
             'read_part', 'uboot_b', '0', '3M', 'uboot_b-restored-readback.bin',
             'write_part', 'miscdata', (Join-Path $BackupDir 'miscdata-original.bin'),
             'wof', 'miscdata', '8192', $record,
             'write_part', 'misc', (Join-Path $BackupDir 'misc-original.bin'),
             'read_part', 'miscdata', '8192', '64', 'unlock-record-final.bin',
             'firstmode', '0', 'reset')

if (-not $DryRun) {
    Assert-File $record 64
    Assert-File $recordCheck 64
    if (Test-AllZero $record) { Stop-With 'unlock writer produced a zero record; stock partitions were restored' }
    if ((Get-FileHash $record).Hash -ne (Get-FileHash $recordCheck).Hash) { Stop-With 'final unlock-record readback mismatch' }
    if ((Get-FileHash (Join-Path $BackupDir 'uboot_b-original.bin')).Hash -ne (Get-FileHash $readback).Hash) {
        Stop-With 'uboot_b restore readback mismatch; use RECOVER-NOW.cmd before rebooting again'
    }
}

Write-Host 'UNLOCK RECORD VERIFIED; ORIGINAL UBOOT_B VERIFIED.' -ForegroundColor Green
Write-Host 'If Android recovery reports init_user0_failed, choose Factory data reset.' -ForegroundColor Yellow
Write-Host 'Never share unlock-record.bin; it is device-specific.' -ForegroundColor Yellow

