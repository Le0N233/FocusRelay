function New-StudyStats {
 return @{LastElapsed=0.0; FocusSeconds=0.0; IdleSeconds=0.0; RuleSeconds=0.0; UnknownSeconds=0.0; AfkEpisode=$false; PendingSeconds=0.0; ActiveSeconds=0.0; PendingRule=0.0; PendingUnknown=0.0; MinuteStart=0.0; Decisions=(New-Object Collections.ArrayList)}
}
function Complete-AfkMinute($State) {
 if ($State.PendingSeconds -le 0) {return}
 $ratio=$State.ActiveSeconds/$State.PendingSeconds
 $recovered=$ratio -gt 0.60
 if ($recovered) {
  $State.RuleSeconds+=$State.PendingRule
  $State.UnknownSeconds+=$State.PendingUnknown
  $State.FocusSeconds+=[math]::Max(0,$State.PendingSeconds-$State.PendingRule-$State.PendingUnknown)
  $State.AfkEpisode=$false
 } else {
  # Count the minute once; app/site distraction and AFK never double-count.
  $State.IdleSeconds+=$State.PendingSeconds
 }
 $null=$State.Decisions.Add([pscustomobject]@{start=$State.MinuteStart;duration=$State.PendingSeconds;activeRatio=[math]::Round($ratio,4);countedAsAfk=(!$recovered)})
 $State.PendingSeconds=0.0; $State.ActiveSeconds=0.0; $State.PendingRule=0.0; $State.PendingUnknown=0.0
}
function Add-StudySample($State,$Plan,[double]$Elapsed,[double]$Idle,[string]$MatchedRule,[bool]$MonitorKnown,[double]$IdleThreshold=120) {
 $from=[double]$State.LastElapsed
 if ($Elapsed -le $from) {return}
 $delta=$Elapsed-$from
 $gap=$delta -gt 15
 # Each sample is active if input occurred during that sampling interval (normally 1 second).
 $active=$Idle -le [math]::Min(3.0,$delta+0.25)
 $cursor=$from
 while ($cursor -lt $Elapsed-0.00001) {
  $phase=Get-PlanPhase $Plan $cursor
  if ($phase.Kind -eq 'complete') {break}
  $length=[math]::Min($phase.Remaining,$Elapsed-$cursor)
  if ($phase.Kind -ne 'focus') {
   Complete-AfkMinute $State; $State.AfkEpisode=$false
   $cursor+=$length; continue
  }
  if ($gap) {
   Complete-AfkMinute $State; $State.AfkEpisode=$false
   $State.UnknownSeconds+=$length; $cursor+=$length; continue
  }
  if (!$State.AfkEpisode -and $Idle -ge $IdleThreshold) {
   $State.AfkEpisode=$true; $State.MinuteStart=$cursor
  }
  if ($State.AfkEpisode) {
   if ($State.PendingSeconds -eq 0) {$State.MinuteStart=$cursor}
   $part=[math]::Min($length,60-$State.PendingSeconds)
   $State.PendingSeconds+=$part
   if ($active) {$State.ActiveSeconds+=$part}
   if ($MatchedRule) {$State.PendingRule+=$part} elseif (!$MonitorKnown) {$State.PendingUnknown+=$part}
   $cursor+=$part
   if ($State.PendingSeconds -ge 59.99999) {Complete-AfkMinute $State}
  } else {
   if ($MatchedRule) {$State.RuleSeconds+=$length}
   elseif (!$MonitorKnown) {$State.UnknownSeconds+=$length}
   else {$State.FocusSeconds+=$length}
   $cursor+=$length
  }
 }
 $State.LastElapsed=$Elapsed
}
function Close-StudyAccounting($State,$Plan,[double]$Elapsed) {
 # Between the last sample and pause/stop there is no input observation: mark that tail unmeasured.
 $cursor=[double]$State.LastElapsed
 while ($cursor -lt $Elapsed-0.00001) {
  $phase=Get-PlanPhase $Plan $cursor
  if ($phase.Kind -eq 'complete') {break}
  $part=[math]::Min($phase.Remaining,$Elapsed-$cursor)
  if ($phase.Kind -eq 'focus') {$State.UnknownSeconds+=$part}
  $cursor+=$part
 }
 $State.LastElapsed=$Elapsed
 Complete-AfkMinute $State; $State.AfkEpisode=$false
}
function Get-StudyTotals($State) {
 $distraction=$State.IdleSeconds+$State.RuleSeconds
 $total=$State.FocusSeconds+$distraction+$State.UnknownSeconds+$State.PendingSeconds
 [pscustomobject]@{focusSeconds=[math]::Round($State.FocusSeconds,2); distractedSeconds=[math]::Round($distraction,2);afkSeconds=[math]::Round($State.IdleSeconds,2);ruleSeconds=[math]::Round($State.RuleSeconds,2);pendingSeconds=[math]::Round($State.PendingSeconds,2);unmeasuredSeconds=[math]::Round($State.UnknownSeconds,2);observedStudySeconds=[math]::Round($total,2);focusPercent=$(if ($total -gt 0) {[math]::Round(100*$State.FocusSeconds/$total,1)} else {0})}
}
