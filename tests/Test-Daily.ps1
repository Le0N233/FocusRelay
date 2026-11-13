$testAppRoot=if(Test-Path (Join-Path $PSScriptRoot '../modules')){Split-Path $PSScriptRoot -Parent}else{Join-Path (Split-Path $PSScriptRoot -Parent) 'src/app'}
$testDataRoot=Join-Path $PSScriptRoot '.test-data'
$null=[IO.Directory]::CreateDirectory($testDataRoot)
if(!(Test-Path (Join-Path $testDataRoot 'config.json'))){Copy-Item (Join-Path $testAppRoot 'config.example.json') (Join-Path $testDataRoot 'config.json')}
$ErrorActionPreference='Stop'
. (Join-Path $testAppRoot 'modules/daily.ps1')
function Assert($Condition,$Message) {if (!$Condition) {throw $Message}}
$folder=Join-Path $testDataRoot ('logs\daily-test-'+[guid]::NewGuid().ToString('N'))
$null=[IO.Directory]::CreateDirectory($folder)
$path=Join-Path $folder 'daily.json'
$summaries=Join-Path $folder 'summaries.jsonl'
$day=[datetime]'2026-10-14T12:00:00'
$s=New-DailyFocus $path $summaries
Add-DailyFocus $s 'one' 120 $day
Add-DailyFocus $s 'one' 120 $day
Add-DailyFocus $s 'one' 180 $day
Add-DailyFocus $s 'two' 60 $day
Assert ((Get-DailyFocusSeconds $s $day) -eq 240) 'Multiple sessions without repeated-count inflation'
Save-DailyFocus $s
$loaded=New-DailyFocus $path $summaries
Assert ((Get-DailyFocusSeconds $loaded $day) -eq 240) 'Persistent daily total survives reopening'
$tomorrow=$day.AddDays(1)
Add-DailyFocus $s 'one' 240 $tomorrow
Assert ((Get-DailyFocusSeconds $s $tomorrow) -eq 60) 'Date rollover assigns only newly credited focus'
Assert ((Get-DailyFocusSeconds $s $day) -eq 240) 'Previous date retained'
$legacyPath=Join-Path $folder 'legacy-daily.json'
$row=@{timestamp=[DateTimeOffset]::new($day).ToString('o');session='legacy';totals=@{focusSeconds=300}}
[IO.File]::WriteAllText($summaries,(($row|ConvertTo-Json -Compress)+[Environment]::NewLine)*2)
$legacy=New-DailyFocus $legacyPath $summaries
Assert ((Get-DailyFocusSeconds $legacy $day) -eq 300) 'Legacy migration deduplicates session summaries'
Save-DailyFocus $legacy
Assert ((Get-DailyFocusSeconds (New-DailyFocus $legacyPath $summaries) $day) -eq 300) 'Migration does not re-import history on restart'
'Daily focus tests passed: accumulation, no double-counting, persistence, rollover, legacy migration.'
