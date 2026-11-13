param([switch]$SmokeTest, [switch]$NotificationTest, [switch]$PhoneTest, [switch]$ForestPreview)
$ErrorActionPreference='Stop'
. "$PSScriptRoot\rules.ps1"
. "$PSScriptRoot\planner.ps1"
. "$PSScriptRoot\phone.ps1"
. "$PSScriptRoot\accounting.ps1"
. "$PSScriptRoot\rules-editor.ps1"
. "$PSScriptRoot\daily.ps1"
Add-Type -AssemblyName System.Net.Http
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
. (Join-Path $PSScriptRoot 'dpi.ps1')
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class StudyGuardIdle {
 [DllImport("winmm.dll", CharSet=CharSet.Unicode, SetLastError=true)]
 static extern bool PlaySound(string sound, IntPtr module, uint flags);
 public static bool PlayNotificationSound() {
  // System event alias + async + no fallback beep + System Sounds audio session.
  return PlaySound("Notification.Default", IntPtr.Zero, 0x00010000u | 0x00000001u | 0x00000002u | 0x00200000u);
 }
 [StructLayout(LayoutKind.Sequential)] struct LASTINPUTINFO { public uint cbSize; public uint dwTime; }
 [DllImport("user32.dll")] static extern bool GetLastInputInfo(ref LASTINPUTINFO info);
 public static double Seconds() {
  LASTINPUTINFO info=new LASTINPUTINFO(); info.cbSize=(uint)Marshal.SizeOf(info);
  if (!GetLastInputInfo(ref info)) throw new InvalidOperationException("Idle detection unavailable");
  return unchecked((uint)Environment.TickCount-info.dwTime)/1000.0;
 }
}
'@
[Windows.Forms.Application]::EnableVisualStyles()
$created=$false
$mutex=New-Object Threading.Mutex($true,'Local\StudyGuardActivityWatch',[ref]$created)
if (!$created -and !$SmokeTest -and !$NotificationTest -and !$PhoneTest -and !$ForestPreview) { $mutex.Dispose(); exit 0 }
$script:config=Get-Content -Raw -LiteralPath "$PSScriptRoot\config.json" | ConvertFrom-Json
$script:running=$false; $script:paused=$false; $script:updating=$true
$script:mode=if ($script:config.plannerMode -eq 'session') {'session'} else {'breaks'}
$script:plan=$null; $script:phase=$null; $script:sessionId=''
$script:clock=[Diagnostics.Stopwatch]::new(); $script:state=New-GuardState
$script:buckets=@(); $script:lastDiscovery=-100; $script:lastTick=0.0
$script:lastHealthLog=-100; $script:lastErrorLog=-100
$script:logPath=Join-Path $PSScriptRoot 'logs\sessions.jsonl'
$script:phoneState=New-PhoneState
$script:studyStats=New-StudyStats
$script:waitingBreak=$false; $script:elapsedOffset=0.0
$script:extraClock=[Diagnostics.Stopwatch]::new(); $script:extraStats=New-StudyStats
$script:extraCompleted=0.0; $script:extraFocusBefore=0.0
$script:extraPlan=[pscustomobject]@{Sessions=@(1.0e12);BreakSeconds=0}
$script:daily=if ($SmokeTest) {@{Path=(Join-Path $PSScriptRoot 'logs\daily-smoke.json');Days=@{};Observed=@{};Dirty=$false}} else {New-DailyFocus (Join-Path $PSScriptRoot 'logs\daily-focus.json') (Join-Path $PSScriptRoot 'logs\study-summaries.jsonl')}
$script:phoneJobs=New-Object Collections.ArrayList
$script:httpClient=[Net.Http.HttpClient]::new()
$script:httpClient.Timeout=[TimeSpan]::FromSeconds(10)
function Write-GuardLog($Type,$Details) {
 try {
  $null=[IO.Directory]::CreateDirectory((Split-Path $script:logPath))
  $row=@{timestamp=[DateTimeOffset]::UtcNow.ToString('o');session=$script:sessionId;type=$Type;details=$Details}
  [IO.File]::AppendAllText($script:logPath,(($row | ConvertTo-Json -Depth 8 -Compress)+[Environment]::NewLine),[Text.UTF8Encoding]::new($false))
 } catch { $script:logError=$_.Exception.Message }
}
$form=New-Object ForestWindow
$form.Text='StudyGuard - Pomodoro & focus reminders'
$form.Size=New-Object Drawing.Size(740,920)
$form.AutoScroll=$true
$form.StartPosition='CenterScreen'; $form.FormBorderStyle='FixedDialog'; $form.MaximizeBox=$false
$form.Font=New-Object Drawing.Font('Segoe UI',10)
function Add-Label($Text,$X,$Y,$Width,$Height) {
 $label=New-Object Windows.Forms.Label; $label.Text=$Text
 $label.Location=New-Object Drawing.Point($X,$Y); $label.Size=New-Object Drawing.Size($Width,$Height)
 $form.Controls.Add($label); return $label
}
function Add-Button($Text,$X,$Y,$Width,$Handler) {
 $button=New-Object Windows.Forms.Button; $button.Text=$Text
 $button.Location=New-Object Drawing.Point($X,$Y); $button.Size=New-Object Drawing.Size($Width,34)
 $button.Add_Click($Handler); $form.Controls.Add($button); return $button
}
function Add-Input($Text,$X,$Y) {
 $box=New-Object Windows.Forms.TextBox; $box.Text=$Text
 $box.Location=New-Object Drawing.Point($X,$Y); $box.Size=New-Object Drawing.Size(110,28)
 $form.Controls.Add($box); return $box
}
$null=Add-Label 'Your study plan' 20 15 680 30
$null=Add-Label 'Study hours (breaks excluded)' 20 55 270 26
$total=Add-Input $(if ($script:config.totalStudyHours) {[string]$script:config.totalStudyHours} else {'2'}) 305 55
$null=Add-Label 'Each break: minutes (fixed)' 20 95 270 26
$recess=Add-Input $(if ($script:config.breakMinutes) {[string]$script:config.breakMinutes} else {'5'}) 305 95
$null=Add-Label 'Number of breaks' 20 135 270 26
$breaks=Add-Input $(if ($null -ne $script:config.breakCount) {[string]$script:config.breakCount} else {'3'}) 305 135
$null=Add-Label 'Each focus session: minutes' 20 175 270 26
$session=Add-Input ([string]$script:config.sessionMinutes) 305 175
$preview=Add-Label '' 20 220 680 55; $preview.ForeColor=[Drawing.Color]::DarkSlateBlue
$status=Add-Label 'Ready. Click Start to begin.' 20 285 680 50
$health=Add-Label 'Chrome URL detection needs ActivityWatch Web Watcher.' 20 345 680 45
$health.ForeColor=[Drawing.Color]::DarkRed
$notice=Add-Label '' 20 400 470 45; $notice.ForeColor=[Drawing.Color]::DarkRed
$null=Add-Label 'Free phone reminders (ntfy)' 20 555 680 26
$phoneCheck=New-Object Windows.Forms.CheckBox
$phoneCheck.Text='Enable phone reminders'; $phoneCheck.Checked=[bool]$script:config.phoneEnabled
$phoneCheck.Location=New-Object Drawing.Point(20,590); $phoneCheck.Size=New-Object Drawing.Size(245,28)
$form.Controls.Add($phoneCheck)
$phoneTopic=Add-Input ([string]$script:config.phoneTopic) 275 590
$phoneTopic.Size=New-Object Drawing.Size(420,28)
$phoneStatus=Add-Label 'Install ntfy on your phone, subscribe to this exact topic, then enable and test.' 20 630 680 40
$null=Add-Button 'Save phone settings' 20 680 200 {
 try {
  if (!(Test-PhoneTopic $phoneTopic.Text)) {throw 'Topic must be 20-80 letters/digits/dashes/underscores. Use the generated random topic.'}
  $saved=Get-Content -Raw "$PSScriptRoot\config.json" | ConvertFrom-Json
  $saved | Add-Member -NotePropertyName phoneEnabled -NotePropertyValue $phoneCheck.Checked -Force
  $saved | Add-Member -NotePropertyName phoneTopic -NotePropertyValue $phoneTopic.Text -Force
  $saved | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 "$PSScriptRoot\config.json"
  $script:config.phoneEnabled=$phoneCheck.Checked; $script:config.phoneTopic=$phoneTopic.Text
  $script:phoneState=New-PhoneState
  $phoneStatus.Text='Saved. Test your phone delivery before relying on reminders.'
 } catch {$phoneStatus.Text=$_.Exception.Message}
}
$null=Add-Button 'Test phone' 235 680 150 {
 if (!$phoneCheck.Checked) {$phoneStatus.Text='Enable phone reminders and save settings first.'; return}
 Send-Phone 'test'
}
$null=Add-Button 'Get ntfy app' 400 680 150 {Start-Process 'https://docs.ntfy.sh/subscribe/phone/'}
$statsLabel=Add-Label 'Estimated focus: 0m | Distracted: 0m | Pending AFK: 0m | Unmeasured: 0m' 20 730 680 48
$focusBar=New-Object Windows.Forms.ProgressBar
$focusBar.Location=New-Object Drawing.Point(20,785); $focusBar.Size=New-Object Drawing.Size(680,18)
$form.Controls.Add($focusBar)
$null=Add-Label 'Focus estimate / elapsed study time. Breaks and paused time excluded.' 20 810 680 26
$dailyLabel=Add-Label '' 20 845 680 30

