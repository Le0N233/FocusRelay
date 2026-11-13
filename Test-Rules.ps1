$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\rules.ps1"
$config = [pscustomobject]@{blockedDomains=@('youtube.com','youtu.be','bilibili.com');blockedApps=@('steam.exe','discord.exe','douyin.exe');allowedYouTubeVideoIds=@('jYtIOLm8HzQ');allowedUrlPrefixes=@();allowedTitlePatterns=@();idleSeconds=120;distractionSeconds=30;cooldownSeconds=180}
function Assert($Condition, $Message) { if (!$Condition) { throw $Message } }
Assert ((Get-Distraction 'chrome.exe' 'https://www.bilibili.com/video/abc' 'video' $config) -eq 'Site: bilibili.com') 'Subdomain rule'
Assert ((Get-Distraction 'chrome.exe' 'https://notyoutube.com' 'YouTube' $config) -eq '') 'Domain boundary'
Assert ((Get-Distraction 'notepad.exe' 'https://youtube.com' 'video' $config) -eq '') 'Background browser rule'
Assert ((Get-Distraction 'chrome.exe' 'https://www.youtube.com/watch?list=abc&v=jYtIOLm8HzQ&index=8' 'lecture' $config) -eq '') 'Exact course video with reordered parameters'
Assert ((Get-Distraction 'chrome.exe' 'https://www.youtube.com/watch?v=jYtIOLm8HzQOTHER' 'video' $config) -eq 'Site: youtube.com') 'Different video remains distracting'
Assert ((Get-Distraction 'chrome.exe' 'https://youtu.be/jYtIOLm8HzQ' 'lecture' $config) -eq '') 'Course short link'
$config.allowedUrlPrefixes = @('https://www.youtube.com/watch?v=lecture')
Assert ((Get-Distraction 'chrome.exe' 'https://www.youtube.com/watch?v=lecture' 'lecture' $config) -eq '') 'Lecture whitelist'
$state = New-GuardState
Assert ((Step-Guard $state 0 0 'Site: youtube.com' $config) -eq '') 'Grace starts'
Assert ((Step-Guard $state 29 0 'Site: youtube.com' $config) -eq '') 'Grace boundary'
Assert ((Step-Guard $state 30 0 'Site: youtube.com' $config) -eq 'distraction') 'Grace expiry'
Assert ((Step-Guard $state 31 0 'Site: youtube.com' $config) -eq '') 'Cooldown'
Assert ((Step-Guard $state 210 0 'Site: youtube.com' $config) -eq 'distraction') 'Repeat reminder'
Assert ((Step-Guard $state 211 119 '' $config) -eq '') 'Idle grace before two minutes'
Assert ((Step-Guard $state 212 120 '' $config) -eq 'idle') 'Idle threshold at two minutes'
Assert ((Step-Guard $state 212 301 '' $config) -eq '') 'Idle deduplication'
$null = Step-Guard $state 213 0 '' $config
Assert ((Step-Guard $state 514 301 '' $config) -eq 'idle') 'Idle rearm'
$state = New-GuardState
$null = Step-Guard $state 0 0 'Site: youtube.com' $config
$null = Step-Guard $state 20 0 '' $config
Assert ((Step-Guard $state 30 0 'Site: youtube.com' $config) -eq '') 'Continuous visit reset'
$now = [DateTimeOffset]::UtcNow
$fresh = @{ timestamp = $now.AddSeconds(-100).ToString('o'); duration = 95 }
$stale = @{ timestamp = $now.AddSeconds(-100).ToString('o'); duration = 10 }
Assert (Test-FreshEvent $fresh $now) 'Long current event freshness'
Assert (!(Test-FreshEvent $stale $now)) 'Stale event rejected'
Write-Output 'All rule assertions passed, including two-minute idle and exact course video whitelist.'
