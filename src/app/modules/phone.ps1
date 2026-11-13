function New-PhoneState { return @{SentAt=$null; LastEscalation=$null; Escalations=0} }
function Step-Phone($State, [double]$Elapsed, [double]$Idle, $Config) {
 if (!$Config.phoneEnabled -or $Idle -lt $Config.idleSeconds) {
  $State.SentAt=$null; $State.LastEscalation=$null; $State.Escalations=0
  return ''
 }
 if ($null -eq $State.SentAt) { $State.SentAt=$Elapsed; return 'initial' }
 $previous=if ($null -eq $State.LastEscalation) {$State.SentAt} else {$State.LastEscalation}
 if ($Elapsed-$previous -ge 60) {
  $State.LastEscalation=$Elapsed; $State.Escalations++
  return 'urgent'
 }
 return ''
}
function Test-PhoneTopic($Topic) { return $Topic -match '^[a-zA-Z0-9_-]{20,80}$' }
