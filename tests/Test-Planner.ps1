$testAppRoot=if(Test-Path (Join-Path $PSScriptRoot '../modules')){Split-Path $PSScriptRoot -Parent}else{Join-Path (Split-Path $PSScriptRoot -Parent) 'src/app'}
$testDataRoot=Join-Path $PSScriptRoot '.test-data'
$null=[IO.Directory]::CreateDirectory($testDataRoot)
if(!(Test-Path (Join-Path $testDataRoot 'config.json'))){Copy-Item (Join-Path $testAppRoot 'config.example.json') (Join-Path $testDataRoot 'config.json')}
$ErrorActionPreference='Stop'
. (Join-Path $testAppRoot 'modules/planner.ps1')
function Assert($condition,$message) {if (!$condition) {throw $message}}
$p=Get-StudyPlan 120 5 'breaks' 3
Assert ($p.Sessions.Count -eq 4 -and $p.SessionSeconds -eq 1800 -and $p.WallSeconds -eq 8100) '2h, 3 breaks => 4 x 30m, 135m elapsed'
Assert (($p.Sessions|Measure-Object -Sum).Sum -eq 7200) 'Breaks excluded from focus target'
$p=Get-StudyPlan 120 5 'session' 25
Assert ($p.Breaks -eq 4 -and $p.Sessions[-1] -eq 1200 -and $p.WallSeconds -eq 8400) '25m => 4 breaks and 20m final session'
$phase=Get-PlanPhase $p 1499
Assert ($phase.Kind -eq 'focus' -and $phase.Remaining -eq 1) 'Focus countdown'
Assert ((Get-PlanPhase $p 1500).Kind -eq 'break') 'Break boundary'
Assert ((Get-PlanPhase $p 1799).Remaining -eq 1) 'Break countdown'
Assert ((Get-PlanPhase $p 1800).Key -eq 'focus-1') 'Automatic focus resume'
Assert ((Get-PlanPhase $p 8399).Kind -eq 'focus') 'Final focus remains'
Assert ((Get-PlanPhase $p 8400).Kind -eq 'complete') 'No extra break at finish'
$p=Get-StudyPlan 120 5 'breaks' 0
Assert ($p.Sessions.Count -eq 1 -and $p.WallSeconds -eq 7200) 'Zero breaks'
$p=Get-StudyPlan 100 5 'breaks' 2
Assert (($p.Sessions|Measure-Object -Sum).Sum -eq 6000) 'Rounding preserves exact focus total'
$failed=$false
try {Get-StudyPlan 120 5 'breaks' 2.5 | Out-Null} catch {$failed=$true}
Assert $failed 'Fractional break count rejected'
Write-Output 'All Pomodoro planner assertions passed.'