function Get-SessionElapsed {
 if ($SmokeTest -and $null -ne $script:testElapsed) {return [double]$script:testElapsed}
 return [math]::Max(0,$script:clock.Elapsed.TotalSeconds-$script:elapsedOffset)
}
function Get-ExtraElapsed {
 if ($SmokeTest -and $null -ne $script:testExtraElapsed) {return [double]$script:testExtraElapsed}
 return $script:extraClock.Elapsed.TotalSeconds
}
function Get-MonitorElapsed {return (Get-SessionElapsed)+$script:extraCompleted+$(if ($script:waitingBreak) {Get-ExtraElapsed} else {0})}
function Get-CombinedTotals {
 $combined=New-StudyStats
 foreach ($key in @('FocusSeconds','IdleSeconds','RuleSeconds','UnknownSeconds','PendingSeconds')) {$combined[$key]=$script:studyStats[$key]+$script:extraStats[$key]}
 return Get-StudyTotals $combined
}
function Format-StudyTime([double]$Seconds) {
 $rounded=[int][math]::Floor($Seconds)
 return ('{0}m {1:00}s' -f [int][math]::Floor($rounded/60),($rounded%60))
}
function Close-ExtraAccounting {
 if (!$script:waitingBreak) {return}
 Close-StudyAccounting $script:extraStats $script:extraPlan (Get-ExtraElapsed)
 Log-AfkDecisions
}

function Update-StatsView {
 $summary=Get-CombinedTotals
 Add-DailyFocus $script:daily $script:sessionId $summary.focusSeconds
 $dailyLabel.Text=('Today ({0}): estimated focus {1}' -f (Get-Date -Format 'yyyy-MM-dd'),(Format-StudyTime (Get-DailyFocusSeconds $script:daily)))
 $statsLabel.Text=('Estimated focus: {0} ({1}%) | Distracted: {2}`nPending AFK: {3} | Unmeasured: {4}' -f (Format-StudyTime $summary.focusSeconds),$summary.focusPercent,(Format-StudyTime $summary.distractedSeconds),(Format-StudyTime $summary.pendingSeconds),(Format-StudyTime $summary.unmeasuredSeconds)).Replace('`n',[Environment]::NewLine)
 $focusBar.Value=[int][math]::Min(100,[math]::Max(0,$summary.focusPercent))
}
function Save-StudySummary($Reason) {
 $summary=Get-CombinedTotals
 Write-GuardLog 'study-summary' @{reason=$Reason;totals=$summary}
 if (!$SmokeTest) {
  $path=Join-Path $PSScriptRoot 'logs\study-summaries.jsonl'
  $record=@{timestamp=[DateTimeOffset]::UtcNow.ToString('o');session=$script:sessionId;reason=$Reason;totals=$summary}
  [IO.File]::AppendAllText($path,(($record|ConvertTo-Json -Depth 8 -Compress)+[Environment]::NewLine),[Text.UTF8Encoding]::new($false))
 }
 Update-StatsView
 if (!$SmokeTest) {Save-DailyFocus $script:daily}
}
function Log-AfkDecisions {
 foreach ($decision in @($script:studyStats.Decisions.ToArray())) {Write-GuardLog 'afk-minute-review' $decision}
 $script:studyStats.Decisions.Clear()
 foreach ($decision in @($script:extraStats.Decisions.ToArray())) {Write-GuardLog 'extra-afk-minute-review' $decision}
 $script:extraStats.Decisions.Clear()
}

