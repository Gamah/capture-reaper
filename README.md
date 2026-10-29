# SteelSeries Capture Reaper

A small workaround for a SteelSeries GG bug: **Moments** sometimes leaves an old `SteelSeriesCaptureSvc.exe` running after the game it was recording has closed. Each leftover copy can sit on **hundreds of MB to over 1 GB of RAM** until you reboot or quit GG.

This script checks every minute and cleans up those leftovers automatically.

> Unofficial. Not affiliated with or endorsed by SteelSeries. Once SteelSeries fixes the bug, [uninstall this](#uninstall).

> **This may already be fixed.** On one machine the leftovers stopped on 2026-10-23 and hadn't come back six days later. That's a single machine, not an announcement from SteelSeries, so check whether you still have the problem before installing anything.

---

## Do I have this problem?

Open **Task Manager → Details** and sort by name. If you see **two or more** `SteelSeriesCaptureSvc.exe` entries, you have it. The older copies are leftovers from games you already closed.

## What it does

Every minute, it runs this check:

- **One or zero** `SteelSeriesCaptureSvc.exe` running → does nothing.
- **Two or more** running → keeps the **newest** one (the one recording your current game) and closes the older ones, along with their `crashpad_handler.exe` helper.

That's all it does. It doesn't touch any other SteelSeries process, doesn't change GG settings, and doesn't connect to the internet. Every process it closes is written to a log file so you can see what it did.

**Where it puts things:**

| What | Where |
|---|---|
| Scheduled task | Task Scheduler Library → `SteelSeries Capture Reaper` |
| Script and log | `C:\ProgramData\CaptureReaper\` |

## Install

1. Download this repo as a ZIP (green **Code** button → **Download ZIP**, or **Download ZIP** at the top of the gist) and extract it anywhere.
2. Double-click **`Install.cmd`**.
3. Click **Yes** on the administrator (UAC) prompt.
4. You should see **"Installed."** in green. Press Enter to close the window.

You can delete the downloaded folder afterward. The installed copy lives in `C:\ProgramData\CaptureReaper`.

> **If Windows blocks the file** ("Windows protected your PC" or a security warning), right-click `Install.cmd` → **Properties** → tick **Unblock** → **OK**, then try again. Do the same for `CaptureReaper.ps1`.

## Check that it's working

Open PowerShell (a normal window is fine; it asks for admin itself) and paste:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:ProgramData\CaptureReaper\CaptureReaper.ps1" -Status
```

After the UAC prompt, it shows whether the task is installed, which capture processes are running right now, and the last 10 it closed.

## Uninstall

Pick **any one** of these. They all do the same thing: delete the scheduled task and the `C:\ProgramData\CaptureReaper` folder.

### Option 1: Double-click

Double-click **`Uninstall.cmd`** (from the download, or the one you still have) and click **Yes** on the UAC prompt. You should see **"Uninstalled."** in green.

### Option 2: Copy and paste (no files needed)

Press **Start**, type **PowerShell**, open it, paste this line, and press Enter. Click **Yes** on the UAC prompt.

```powershell
Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile -Command "Unregister-ScheduledTask -TaskName ''SteelSeries Capture Reaper'' -Confirm:$false -ErrorAction SilentlyContinue; Remove-Item -Recurse -Force $env:ProgramData\CaptureReaper -ErrorAction SilentlyContinue; Read-Host ''Uninstalled. Press Enter to close''"'
```

### Option 3: By hand

1. Press **Start**, type **Task Scheduler**, open it.
2. Click **Task Scheduler Library** on the left.
3. Find **SteelSeries Capture Reaper**, right-click it → **Delete**.
4. Open File Explorer, paste `C:\ProgramData` into the address bar, and delete the **CaptureReaper** folder.

> Don't see the task in Task Scheduler? Close it and reopen it with right-click → **Run as administrator**. Tasks that run as SYSTEM are hidden from non-admin views.

## How do I know when SteelSeries has fixed it?

After a GG update, play normally for a few sessions, then run the Status command again:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:ProgramData\CaptureReaper\CaptureReaper.ps1" -Status
```

Look at the dates in **Last 10 kills**. If nothing new has been logged since the update, the leftovers have stopped and you can [uninstall](#uninstall). Give it a week of normal use before deciding — an empty log only means something if the reaper was running and you were recording.

Check `Task: INSTALLED` at the top of that output, not Task Scheduler or `Get-ScheduledTask`: the task runs as SYSTEM, so an ordinary window can't see it and will claim it isn't there.

## FAQ

**Will it break Moments recording?**
No. It always keeps the newest capture process, which is the one recording your current game. Clips keep saving normally.

**What if I record two games at the same time?**
Then both capture processes are legitimate, and this script will close the older one. That's an unusual setup. If it's yours, don't use this.

**Why does it need administrator rights?**
The capture service runs with elevated rights, so closing it needs them too. The scheduled task runs as SYSTEM so it works without a prompt every minute.

**Why every minute instead of instantly?**
Simplicity. An orphan holds memory for at most about a minute before it's cleaned up.

**Can I test it without installing?**
Yes. In PowerShell, from the downloaded folder:
```powershell
powershell -ExecutionPolicy Bypass -File .\CaptureReaper.ps1 -DryRun
```
It lists what it *would* close and closes nothing.
