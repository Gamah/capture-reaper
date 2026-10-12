<#
.SYNOPSIS
    Kills orphaned SteelSeriesCaptureSvc.exe processes left behind by SteelSeries GG "Moments".

.DESCRIPTION
    SteelSeries GG's Moments feature sometimes leaves an old SteelSeriesCaptureSvc.exe running after
    the game it was capturing exits. Each orphan can hold hundreds of MB to over 1 GB of RAM.

    Rule: if more than one SteelSeriesCaptureSvc.exe is running, keep the NEWEST one and kill the rest
    (along with each one's crashpad_handler.exe child). With only one running, nothing happens.

    Unofficial workaround. Not affiliated with or endorsed by SteelSeries.

.PARAMETER Install
    Installs to C:\ProgramData\CaptureReaper and creates a scheduled task that runs every minute as SYSTEM.

.PARAMETER Uninstall
    Removes the scheduled task and C:\ProgramData\CaptureReaper.

.PARAMETER Status
    Shows whether the task is installed, which capture processes are running, and recent log entries.

.PARAMETER DryRun
    Shows what would be killed without killing anything.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\CaptureReaper.ps1 -Install
#>
param(
    [switch]$Install,
    [switch]$Uninstall,
    [switch]$Status,
    [switch]$DryRun,
    [switch]$Pause   # internal: keep the elevated window open at the end
)

$TaskName = 'SteelSeries Capture Reaper'
$Dir      = Join-Path $env:ProgramData 'CaptureReaper'
$Script   = Join-Path $Dir 'CaptureReaper.ps1'
$Log      = Join-Path $Dir 'reaper.log'

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    ([Security.Principal.WindowsPrincipal]$id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Exit-WithPause {
    if ($Pause) { Write-Host ''; Read-Host 'Press Enter to close' | Out-Null }
}

# Install / Uninstall / Status need admin. If we don't have it, relaunch elevated (UAC prompt).
if (($Install -or $Uninstall -or $Status) -and -not (Test-Admin)) {
    $mode = if ($Install) { '-Install' } elseif ($Uninstall) { '-Uninstall' } else { '-Status' }
    try {
        Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $mode -Pause"
        Write-Host 'Opened an administrator window to finish. Approve the UAC prompt if it appears.'
    } catch {
        Write-Host 'Administrator permission was declined, so nothing was changed.' -ForegroundColor Yellow
    }
    return
}

if ($Install) {
    # Stage a copy first, in case we're being run from the install folder itself.
    $staged = Join-Path $env:TEMP 'CaptureReaper.staged.ps1'
    Copy-Item -Force $PSCommandPath $staged

    # Recreate the folder as admin so a normal user can't edit a script that runs as SYSTEM.
    $oldLog = if (Test-Path $Log) { Get-Content $Log } else { $null }
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force $Dir -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force $Dir | Out-Null
    Move-Item -Force $staged $Script
    if ($oldLog) { Set-Content -Path $Log -Value $oldLog }

    $action    = New-ScheduledTaskAction -Execute 'powershell.exe' `
                   -Argument "-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$Script`""
    $trigger   = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 1)
    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
                   -ExecutionTimeLimit (New-TimeSpan -Minutes 2) -MultipleInstances IgnoreNew
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
        -Principal $principal -Settings $settings -Description 'Kills orphaned SteelSeriesCaptureSvc.exe processes. Uninstall: see C:\ProgramData\CaptureReaper' -Force | Out-Null
    Start-ScheduledTask -TaskName $TaskName   # run one pass right away

    Write-Host "Installed. '$TaskName' now runs every minute." -ForegroundColor Green
    Write-Host "Kills are logged to $Log"
    Exit-WithPause
    return
}

if ($Uninstall) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force $Dir -ErrorAction SilentlyContinue
    if ((Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) -or (Test-Path $Dir)) {
        Write-Host 'Something could not be removed. See the manual uninstall steps in the README.' -ForegroundColor Yellow
    } else {
        Write-Host 'Uninstalled. The scheduled task and C:\ProgramData\CaptureReaper are gone.' -ForegroundColor Green
    }
    Exit-WithPause
    return
}

if ($Status) {
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($task) {
        $info = $task | Get-ScheduledTaskInfo
        Write-Host "Task: INSTALLED ($($task.State)), last run $($info.LastRunTime), result $($info.LastTaskResult)" -ForegroundColor Green
    } else {
        Write-Host 'Task: NOT INSTALLED' -ForegroundColor Yellow
    }
    Write-Host "`nCapture processes running now:"
    Get-CimInstance Win32_Process -Filter "Name='SteelSeriesCaptureSvc.exe'" | Sort-Object CreationDate |
        Select-Object ProcessId, CreationDate, @{n='MB'; e={[math]::Round($_.WorkingSetSize / 1MB)}} |
        Format-Table -AutoSize | Out-String | Write-Host
    Write-Host 'Last 10 kills:'
    if (Test-Path $Log) { Get-Content $Log -Tail 10 | Write-Host } else { Write-Host '  (none logged)' }
    Exit-WithPause
    return
}

# ---- Main pass: what the scheduled task runs every minute ----
$caps = @(Get-CimInstance Win32_Process -Filter "Name='SteelSeriesCaptureSvc.exe'" | Sort-Object CreationDate)
if ($caps.Count -le 1) {
    if ($DryRun) { "$($caps.Count) capture process(es) running - nothing to do." }
    return
}

$keep = $caps[-1]
foreach ($c in $caps[0..($caps.Count - 2)]) {
    $msg = "{0:s}  killed PID {1} (started {2:T}, {3} MB)  kept newest PID {4} (started {5:T})" -f `
        (Get-Date), $c.ProcessId, $c.CreationDate, [math]::Round($c.WorkingSetSize / 1MB),
        $keep.ProcessId, $keep.CreationDate
    if ($DryRun) { "DRYRUN  $msg"; continue }
    taskkill /PID $c.ProcessId /T /F 2>&1 | Out-Null   # /T also ends its crashpad_handler child
    if (Test-Path $Dir) {
        Add-Content -Path $Log -Value $msg
        # Keep the log small: once it passes 1000 lines, trim to the last 500.
        $lines = @(Get-Content $Log)
        if ($lines.Count -gt 1000) { $lines[-500..-1] | Set-Content $Log }
    }
    $msg
}