function Send-Phone($Kind,$CustomMessage='') {
 if (!$script:config.phoneEnabled) {return}
 if (!(Test-PhoneTopic $script:config.phoneTopic)) {$phoneStatus.Text='Invalid phone topic; sending disabled.'; return}
 $priority=if ($Kind -in @('urgent','break-urgent')) {5} else {4}
 $titles=@('Time to refocus','Your study goal is waiting','Come back to your focus session','One small step: return to studying')
 $title=if ($Kind -eq 'urgent') {$titles[($script:phoneState.Escalations-1)%$titles.Count]+' (#'+$script:phoneState.Escalations+')'} elseif ($Kind -eq 'test') {'StudyGuard phone test'} elseif ($Kind -eq 'distraction') {'Distraction detected - back to focus'} elseif ($Kind -eq 'break-ended') {'Break is over - time to focus'} else {'StudyGuard check-in'}
 $message=if ($Kind -eq 'test') {'Your phone reminders are connected.'} elseif ($Kind -eq 'distraction') {'A distraction was detected during your focus session. Please return to studying.'} elseif ($Kind -eq 'break-ended') {'Your break has ended. The next focus session has started - come back to your computer and continue studying.'} else {'Your focus session is running and the computer is idle. Please return to studying, or pause if you need a break.'}
 if ($Kind -in @('break-idle','break-urgent')) {
  $title=if ($Kind -eq 'break-urgent') {'Your break is waiting (#'+$script:phoneState.Escalations+')'} else {'Time to take your break'}
  $message='Your focus block is finished and the computer is idle. Click Start break to begin your full recess, or Pause if you are away.'
 }
 if ($Kind -eq 'break-start') {$title='Break started - extra focus recorded'; $message=$CustomMessage}
 # Only generic reminders leave the computer. No timeline, app names, titles or URLs.
 $payload=@{topic=$script:config.phoneTopic; title=$title; message=$message; priority=$priority; tags=@('books')}
 $content=[Net.Http.StringContent]::new(($payload|ConvertTo-Json -Compress),[Text.Encoding]::UTF8,'application/json')
 $task=$script:httpClient.PostAsync('https://ntfy.sh/',$content)
 $null=$script:phoneJobs.Add(@{task=$task; content=$content; kind=$Kind; session=$script:sessionId})
 $phoneStatus.Text='Sending phone reminder...'
}
function Poll-PhoneJobs {
 foreach ($job in @($script:phoneJobs.ToArray())) {
  if (!$job.task.IsCompleted) {continue}
  try {
   $response=$job.task.GetAwaiter().GetResult()
   if (!$response.IsSuccessStatusCode) {throw ('Phone service returned HTTP '+[int]$response.StatusCode)}
   $phoneStatus.Text='Phone reminder accepted by ntfy. Check your phone to confirm receipt.'
   Write-GuardLog 'phone-submitted' @{kind=$job.kind; sourceSession=$job.session}
   $response.Dispose()
  } catch {$phoneStatus.Text='Phone delivery failed: '+$_.Exception.Message; Write-GuardLog 'phone-error' @{kind=$job.kind;error=$_.Exception.Message}}
  finally {$job.content.Dispose(); $script:phoneJobs.Remove($job)}
 }
}
function Read-Number($Text) {
 $value=0.0
 if (![double]::TryParse($Text,[Globalization.NumberStyles]::Float,[Globalization.CultureInfo]::CurrentCulture,[ref]$value)) { throw 'Fill in the required plan fields with numbers.' }
 if ([double]::IsNaN($value) -or [double]::IsInfinity($value)) { throw 'Enter finite numbers.' }
 return $value
}
function Update-Plan($Source) {
 if ($script:updating -or $script:running) { return }
 $script:updating=$true
 try {
  if ($Source -eq 'recess') {
   $breaks.Text=''; $session.Text=''; $script:plan=$null
   $preview.Text='Break length changed. Enter a break count OR a focus-session length to rebuild the plan.'; return
  }
  if ($Source -in @('breaks','session')) { $script:mode=$Source }
  $valueText=if ($script:mode -eq 'breaks') {$breaks.Text} else {$session.Text}
  $script:plan=Get-StudyPlan ((Read-Number $total.Text)*60) (Read-Number $recess.Text) $script:mode (Read-Number $valueText)
  $breaks.Text=[string]$script:plan.Breaks
  if ($script:mode -eq 'breaks') { $session.Text=[string][math]::Round($script:plan.SessionSeconds/60.0,4) }
  $preview.Text=('{0} focus sessions; {1} min each; last {2} min. {3} breaks x {4} min. Total elapsed: {5} min.' -f $script:plan.Sessions.Count,[math]::Round($script:plan.SessionSeconds/60.0,2),[math]::Round($script:plan.Sessions[-1]/60.0,2),$script:plan.Breaks,[math]::Round($script:plan.BreakSeconds/60.0,2),[math]::Round($script:plan.WallSeconds/60.0,2))
 } catch { $script:plan=$null; $preview.Text=$_.Exception.Message }
 finally { $script:updating=$false }
}
$total.Add_TextChanged({Update-Plan 'total'}); $recess.Add_TextChanged({Update-Plan 'recess'})
$breaks.Add_TextChanged({Update-Plan 'breaks'}); $session.Add_TextChanged({Update-Plan 'session'})
$script:updating=$false; Update-Plan $script:mode
$tray=New-Object Windows.Forms.NotifyIcon
$tray.Icon=[Drawing.SystemIcons]::Information; $tray.Text='StudyGuard'; $tray.Visible=$true
$menu=New-Object Windows.Forms.ContextMenuStrip
$show=$menu.Items.Add('Show StudyGuard'); $show.Add_Click({$form.Show(); $form.WindowState='Normal'; $form.Activate()})
$stop=$menu.Items.Add('Stop plan'); $stop.Add_Click({Stop-Session})
$exit=$menu.Items.Add('Exit StudyGuard'); $exit.Add_Click({$form.Close()})
$tray.ContextMenuStrip=$menu
$tray.Add_DoubleClick({$form.Show(); $form.WindowState='Normal'; $form.Activate()})
function Notify-Study($Message,$Kind='distraction') {
 $title=switch ($Kind) {
  'complete' {'Congrats, you made it!'}
  'break' {'Congrats, you made it! Time for a break'}
  'focus' {'Break over - back to focus'}
  'idle' {'Still studying? Check in'}
  'test' {'StudyGuard notification test'}
  'tracking' {'StudyGuard - website tracking unavailable'}
  default {'StudyGuard - back to your goal'}
 }
 $notice.Text="$title $Message"
 try {
  $tray.BalloonTipTitle=$title; $tray.BalloonTipText=$Message; $tray.BalloonTipIcon='Info'
  $tray.ShowBalloonTip(8000)
  $soundStarted=[StudyGuardIdle]::PlayNotificationSound()
  Write-GuardLog 'notification-sound' @{event='Notification.Default';started=$soundStarted}
  Write-GuardLog 'notification-submitted' @{kind=$Kind;title=$title;message=$Message}
 } catch {Write-GuardLog 'notification-error' @{kind=$Kind;error=$_.Exception.Message}}
}
function Set-PlanInputs($Enabled) { foreach ($control in @($total,$recess,$breaks,$session)) {$control.Enabled=$Enabled} }
function Stop-Session {
 if ($script:running) {
  $script:extraClock.Stop(); Close-ExtraAccounting
  Close-StudyAccounting $script:studyStats $script:plan (Get-SessionElapsed)
  Log-AfkDecisions; Save-StudySummary 'stopped'
  Write-GuardLog 'stopped' @{elapsed=$script:clock.Elapsed.TotalSeconds}
 }
 $script:running=$false; $script:paused=$false; $script:clock.Stop()
 $script:waitingBreak=$false; $beginBreak.Enabled=$false
 $script:state=New-GuardState; $pause.Text='Pause'; Set-PlanInputs $true
 $script:phoneState=New-PhoneState
 $status.Text='Stopped. ActivityWatch continues until you quit its own tray icon.'
}
function Ensure-ActivityWatch {
 try {$null=Invoke-RestMethod 'http://127.0.0.1:5600/api/0/info' -TimeoutSec 1; return} catch {}
 $exe=Join-Path $PSScriptRoot 'app\activitywatch\aw-qt.exe'
 if (!(Test-Path -LiteralPath $exe)) {throw 'ActivityWatch executable missing from app folder.'}
 if (!(Get-Process aw-qt -ErrorAction SilentlyContinue)) {Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe) -WindowStyle Hidden}
}
$start=Add-Button 'Start' 20 460 95 {
 if ($script:running) {return}
 try {
  Update-Plan $script:mode
  if (!$script:plan) {throw $preview.Text}
  $script:config=Get-Content -Raw -LiteralPath "$PSScriptRoot\config.json" | ConvertFrom-Json
  $script:config | Add-Member -NotePropertyName totalStudyHours -NotePropertyValue (Read-Number $total.Text) -Force
  $script:config | Add-Member -NotePropertyName breakMinutes -NotePropertyValue (Read-Number $recess.Text) -Force
  $script:config | Add-Member -NotePropertyName breakCount -NotePropertyValue $script:plan.Breaks -Force
  $script:config | Add-Member -NotePropertyName sessionMinutes -NotePropertyValue ($script:plan.SessionSeconds/60.0) -Force
  $script:config | Add-Member -NotePropertyName plannerMode -NotePropertyValue $script:mode -Force
  if (!$SmokeTest) {$script:config | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 -LiteralPath "$PSScriptRoot\config.json"}
  Ensure-ActivityWatch
  $script:sessionId=[Guid]::NewGuid().ToString()
  $script:state=New-GuardState; $script:phase=Get-PlanPhase $script:plan 0
  $script:phoneState=New-PhoneState
  $script:studyStats=New-StudyStats; $script:extraStats=New-StudyStats; $script:extraClock.Reset(); $script:extraCompleted=0.0
  $script:waitingBreak=$false; $script:elapsedOffset=0.0; $beginBreak.Enabled=$false; Update-StatsView
  $script:clock.Restart(); $script:running=$true; $script:paused=$false; $script:lastTick=0
  $script:lastDiscovery=-100; $script:lastHealthLog=-100; $notice.Text=''; $pause.Text='Pause'
  $script:trackingWarned=$false; Set-PlanInputs $false
  Write-GuardLog 'started' @{plan=$script:plan;idleSeconds=$script:config.idleSeconds;distractionSeconds=$script:config.distractionSeconds}
  $status.Text='Starting focus session 1...'
 } catch {$status.Text=$_.Exception.Message}
}
$pause=Add-Button 'Pause' 125 460 95 {
 if (!$script:running) {return}
 $script:paused=!$script:paused; $script:state=New-GuardState
 $script:phoneState=New-PhoneState
 if ($script:paused) {$script:clock.Stop(); $script:extraClock.Stop(); $beginBreak.Enabled=$false; $pause.Text='Resume'; $status.Text='Paused: clock and reminders are paused.'}
 else {
  if ($script:waitingBreak) {$script:extraClock.Start(); $beginBreak.Enabled=$true} else {$script:clock.Start()}
  $script:lastTick=Get-MonitorElapsed; $pause.Text='Pause'
 }
 Write-GuardLog 'pause-changed' @{paused=$script:paused;elapsed=$script:clock.Elapsed.TotalSeconds}
 if ($script:paused) {
  Close-ExtraAccounting
  Close-StudyAccounting $script:studyStats $script:plan (Get-SessionElapsed)
  Log-AfkDecisions; Update-StatsView
  if (!$SmokeTest) {Save-DailyFocus $script:daily}
 }
}
$null=Add-Button 'Stop' 230 460 95 {Stop-Session}
$null=Add-Button 'Test alert' 335 460 120 {Notify-Study 'Notification + sound test. Do Not Disturb can hide banners.' 'test'}
$null=Add-Button 'Edit rules' 465 460 230 {
 if ($script:running -and !$script:paused) {
  $null=[Windows.Forms.MessageBox]::Show($form,'Pause your session before editing rules. This keeps your study statistics consistent.','Pause first')
  return
 }
 $updated=Show-RulesEditor $form $script:config "$PSScriptRoot\config.json"
 if ($null -ne $updated) {
  $script:config=$updated; $script:state=New-GuardState; $script:phoneState=New-PhoneState
  $notice.Text='Rules saved. New checks use your updated settings.'
 }
}
$null=Add-Button 'Chrome extension' 20 505 190 {Start-Process 'https://chromewebstore.google.com/detail/activitywatch-web-watcher/nglaklhklhcoonedhgnpgddginnjdadi'}
$null=Add-Button 'Activity dashboard' 220 505 190 {Start-Process 'http://localhost:5600'}
$null=Add-Button 'Diagnostic log' 420 505 190 {if (Test-Path $script:logPath) {Start-Process notepad.exe -ArgumentList ('"'+$script:logPath+'"')}}
$beginBreak=Add-Button 'Start break' 500 405 195 {
 if (!$script:running -or !$script:waitingBreak -or $script:paused) {return}
 $script:extraClock.Stop(); Close-ExtraAccounting
 $extraFocus=[math]::Max(0,$script:extraStats.FocusSeconds-$script:extraFocusBefore)
 $script:extraCompleted+=Get-ExtraElapsed
 $script:waitingBreak=$false; $beginBreak.Enabled=$false
 $script:clock.Start(); $script:state=New-GuardState; $script:phoneState=New-PhoneState
 Write-GuardLog 'break-confirmed' @{elapsed=(Get-SessionElapsed);extraFocusSeconds=$extraFocus}
 Update-StatsView
 if (!$SmokeTest) {Save-DailyFocus $script:daily}
 $message='Extra estimated focus before this break: '+(Format-StudyTime $extraFocus)+'. Your '+$script:plan.BreakSeconds/60+' minute break starts now.'
 Notify-Study $message 'break'
 Send-Phone 'break-start' $message
 $status.Text='Break started. The full break duration is available.'
}
$beginBreak.Enabled=$false
function Get-Latest($Bucket) {
 $id=[Uri]::EscapeDataString($Bucket.id)
 $events=@(Invoke-RestMethod "http://127.0.0.1:5600/api/0/buckets/$id/events?limit=1" -TimeoutSec 1 | ForEach-Object {$_})
 if ($events.Count -gt 0) {return $events[0]}; return $null
}
$timer=New-Object Windows.Forms.Timer; $timer.Interval=1000
$timer.Add_Tick({
 Poll-PhoneJobs
 Update-StatsView
 if (!$script:running -or $script:paused) {return}
 try {
  $elapsed=Get-SessionElapsed
  # Never consume break time before confirmation, including a delayed timer tick.
  if ($script:phase.Kind -eq 'focus' -and $script:phase.Index -lt $script:plan.Sessions.Count-1) {
   $boundary=($script:plan.Sessions[0..$script:phase.Index] | Measure-Object -Sum).Sum+$script:phase.Index*$script:plan.BreakSeconds
   if ($elapsed -ge $boundary) {
    $script:clock.Stop(); $script:elapsedOffset+=$elapsed-$boundary
    $elapsed=[double]$boundary
    if ($SmokeTest) {$script:testElapsed=$elapsed}
    $script:waitingBreak=$true; $beginBreak.Enabled=$true
    $script:extraStats.LastElapsed=0.0; $script:extraFocusBefore=$script:extraStats.FocusSeconds
    $script:extraClock.Restart()
    if ($SmokeTest) {$script:testExtraElapsed=0.0}
   }
  }
  $phase=Get-PlanPhase $script:plan $elapsed
  if ($phase.Key -ne $script:phase.Key) {
   Close-StudyAccounting $script:studyStats $script:plan $elapsed
   Log-AfkDecisions; Update-StatsView
  }
  if ($phase.Key -ne $script:phase.Key) {
   $script:state=New-GuardState
   $script:phoneState=New-PhoneState
   Write-GuardLog 'phase-changed' @{from=$script:phase.Key;to=$phase.Key;elapsed=$elapsed}
   if ($phase.Kind -eq 'complete') {
    Write-GuardLog 'completed' @{focusSeconds=$script:plan.FocusSeconds;elapsed=$elapsed}
    Save-StudySummary 'completed'
    $script:running=$false; $script:clock.Stop(); Set-PlanInputs $true; $pause.Text='Pause'
    $status.Text='Study plan complete. Well done!'
    $totals=Get-CombinedTotals
    Notify-Study "Plan complete! Estimated focus: $([math]::Round($totals.focusSeconds/60,1))m; distracted: $([math]::Round($totals.distractedSeconds/60,1))m; unmeasured: $([math]::Round($totals.unmeasuredSeconds/60,1))m." 'complete'; return
   }
   if ($phase.Kind -eq 'break') {Notify-Study "Session $($phase.Index+1) complete. Click Start break when ready; your break countdown has not started." 'break'}
   else {
    Notify-Study "Starting focus session $($phase.Index+1) of $($script:plan.Sessions.Count)." 'focus'
    if ($script:phase.Kind -eq 'break') {Send-Phone 'break-ended'}
   }
   $script:phase=$phase
  }
  $remaining=[TimeSpan]::FromSeconds([math]::Ceiling($phase.Remaining))
  if ($phase.Kind -eq 'break' -and !$script:waitingBreak) {
   $status.Text=('Break {0}/{1}: {2:mm\:ss} left. Reminders paused during recess.' -f ($phase.Index+1),$script:plan.Breaks,$remaining)
   $health.Text='Next focus session starts automatically when this break ends.'; return
  }
  $planElapsed=$elapsed
  $elapsed=Get-MonitorElapsed
  if (($elapsed-$script:lastTick) -gt 15) {$script:state=New-GuardState}
  $script:lastTick=$elapsed
  $idle=if ($SmokeTest -and $null -ne $script:testIdle) {$script:testIdle} else {[StudyGuardIdle]::Seconds()}
  $distraction=''; $app=''; $websiteReady=$false; $now=[DateTimeOffset]::UtcNow
  $monitorKnown=$false
  try {
   if (($elapsed-$script:lastDiscovery) -gt 15) {
    $info=Invoke-RestMethod 'http://127.0.0.1:5600/api/0/info' -TimeoutSec 1
    $map=Invoke-RestMethod 'http://127.0.0.1:5600/api/0/buckets/' -TimeoutSec 1
    $script:buckets=@($map.PSObject.Properties.Value | Where-Object {$_.hostname -eq $info.hostname})
    $script:lastDiscovery=$elapsed
    $webInstalled=@($script:buckets | Where-Object type -eq 'web.tab.current').Count -gt 0
    if (!$webInstalled -and !$script:trackingWarned) {
     Notify-Study 'No browser-extension data found. Enable Web Watcher; idle and app reminders still work.' 'tracking'
     $script:trackingWarned=$true
    }
   }
   $windowBucket=$script:buckets | Where-Object type -eq 'currentwindow' | Select-Object -First 1
   $window=if ($windowBucket) {Get-Latest $windowBucket} else {$null}
   $health.Text='Waiting for fresh ActivityWatch foreground data.'; $health.ForeColor=[Drawing.Color]::DarkRed
   if (Test-FreshEvent $window $now) {
    $app=[string]$window.data.app; $title=[string]$window.data.title; $url=[string]$window.data.url
    if ($app -match '^(chrome|msedge|firefox|brave|opera|vivaldi)\.exe$') {
     $browser=switch -Regex ($app) {'^chrome' {'chrome'; break}; '^msedge' {'edge'; break}; '^firefox' {'firefox'; break}; '^brave' {'brave'; break}; '^opera' {'opera'; break}; '^vivaldi' {'vivaldi'; break}}
     $webBuckets=@($script:buckets | Where-Object {$_.type -eq 'web.tab.current' -and $_.id -match [regex]::Escape($browser)})
     $web=$null
     foreach ($bucket in $webBuckets) {
      $event=Get-Latest $bucket
      if ((Test-FreshEvent $event $now) -and $event.data.url -and $event.data.title -and $title.Contains([string]$event.data.title)) {
       if (!$web -or [DateTimeOffset]::Parse($event.timestamp) -gt [DateTimeOffset]::Parse($web.timestamp)) {$web=$event}
      }
     }
     if ($web) {$url=[string]$web.data.url}
     if ($url) {$websiteReady=$true; $health.Text='Website detection active: '+([Uri]$url).Host; $health.ForeColor=[Drawing.Color]::DarkGreen}
     else {$health.Text='Website reminders INACTIVE: URL unavailable. Check the Chrome extension.'}
    } else {$health.Text="App monitoring active: $app. Idle threshold: $($script:config.idleSeconds)s."; $health.ForeColor=[Drawing.Color]::DarkGreen}
    $distraction=Get-Distraction $app $url $title $script:config
    $monitorKnown=($app -notmatch '^(chrome|msedge|firefox|brave|opera|vivaldi)\.exe$') -or $websiteReady
   }
  } catch {
   $health.Text='ActivityWatch unavailable. Idle reminders still active.'; $health.ForeColor=[Drawing.Color]::DarkRed
   $script:lastDiscovery=-100
   if ($elapsed-$script:lastErrorLog -gt 30) {Write-GuardLog 'monitor-error' @{error=$_.Exception.Message}; $script:lastErrorLog=$elapsed}
  }
  $alert=Step-Guard $script:state $elapsed $idle $distraction $script:config
  if ($script:waitingBreak) {Add-StudySample $script:extraStats $script:extraPlan (Get-ExtraElapsed) $idle $distraction $monitorKnown $script:config.idleSeconds}
  else {Add-StudySample $script:studyStats $script:plan $planElapsed $idle $distraction $monitorKnown $script:config.idleSeconds}
  Log-AfkDecisions; Update-StatsView
  if ($alert -eq 'idle') {
   $idleMessage=if ($script:waitingBreak) {'You are idle after your focus block. Click Start break and take your full recess.'} else {"No keyboard/mouse activity for $($script:config.idleSeconds)s. Still studying?"}
   Notify-Study $idleMessage 'idle'
  }
  if ($alert -eq 'distraction') {Notify-Study "$distraction for $($script:config.distractionSeconds)s. Return to your study goal." 'distraction'; Send-Phone 'distraction'}
  $phoneAction=Step-Phone $script:phoneState $elapsed $idle $script:config
  if ($phoneAction -and $script:waitingBreak) {$phoneAction=if ($phoneAction -eq 'urgent') {'break-urgent'} else {'break-idle'}}
  if ($phoneAction) {Send-Phone $phoneAction}
  if ($elapsed-$script:lastHealthLog -ge 15) {
   if (!$SmokeTest) {Save-DailyFocus $script:daily}
   Write-GuardLog 'monitor-sample' @{elapsed=[math]::Round($elapsed);phase=$phase.Key;extraWork=$script:waitingBreak;idleSeconds=[math]::Round($idle);app=$app;websiteReady=$websiteReady;matchedRule=$distraction}
   Write-GuardLog 'study-totals' (Get-CombinedTotals)
   $script:lastHealthLog=$elapsed
  }
  if ($script:waitingBreak) {$status.Text='Finishing up before break. Extra estimated focus: '+(Format-StudyTime ($script:extraStats.FocusSeconds-$script:extraFocusBefore))+'. Click Start break when ready.'}
  else {$status.Text=('Focus {0}/{1}: {2:mm\:ss} left. Idle: {3}s. {4}' -f ($phase.Index+1),$script:plan.Sessions.Count,$remaining,[int]$idle,$distraction)}
 } catch {$status.Text='Monitor error: '+$_.Exception.Message; Write-GuardLog 'timer-error' @{error=$_.Exception.Message}}
})
# Keep the window on the taskbar when minimized; the tray is an additional shortcut.
. (Join-Path $PSScriptRoot 'forest-theme.ps1')
$form.ShowInTaskbar=$true
if(Test-Path (Join-Path $PSScriptRoot 'StudyGuard.ico')) {$form.Icon=New-Object Drawing.Icon((Join-Path $PSScriptRoot 'StudyGuard.ico'));$tray.Icon=$form.Icon}
$form.Add_FormClosed({if ($script:running) {Stop-Session}; $timer.Stop(); $tray.Visible=$false; $tray.Dispose(); $script:httpClient.Dispose()})
if ($SmokeTest -or $NotificationTest -or $PhoneTest -or $ForestPreview) {
 if ($ForestPreview) {
  $form.Show(); [Windows.Forms.Application]::DoEvents()
  $b=New-Object Drawing.Bitmap($form.Width,$form.Height)
  $form.DrawToBitmap($b,(New-Object Drawing.Rectangle(0,0,$form.Width,$form.Height)))
  $b.Save((Join-Path $PSScriptRoot 'forest-preview.png')); $b.Dispose()
  $dpiInfo=@{dpi=[GuardDpi]::GetDpiForWindow($form.Handle);scale=$form.LayoutScale;clientWidth=$form.ClientSize.Width;clientHeight=$form.ClientSize.Height;timerWidth=$scene.Width;timerHeight=$scene.Height;exe=[Diagnostics.Process]::GetCurrentProcess().MainModule.ModuleName}
  foreach($control in @($start,$pause,$beginBreak,$total,$session,$recess,$breaks)){
   if($control.Width -le 0 -or $control.Height -le 0 -or $control.Left -lt 0 -or $control.Top -lt 0){throw 'Invalid scaled control bounds'}
  }
  $dpiInfo|ConvertTo-Json|Set-Content (Join-Path $PSScriptRoot 'dpi-verification.json')
  $phoneTopic.UseSystemPasswordChar=$true
  $script:forestSettings.Show($form);[Windows.Forms.Application]::DoEvents()
  $sb=New-Object Drawing.Bitmap($script:forestSettings.Width,$script:forestSettings.Height)
  $script:forestSettings.DrawToBitmap($sb,(New-Object Drawing.Rectangle(0,0,$sb.Width,$sb.Height)))
  $sb.Save((Join-Path $PSScriptRoot 'settings-preview.png'));$sb.Dispose();$script:forestSettings.Hide()
  $form.Hide(); $form.Dispose(); $tray.Dispose()
  if($created){$mutex.ReleaseMutex()};$mutex.Dispose(); exit
 }
 if (!$script:plan -or $script:plan.FocusSeconds -le 0) {throw 'Plan initialization failed.'}
 if ($SmokeTest) {
  $script:config.phoneEnabled=$false
  $script:updating=$true; $recess.Text='5'; $script:updating=$false
  $total.Text='2'; $breaks.Text='3'
  Update-Plan 'breaks'
  if ($session.Text -ne '30' -or $script:plan.WallSeconds -ne 8100) {throw 'Forward-linked controls failed'}
  $session.Text='25'
  if ($breaks.Text -ne '4' -or $script:plan.Sessions[-1] -ne 1200 -or $recess.Text -ne '5') {throw 'Reverse-linked controls failed'}
  $recess.Text='10'
  if ($breaks.Text -ne '' -or $session.Text -ne '' -or $null -ne $script:plan) {throw 'Changing fixed break duration must clear both derived fields'}
  $breaks.Text='3'
  if ($session.Text -ne '30' -or $script:plan.WallSeconds -ne 9000) {throw 'Plan rebuild after fixed duration change failed'}
  'Linked controls tested: forward, reverse, clear, rebuild.'
  # Exercise the actual GUI click and timer handlers with local fixtures.
  $script:testApp='douyin.exe'; $script:testIdle=0; $script:testElapsed=0; $script:testNotices=@()
  function Ensure-ActivityWatch {}
  function Invoke-RestMethod {
   param($Uri,$TimeoutSec)
   if ($Uri -like '*/info') {return [pscustomobject]@{hostname='test'}}
   if ($Uri -like '*/buckets/') {return [pscustomobject]@{window=[pscustomobject]@{id='window';type='currentwindow';hostname='test'}}}
   throw 'Unexpected fixture endpoint'
  }
  function Get-Latest($Bucket) {return [pscustomobject]@{timestamp=[DateTimeOffset]::UtcNow.ToString('o');duration=0;data=@{app=$script:testApp;title='test';url=''}}}
  function Notify-Study($Message,$Kind='distraction') {$script:testNotices += $Kind}
  $script:testPhoneNotices=@()
  $script:testPhoneMessages=@()
  function Send-Phone($Kind,$CustomMessage='') {$script:testPhoneNotices += $Kind; $script:testPhoneMessages += $CustomMessage}
  $flags=[Reflection.BindingFlags]'Instance,NonPublic'
  $click=$start.GetType().GetMethod('OnClick',$flags)
  $tick=$timer.GetType().GetMethod('OnTick',$flags)
  $null=$click.Invoke($start,@([EventArgs]::Empty))
  if (!$script:running) {throw ('Start handler failed: '+$status.Text)}
  for ($sec=0; $sec -le 32; $sec+=2) {$script:testElapsed=$sec; $null=$tick.Invoke($timer,@([EventArgs]::Empty))}
  if ($script:testNotices -notcontains 'distraction') {throw 'Distraction timer integration failed'}
  $script:testElapsed=34; $script:testIdle=120; $null=$tick.Invoke($timer,@([EventArgs]::Empty))
  if ($script:testNotices -notcontains 'idle') {throw 'Idle timer integration failed'}
  $script:testElapsed=36; $null=$tick.Invoke($timer,@([EventArgs]::Empty))
  if (@($script:testNotices | Where-Object {$_ -eq 'idle'}).Count -ne 1) {throw 'Idle deduplication failed in timer'}
  $script:testElapsed=1800; $null=$tick.Invoke($timer,@([EventArgs]::Empty))
  if ($script:testNotices -notcontains 'break' -or $script:phase.Kind -ne 'break') {throw 'Break transition integration failed'}
  if (!$script:waitingBreak -or $script:clock.IsRunning -or !$beginBreak.Enabled) {throw 'Break must wait for confirmation'}
  $beforeWait=$script:studyStats.LastElapsed
  $script:testElapsed=2100; $null=$tick.Invoke($timer,@([EventArgs]::Empty))
  if (!$script:waitingBreak -or $script:studyStats.LastElapsed -ne $beforeWait) {throw 'Waiting must not consume break or study time'}
  $script:testElapsed=1800
  $script:config.phoneEnabled=$true; $script:testApp='notepad.exe'; $script:testIdle=0
  for ($sec=1; $sec -le 40; $sec++) {$script:testExtraElapsed=$sec; $null=$tick.Invoke($timer,@([EventArgs]::Empty))}
  if ($script:extraStats.FocusSeconds -ne 40 -or $timer.Interval -ne 1000) {throw 'One-second extra focus sampling failed'}
  $null=$click.Invoke($pause,@([EventArgs]::Empty))
  if (!$script:paused -or $script:extraClock.IsRunning -or $beginBreak.Enabled) {throw 'Pause during extra work must freeze input accounting'}
  $script:testExtraElapsed=45; $null=$tick.Invoke($timer,@([EventArgs]::Empty))
  if ($script:extraStats.FocusSeconds -ne 40) {throw 'Paused extra work must not count as focus'}
  $script:testExtraElapsed=40; $null=$click.Invoke($pause,@([EventArgs]::Empty))
  if ($script:paused -or !$beginBreak.Enabled -or !$script:extraClock.IsRunning) {throw 'Extra-work resume failed'}
  $script:testIdle=120
  for ($sec=41; $sec -le 100; $sec++) {$script:testExtraElapsed=$sec; $null=$tick.Invoke($timer,@([EventArgs]::Empty))}
  if ($script:extraStats.IdleSeconds -ne 60) {throw 'Extra AFK minute must count as distracted'}
  if ($script:testPhoneNotices -notcontains 'break-idle') {throw 'Extra AFK must send a phone break reminder'}
  $script:testExtraElapsed=101; $null=$tick.Invoke($timer,@([EventArgs]::Empty))
  if ($script:testPhoneNotices -notcontains 'break-urgent') {throw 'Extra AFK must repeat on phone after one minute'}
  $null=$click.Invoke($beginBreak,@([EventArgs]::Empty))
  if ($script:waitingBreak -or !$script:clock.IsRunning -or $beginBreak.Enabled) {throw 'Break confirmation handler failed'}
  if ($script:testPhoneNotices -notcontains 'break-start' -or !($script:testPhoneMessages -match '0m 40s')) {throw 'Break start must report actual extra focused time on phone'}
  $script:testElapsed=2400; $script:testIdle=0; $null=$tick.Invoke($timer,@([EventArgs]::Empty))
  if ($script:testNotices -notcontains 'focus') {throw 'Focus resumption integration failed'}
  if (@($script:testPhoneNotices | Where-Object {$_ -eq 'break-ended'}).Count -ne 1) {throw 'Break-end phone reminder missing'}
  $script:testElapsed=2402; $null=$tick.Invoke($timer,@([EventArgs]::Empty))
  if (@($script:testPhoneNotices | Where-Object {$_ -eq 'break-ended'}).Count -ne 1) {throw 'Break-end phone reminder duplicated'}
  foreach ($end in @(4200,6600)) {
   $script:testElapsed=$end; $null=$tick.Invoke($timer,@([EventArgs]::Empty))
   if (!$script:waitingBreak) {throw 'Each break must require confirmation'}
   $null=$click.Invoke($beginBreak,@([EventArgs]::Empty))
   $script:testElapsed=$end+600; $null=$tick.Invoke($timer,@([EventArgs]::Empty))
  }
  $script:testElapsed=9000; $null=$tick.Invoke($timer,@([EventArgs]::Empty))
  if ($script:running -or $script:testNotices[-1] -ne 'complete') {throw 'Plan completion integration failed'}
  $stats=Get-StudyTotals $script:studyStats
  if ([math]::Abs($stats.observedStudySeconds-7200) -gt 0.01 -or $stats.pendingSeconds -ne 0) {throw 'Accounting integration must cover exactly study time, not breaks'}
  if ([math]::Abs(($stats.focusSeconds+$stats.distractedSeconds+$stats.unmeasuredSeconds)-7200) -gt 0.01) {throw 'Accounting totals do not reconcile'}
  $combined=Get-CombinedTotals
  if ($combined.observedStudySeconds -ne 7301 -or $combined.focusSeconds -ne ($stats.focusSeconds+40)) {throw 'Extra time must be included once in combined session totals'}
  if ([math]::Abs((Get-DailyFocusSeconds $script:daily)-$combined.focusSeconds) -gt 0.01) {throw 'Extra focus must enter daily totals once'}
  'Accounting integration tested: totals reconcile, breaks excluded, final pending minute settled.'
  'Timer handlers tested: distraction, idle, deduplication, break, resume, completion.'
  if (@($script:testPhoneNotices | Where-Object {$_ -eq 'break-ended'}).Count -ne 3) {throw 'Expected one phone reminder per confirmed break end'}
  'Phone break-end transitions tested: one reminder per break, no repeat on next tick.'
  'Extra focus tested: 1-second sampling, AFK, phone break reminder and extra-focus report, combined and daily totals; full break preserved.'
  $form.Show()
  [Windows.Forms.Application]::DoEvents()
  $form.WindowState='Minimized'
  [Windows.Forms.Application]::DoEvents()
  if (!$form.Visible -or !$form.ShowInTaskbar) {throw 'Minimized window must remain visible on the taskbar'}
  $form.WindowState='Normal'
  [Windows.Forms.Application]::DoEvents()
  if (!$form.Visible) {throw 'Restored window unexpectedly hidden'}
  'Taskbar behavior tested: minimize does not hide, restore stays visible.'
  $bitmap=New-Object Drawing.Bitmap($form.Width,$form.Height)
  $form.DrawToBitmap($bitmap,(New-Object Drawing.Rectangle(0,0,$form.Width,$form.Height)))
  $bitmap.Save((Join-Path $PSScriptRoot 'smoke-preview.png'))
  $bitmap.Dispose()
  $form.Hide()
 }
 if ($SmokeTest) {. (Join-Path $PSScriptRoot 'Test-DeskView.ps1')}
 'GUI and linked plan initialized; idle API: '+[StudyGuardIdle]::Seconds()
 if ($NotificationTest) {Notify-Study 'The updated notification system is ready.' 'test'; Start-Sleep -Seconds 3}
 if ($PhoneTest) {
  $script:config.phoneEnabled=$true
  Send-Phone 'test'
  $wait=[Diagnostics.Stopwatch]::StartNew()
  while ($script:phoneJobs.Count -gt 0 -and $wait.Elapsed.TotalSeconds -lt 12) {Start-Sleep -Milliseconds 100; Poll-PhoneJobs}
  if ($phoneStatus.Text -notlike 'Phone reminder accepted*') {throw $phoneStatus.Text}
  $phoneStatus.Text
 }
 $form.Dispose(); $tray.Dispose()
} else {$timer.Start(); [Windows.Forms.Application]::Run($form)}
if ($created) {$mutex.ReleaseMutex()}; $mutex.Dispose()
