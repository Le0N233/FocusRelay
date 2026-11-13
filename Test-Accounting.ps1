$ErrorActionPreference='Stop'
. "$PSScriptRoot\planner.ps1"
. "$PSScriptRoot\accounting.ps1"
function Assert-Near($Actual,$Expected,$Message) {if ([math]::Abs($Actual-$Expected) -gt 0.001) {throw "$Message -- got $Actual expected $Expected"}}
$plan=Get-StudyPlan 10 1 'breaks' 0
$s=New-StudyStats
for ($t=2;$t -le 118;$t+=2) {Add-StudySample $s $plan $t 0 '' $true}
Add-StudySample $s $plan 120 120 '' $true
Assert-Near $s.FocusSeconds 118 'Initial AFK only starts from previous sample'
Assert-Near $s.PendingSeconds 2 'First AFK interval is pending'
for ($t=122;$t -le 178;$t+=2) {Add-StudySample $s $plan $t 120 '' $true}
Assert-Near $s.IdleSeconds 60 'First idle minute counted'
for ($t=180;$t -le 238;$t+=2) {Add-StudySample $s $plan $t 120 '' $true}
Assert-Near $s.IdleSeconds 120 'Continued idle minute accumulates'
# 20/30 active samples => >60%, discard this AFK minute.
for ($t=240;$t -le 258;$t+=2) {Add-StudySample $s $plan $t 10 '' $true}
for ($t=260;$t -le 298;$t+=2) {Add-StudySample $s $plan $t 0 '' $true}
Assert-Near $s.IdleSeconds 120 'Recovery minute not added to distraction'
Assert-Near $s.FocusSeconds 178 'Recovery minute restored to focus'
if ($s.AfkEpisode) {throw 'Recovery minute must end AFK episode'}
Add-StudySample $s $plan 300 0 'Site: youtube.com' $true
Assert-Near $s.RuleSeconds 2 'Rule-based distraction counted separately'
Assert-Near (Get-StudyTotals $s).observedStudySeconds 300 'No double counting'
# Exactly 60% still counts, since user specified MORE than 60%.
$s=New-StudyStats
Add-StudySample $s $plan 2 120 '' $true
for ($t=4;$t -le 24;$t+=2) {Add-StudySample $s $plan $t 10 'App: game.exe' $true}
for ($t=26;$t -le 60;$t+=2) {Add-StudySample $s $plan $t 0 '' $true}
Assert-Near $s.IdleSeconds 60 '60% boundary is not above threshold'
Assert-Near $s.RuleSeconds 0 'AFK and app distraction overlap counted once'
# Stop settles a partial minute based on its observed ratio, excludes unsampled tail.
$s=New-StudyStats
Add-StudySample $s $plan 2 120 '' $true
Add-StudySample $s $plan 4 120 '' $true
Close-StudyAccounting $s $plan 5
Assert-Near $s.IdleSeconds 4 'Partial-minute classification on stop'
Assert-Near $s.UnknownSeconds 1 'Unsampled stop tail not assumed focused'
# Breaks, coverage gaps and phase boundaries preserve accounting identity.
$plan=Get-StudyPlan 2 1 'breaks' 1
$s=New-StudyStats
for ($t=2;$t -le 60;$t+=2) {Add-StudySample $s $plan $t 0 '' $true}
for ($t=62;$t -le 120;$t+=2) {Add-StudySample $s $plan $t 0 '' $true}
for ($t=122;$t -le 180;$t+=2) {Add-StudySample $s $plan $t 0 '' $true}
Assert-Near (Get-StudyTotals $s).observedStudySeconds 120 'Break excluded'
Assert-Near $s.FocusSeconds 120 'Exact study target preserved'
$s=New-StudyStats
Add-StudySample $s $plan 30 0 '' $true
Assert-Near $s.UnknownSeconds 30 'Large monitoring gap unmeasured'
$s=New-StudyStats
Add-StudySample $s $plan 2 0 '' $false
Assert-Near $s.UnknownSeconds 2 'Missing page data unmeasured'
'All focus/AFK accounting assertions passed.'
