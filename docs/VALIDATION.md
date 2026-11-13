# Verification record

[Project overview](../README.md) · [Setup and troubleshooting](SETUP.md)

Checked on **13 November 2026** against the prepared **1.2.0 Windows x64** build. Testing used disposable copies with fresh example settings; personal configuration and activity logs were not modified. No real phone push was sent.

## Passed automated checks

| Check | Result |
| --- | --- |
| EXE startup and built-in smoke test | Passed |
| Planner: linked fields, interval calculation and plan rebuilding | Passed |
| Rules: app/domain matching, idle threshold and exact video exceptions | Passed |
| Session accounting: focus, distraction, AFK and unknown time | Passed |
| Daily totals: accumulation, persistence, rollover and no double counting | Passed |
| Phone reminder state: escalation/deduplication logic, not delivery | Passed |
| Rules editor: normalisation, save, preservation and cancel | Passed |
| Desk states: focus credits versus elapsed time, pause, break and fresh page | Passed in the EXE smoke test |
| Taskbar minimise/restore checks | Passed in the EXE smoke test |

## DPI fixtures

The host display reported **144 DPI (150%)**. The process-local test override generated these layouts without changing Windows display settings:

| Requested scale | Recorded layout scale | Client area | Result |
| --- | --- | --- | --- |
| 100% | 1.00 | 1080 × 790 | Passed |
| 125% | 1.25 | 1350 × 988 | Passed |
| 150% | 1.50 | 1620 × 1185 | Passed |
| 200% | 2.00 | 2160 × 1448 | Passed; height capped to available work area |

Main-window previews at 100% and 200%, and the settings preview at 150%, were visually inspected. At the larger scale not all content is in the initial viewport; scrolling is enabled in the implementation. Physical cross-monitor movement and manual scrolling at every scale remain separate checks, not covered by the positive-bounds fixture alone.

## ActivityWatch: observed, not assumed

A read-only check reached the local **ActivityWatch v0.14.0** API and found one local foreground-window bucket and one local browser-tab bucket. Recent window and browser events were observed. Checks emitted only booleans, freshness and aggregate counts; no hostnames, bucket IDs, URLs or window titles were included in the report.

The first snapshots had a non-browser application in the foreground. After the user started a normal session and opened a Chrome webpage, the follow-up found matching foreground-window and browser-tab records. The installed application's own diagnostic log also recorded `websiteReady: true` (two samples in the later five-minute window), with no monitor/timer errors in that check window. This establishes that the real application can recognise webpage coverage, not only that the API is reachable.

### Observed limitation: browser-data freshness

The same follow-up exposed an integration limitation. In three consecutive snapshots at approximately **16:58 Sydney time**, Chrome was foreground and the tab title matched, but the latest browser event ended **39.7, 42.7 and 45.5 seconds** earlier. The application currently accepts browser events only within **25 seconds**, so these snapshots correctly reproduced its inactive-coverage condition.

This is not a claim that the server disconnected or that browser detection never works. It means the current freshness rule can temporarily reject otherwise matching browser data between updates. The underlying reason for the update cadence has not been isolated; watcher scheduling, buffering and other causes have not been distinguished. No watcher settings or application detection logic were changed during this verification.

**Release assessment:** basic live recognition is confirmed. Some otherwise matching records were rejected as stale in the observed snapshots; sustained webpage-reminder coverage is not fully verified. A controlled foreground-browser test over multiple update cycles is needed before deciding whether the freshness policy requires a change.

## Remaining manual checks

- Run a controlled foreground-browser test over multiple update cycles to isolate the freshness/update-cadence behaviour; address any confirmed issue and retest.
- Test a configured website rule through its grace period and verify the actual desktop notification.
- Configure optional phone reminders and confirm receipt on the physical phone.
- Check actual scrolling on a constrained display and dragging between monitors with different scaling.

Passing fixtures and connecting to the server are not a claim that all these manual checks have passed.
