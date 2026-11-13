# Setup and technical reference

[Back to the project overview](../README.md)

## Requirements

- Windows 10 or Windows 11, x64.
- .NET Framework 4.8 and built-in Windows PowerShell 5.1.
- A writable folder containing the **complete** application distribution.
- ActivityWatch Classic v0.14.0, the version used during development.
- ActivityWatch Web Watcher for Chrome webpage detection.
- Optional: ntfy on a phone and an internet connection.

The portable build does not require a terminal, Python, Node.js or development tools. Its EXE hosts the PowerShell engine in its own graphical process; supporting scripts are still required.

The app is unsigned. Managed computers may restrict it; follow your organisation's security policies. This is not a single-file executable or an installer.

## Start the portable build

1. Extract the entire Windows portable ZIP into a writable folder.
2. Keep `StudyGuard.exe`, `StudyGuard.exe.config`, the scripts, `forest-art.cs` and all other supplied files together.
3. Open `StudyGuard.exe`. First run creates local settings from `config.example.json`, including a random ntfy topic. Phone reminders start disabled.
4. Set up ActivityWatch before relying on activity classifications.

The prepared 1.2.0 Windows archive is named `StudyGuard-1.2.0-win-x64.zip`. A source ZIP or repository clone does not include the compiled executable. The portable archive needs to be attached to a GitHub Release before visitors can download a release build; this document does not assume a published download URL.

## ActivityWatch and Chrome

