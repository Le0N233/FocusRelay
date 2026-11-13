$ErrorActionPreference='Stop'
. "$PSScriptRoot\phone.ps1"
function Assert($condition,$message) {if (!$condition) {throw $message}}
$config=[pscustomobject]@{phoneEnabled=$true;idleSeconds=120}
$state=New-PhoneState
Assert ((Step-Phone $state 119 119 $config) -eq '') 'No alert before two minutes'
Assert ((Step-Phone $state 120 120 $config) -eq 'initial') 'Initial two-minute phone reminder'
Assert ((Step-Phone $state 179 179 $config) -eq '') 'No early escalation'
Assert ((Step-Phone $state 180 180 $config) -eq 'urgent') 'Escalate one minute after first reminder'
Assert ((Step-Phone $state 240 240 $config) -eq 'urgent') 'Next one-minute reminder'
Assert ((Step-Phone $state 299 299 $config) -eq '') 'Repeat cooldown'
Assert ((Step-Phone $state 300 300 $config) -eq 'urgent') 'Second urgent reminder'
Assert ((Step-Phone $state 360 360 $config) -eq 'urgent') 'Third urgent reminder'
Assert ((Step-Phone $state 420 420 $config) -eq 'urgent') 'Reminders continue while away'
Assert ((Step-Phone $state 421 0 $config) -eq '') 'Activity cancels episode'
Assert ((Step-Phone $state 542 121 $config) -eq 'initial') 'Next idle spell re-arms'
$config.phoneEnabled=$false
Assert ((Step-Phone $state 1000 999 $config) -eq '') 'Disabled phone reminders stay silent'
Assert (!(Test-PhoneTopic 'short')) 'Reject guessable short topic'
Assert (Test-PhoneTopic 'studyguard-12345678901234567890123456789012') 'Accept random topic'
'All phone escalation assertions passed.'
