# Executed inside StudyGuard.exe --smoke-test, after the original engine checks.
$script:plan=Get-StudyPlan 50 5 'session' 25
$script:studyStats=New-StudyStats;$script:extraStats=New-StudyStats
$script:sessionId='desk-view-fixture';$script:running=$true;$script:waitingBreak=$false;$script:paused=$false
$script:testElapsed=0
Update-ForestView
if($scene.NoteProgress -ne 0 -or $scene.Resting -or $scene.TimeText -ne '25:00'){throw 'Desk initial state failed'}
$strip=New-Object Drawing.Bitmap(2172,437)
$sg=[Drawing.Graphics]::FromImage($strip);$sg.Clear([Drawing.ColorTranslator]::FromHtml('#F5F5EC'))
function Capture-Desk($x,$label){
 $sample=New-Object ForestScene;$sample.Size=New-Object Drawing.Size(724,397)
 foreach($name in @('Progress','NoteProgress','Resting','Paused','TimeText','PhaseText')){$sample.$name=$scene.$name}
 $image=New-Object Drawing.Bitmap(724,397)
 $sample.DrawToBitmap($image,(New-Object Drawing.Rectangle(0,0,724,397)))
 $sg.DrawImageUnscaled($image,$x,40)
 $font=New-Object Drawing.Font('Segoe UI',12,[Drawing.FontStyle]::Bold,[Drawing.GraphicsUnit]::Pixel)
 $brush=New-Object Drawing.SolidBrush([Drawing.ColorTranslator]::FromHtml('#365E43'))
 $sg.DrawString($label,$font,$brush,($x+22),14)
 $font.Dispose();$brush.Dispose();$image.Dispose();$sample.Dispose()
}
Capture-Desk 0 '01 / BEGIN'
$script:testElapsed=750;$script:studyStats.FocusSeconds=600
Update-ForestView
if([math]::Abs($scene.Progress-.5) -gt .0001 -or [math]::Abs($scene.NoteProgress-.4) -gt .0001){throw ('Desk must separate elapsed progress from credited focus: elapsed='+$scene.Progress+' ink='+$scene.NoteProgress+' total='+$totals.focusSeconds+' elapsed='+ (Get-SessionElapsed))}
Capture-Desk 724 '02 / 10 MINUTES OF ESTIMATED FOCUS'
$script:paused=$true;Update-ForestView
if(!$scene.Paused -or $scene.NoteProgress -ne .4){throw 'Pause must preserve notebook progress'}
$script:paused=$false;$script:testElapsed=1500;Update-ForestView
if(!$scene.Resting -or $scene.NoteProgress -ne .4){throw 'Break must close book without adding focus'}
Capture-Desk 1448 '03 / TAKE A REAL BREAK'
$script:testElapsed=1800;Update-ForestView
if($scene.Resting -or $scene.NoteProgress -ne 0){throw 'Next interval must start a fresh page'}
$script:testElapsed=2400;$script:studyStats.FocusSeconds=1200;Update-ForestView
if([math]::Abs($scene.NoteProgress-.4) -gt .0001){throw 'Later interval must use its own focus baseline'}
$script:sessionId='desk-view-new-session';$script:studyStats.FocusSeconds=0;$script:testElapsed=0;Update-ForestView
if($scene.NoteProgress -ne 0){throw 'New session must reset notebook progress'}
$sg.Dispose();$strip.Save((Join-Path $PSScriptRoot 'desk-states.png'));$strip.Dispose()
$script:running=$false;Update-ForestView
'Desk view tested: blank page, credited-focus ink, elapsed daylight, pause preservation, closed-book break, next-page and new-session reset.'

