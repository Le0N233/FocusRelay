function New-DailyFocus($Path,$SummaryPath) {
 $state=@{Path=$Path;Days=@{};Observed=@{};Dirty=$false}
 if (Test-Path -LiteralPath $Path) {
  $data=Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
  foreach ($day in $data.days.PSObject.Properties) {
   $state.Days[$day.Name]=@{}
   foreach ($session in $day.Value.PSObject.Properties) {$state.Days[$day.Name][$session.Name]=[double]$session.Value}
  }
 } elseif (Test-Path -LiteralPath $SummaryPath) {
  # Older sessions have only end timestamps: assign their totals to the local completion date.
  foreach ($line in Get-Content -LiteralPath $SummaryPath) {
   try {
    $row=$line | ConvertFrom-Json
    if (!$row.session) {continue}
    $day=([DateTimeOffset]::Parse($row.timestamp)).LocalDateTime.ToString('yyyy-MM-dd')
    if (!$state.Days.ContainsKey($day)) {$state.Days[$day]=@{}}
    $state.Days[$day][$row.session]=[double]$row.totals.focusSeconds
    $state.Dirty=$true
   } catch {continue}
  }
 }
 return $state
}
function Add-DailyFocus($State,[string]$Session,[double]$FocusSeconds,[datetime]$Now=(Get-Date)) {
 if (!$Session) {return}
 $previous=if ($State.Observed.ContainsKey($Session)) {[double]$State.Observed[$Session]} else {0.0}
 $delta=[math]::Max(0,$FocusSeconds-$previous)
 $State.Observed[$Session]=$FocusSeconds
 if ($delta -le 0) {return}
 $day=$Now.ToString('yyyy-MM-dd')
 if (!$State.Days.ContainsKey($day)) {$State.Days[$day]=@{}}
 if (!$State.Days[$day].ContainsKey($Session)) {$State.Days[$day][$Session]=0.0}
 $State.Days[$day][$Session]+=$delta; $State.Dirty=$true
}
function Get-DailyFocusSeconds($State,[datetime]$Now=(Get-Date)) {
 $day=$Now.ToString('yyyy-MM-dd'); $sum=0.0
 if ($State.Days.ContainsKey($day)) {foreach ($value in $State.Days[$day].Values) {$sum+=[double]$value}}
 return $sum
}
function Save-DailyFocus($State) {
 if (!$State.Dirty) {return}
 $null=[IO.Directory]::CreateDirectory((Split-Path $State.Path))
 $json=@{version=1;days=$State.Days} | ConvertTo-Json -Depth 8
 $temp=$State.Path+'.tmp'
 [IO.File]::WriteAllText($temp,$json,[Text.UTF8Encoding]::new($false))
 if (Test-Path -LiteralPath $State.Path) {[IO.File]::Replace($temp,$State.Path,$State.Path+'.bak')} else {[IO.File]::Move($temp,$State.Path)}
 $State.Dirty=$false
}
