function Get-StudyPlan([double]$FocusMinutes, [double]$BreakMinutes, [string]$Mode, [double]$Value) {
 if ($FocusMinutes -le 0 -or $FocusMinutes -gt 1440 -or $BreakMinutes -le 0 -or $BreakMinutes -gt 180) { throw 'Study hours: greater than 0, at most 24. Break minutes: greater than 0, at most 180.' }
 $focusSeconds = [int][math]::Round($FocusMinutes * 60)
 $breakSeconds = [int][math]::Round($BreakMinutes * 60)
 if ($Mode -eq 'breaks') {
  if ($Value -lt 0 -or $Value -ne [math]::Floor($Value) -or $Value -gt 100) { throw 'Break count must be a whole number from 0 to 100.' }
  $count = [int]$Value + 1
  $sessionSeconds = [int][math]::Floor($focusSeconds / $count)
 } else {
  if ($Value -le 0 -or $Value * 60 -gt $focusSeconds) { throw 'Session length must be positive and no longer than total study time.' }
  $sessionSeconds = [int][math]::Round($Value * 60)
  $count = [int][math]::Ceiling($focusSeconds / [double]$sessionSeconds)
  if ($count -gt 101) { throw 'Maximum 100 breaks. Choose longer sessions.' }
 }
 if ($sessionSeconds -lt 10) { throw 'Sessions must last at least 10 seconds.' }
 $sessions = @()
 for ($i=0; $i -lt $count; $i++) {
  $seconds = if ($i -eq $count-1) { $focusSeconds-$sessionSeconds*($count-1) } else { $sessionSeconds }
  $sessions += [int]$seconds
 }
 [pscustomobject]@{ FocusSeconds=$focusSeconds; BreakSeconds=$breakSeconds; Breaks=$count-1; SessionSeconds=$sessionSeconds; Sessions=$sessions; WallSeconds=$focusSeconds+($count-1)*$breakSeconds }
}
function Get-PlanPhase($Plan, [double]$Elapsed) {
 $cursor=0.0
 for ($i=0; $i -lt $Plan.Sessions.Count; $i++) {
  $end=$cursor+$Plan.Sessions[$i]
  if ($Elapsed -lt $end) { return [pscustomobject]@{ Kind='focus'; Index=$i; Remaining=$end-$Elapsed; Key="focus-$i" } }
  $cursor=$end
  if ($i -lt $Plan.Sessions.Count-1) {
   $end=$cursor+$Plan.BreakSeconds
   if ($Elapsed -lt $end) { return [pscustomobject]@{ Kind='break'; Index=$i; Remaining=$end-$Elapsed; Key="break-$i" } }
   $cursor=$end
  }
 }
 [pscustomobject]@{ Kind='complete'; Index=$Plan.Sessions.Count; Remaining=0; Key='complete' }
}