Install and start [ActivityWatch Classic v0.14.0](https://github.com/ActivityWatch/activitywatch/releases/tag/v0.14.0), with its window watcher running. Alternatively, put its **complete portable distribution** under `app/activitywatch/`, including `app/activitywatch/aw-qt.exe`.

The app connects to `http://127.0.0.1:5600`. ActivityWatch is not bundled or automatically downloaded.

For Chrome webpages, use **Settings → Chrome extension** to install [ActivityWatch Web Watcher](https://chromewebstore.google.com/detail/activitywatch-web-watcher/nglaklhklhcoonedhgnpgddginnjdadi). During a session, check for **Website detection active**. An extension showing Connected alone does not establish coverage.

### What each component supplies

| Component | Role |
| --- | --- |
| ActivityWatch local server | Serves the local API on port 5600. |
| Window watcher | Supplies the current foreground application and window title. |
| Chrome Web Watcher | Supplies browser-tab titles and URLs. A browser tab can continue reporting while another application is foreground. |
| FocusRelay | Matches fresh browser data to the foreground window, applies reminder rules and maintains the timer/accounting. Idle checks use the Windows last-input API, not the ActivityWatch AFK bucket. |

The app discovers data belonging to the local ActivityWatch host. It treats an event as fresh using its timestamp **plus duration**, not its start timestamp alone. For browser coverage, it matches the browser and checks that the foreground window title contains the reported tab title; the event freshness limit is 25 seconds. A URL reported directly by the window watcher can also supply coverage.

Title matching is a heuristic, not a unique tab identifier: pages with identical titles, multiple browser profiles or unusual window titles can make matching ambiguous or unavailable. The verified setup target is Classic v0.14.0 with Chrome Web Watcher; this is not a claim that every supported browser name has been tested end to end.

### Connection check in normal use

1. Start ActivityWatch and confirm that its dashboard opens at `http://127.0.0.1:5600`.
2. Start a focus session in the app.
3. Bring a normal Chrome webpage to the foreground and leave it there briefly. Avoid using a `chrome://` page as the test; private windows or restricted pages may not supply the expected data.
4. Return to the app and inspect its recent status/diagnostic samples. A non-browser app may already have become foreground again by the time you check the screen, so the live status can legitimately change.
5. To test a configured website rule, use a normal page that matches that rule, confirm it is not allowlisted, and remain active beyond the configured distraction grace period. Test real notification display separately from API connectivity.

| Status | Meaning |
| --- | --- |
| `Website detection active` | A fresh foreground-browser URL is available for website rules. |
| `App monitoring active` | Foreground application monitoring is working; it does not by itself establish website coverage. |
| `Website reminders INACTIVE: URL unavailable` | The foreground browser lacks a usable/matching URL. This is not evidence of focused work. |
| `Waiting for fresh ActivityWatch foreground data` | Current foreground records are missing or stale. |
| `ActivityWatch unavailable. Idle reminders still active` | During an already-running session, the ActivityWatch request failed. Windows idle checks continue; unavailable activity coverage is not silently counted as focus. |

If the local dashboard works but webpage coverage does not, check that the window watcher and Chrome extension are both producing current records, the extension is running in the Chrome profile being used, and its event title matches the foreground window. Do not infer success only from the extension being installed or from old data appearing on the dashboard.

**Known limitation found in live checking:** the foreground window and browser title can match while the latest browser event is older than the app's fixed 25-second freshness limit. The current version then temporarily disables website coverage, even though the feed has worked in other samples. This timing compatibility has not been fixed in this documentation pass; see [the verification record](VALIDATION.md). Do not describe occasional successful recognition as proof of uninterrupted monitoring.

The source uses ActivityWatch's local [REST API](https://docs.activitywatch.net/en/latest/api/rest.html); it does not send an API-key authentication header. The documented setup uses the local Classic service. Do not expose that API to the public internet.

## Display scaling (DPI)

The EXE manifest declares Per-Monitor V2 awareness. `dpi.ps1` requests awareness before the first application window is created. Main and settings layouts use 96-DPI logical bounds, scale controls/fonts for the current window DPI and handle `DpiChanged` events. The desk drawing renders at the current scale rather than relying on a stretched screenshot.

Where the enlarged layout exceeds the screen work area, window dimensions are capped and scrolling is enabled. At larger scales some content can therefore be outside the initial viewport; that is different from claiming the whole layout fits every display.

The current test pass generated previews at 100%, 125%, 150% and 200% on a 144-DPI host. Cross-monitor dragging and every hardware combination have not been manually verified. See [the verification record](VALIDATION.md).

## Daily use

1. Set a work target, focus-session length, break length and break count. Session length and break count are linked.
2. After changing break length, enter the session length or break count again.
3. Select **Start focus**. Pause or stop whenever needed.
4. When a focus interval ends, select **Start break** when ready. Extra work before confirmation is accounted for separately.
5. The next focus interval starts automatically after the break.
6. Open **Settings** for rules, reminder tests, diagnostics and phone options.

Notebook marks reflect credited estimated focus in the current interval. Elapsed time, distraction and unmeasured time are not interchangeable with that estimate. Pages are not saved notes or collectible rewards.

## Optional phone reminders

Follow the [ntfy phone setup guide](https://docs.ntfy.sh/subscribe/phone/). Subscribe to the app's generated topic on `https://ntfy.sh`, enable reminders, save settings and use **Test phone**.

Check actual receipt on the phone. Service acceptance is not delivery confirmation. Keep the topic private: its name is not account authentication, and someone who knows it may be able to subscribe or publish to it.

Messages contain generic reminders, not browser URLs, window titles or app names. The integration does not measure phone usage.

## Build from source

Run from the source folder in **Windows PowerShell 5.1**, not PowerShell 7:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Build.ps1
```

[Build.ps1](../Build.ps1) uses the Windows .NET Framework C# compiler to compile [Launcher.cs](../Launcher.cs), with [app.manifest](../app.manifest) and an app icon. The resulting EXE still needs its configuration and supporting files.

The launcher sets PowerShell policy for its own process; it does not change user or machine execution policy. Organisational restrictions still apply.

## Verification

The EXE supports `--preview` to render the interface without starting a session, and `--smoke-test` for fixture-based checks. Run them in a **disposable copy** because local settings, test logs or preview images may be written there. Output is recorded in `verification.txt`.

The internal preview check also accepts the process environment variable `STUDYGUARD_TEST_SCALE` with values such as `1`, `1.25`, `1.5` or `2`. This simulates layout scale for fixtures; it does not change Windows display settings or replace a physical multi-monitor test.

[Test-DeskView.ps1](../Test-DeskView.ps1) checks elapsed progress versus credited focus, pause preservation, break state and fresh-page transitions. Fixture tests do not establish real-device notification delivery, learning outcomes or support for every Windows environment.

## Source map

| File | Role |
| --- | --- |
| [Launcher.cs](../Launcher.cs) / [Build.ps1](../Build.ps1) | Graphical EXE host and build |
| [StudyGuard.ps1](../StudyGuard.ps1) | App and monitoring orchestration |
| [forest-theme.ps1](../forest-theme.ps1) / [forest-art.cs](../forest-art.cs) | Layout and illustrated session states |
| [dpi.ps1](../dpi.ps1) | Display-scaling support |
| [planner.ps1](../planner.ps1) | Work-and-break calculations |
| [accounting.ps1](../accounting.ps1) / [daily.ps1](../daily.ps1) | Session estimates and daily totals |
| [rules.ps1](../rules.ps1) / [rules-editor.ps1](../rules-editor.ps1) | Matching rules and editor |
| [phone.ps1](../phone.ps1) | Phone reminder state |

## Before publishing

Exclude personal `config.json`, ntfy topics, logs, ActivityWatch records and backups. Inspect screenshots and commit history, not only current files. The README images are reviewed UI/fixture previews, not exports of personal activity records.

These documentation files do not create a GitHub repository or publish a release.
