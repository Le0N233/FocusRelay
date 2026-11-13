function Convert-RuleEntry([string]$Kind,[string]$Text) {
 $value=$Text.Trim()
 if (!$value) {throw 'Enter a value first.'}
 switch ($Kind) {
  'blockedDomains' {
   $uri=$null
   if ($value -notmatch '^https?://') {$value='https://'+$value}
   if (![Uri]::TryCreate($value,[UriKind]::Absolute,[ref]$uri) -or !$uri.Host.Contains('.') -or $uri.HostNameType -ne 'Dns') {throw 'Enter a website domain, e.g. bilibili.com.'}
   return $uri.Host.ToLowerInvariant()
  }
  'blockedApps' {
   $value=[IO.Path]::GetFileName($value).ToLowerInvariant()
   if ($value -notmatch '^[^\\/:*?"<>|]+\.exe$') {throw 'Enter an app filename such as discord.exe, or select an .exe file.'}
   return $value
  }
  'allowedYouTubeVideoIds' {
   if ($value -cmatch '^[a-zA-Z0-9_-]{11}$') {return $value}
   $uri=$null; $id=''
   if ([Uri]::TryCreate($value,[UriKind]::Absolute,[ref]$uri) -and $uri.Scheme -in @('http','https')) {
    if ($uri.Host -eq 'youtu.be') {$id=$uri.AbsolutePath.Trim('/')}
    elseif ($uri.Host -in @('youtube.com','www.youtube.com','m.youtube.com') -and $uri.AbsolutePath -eq '/watch') {
     foreach ($part in $uri.Query.TrimStart('?').Split('&')) {$pair=$part.Split('=',2); if ($pair.Length -eq 2 -and $pair[0] -ceq 'v') {$id=[Uri]::UnescapeDataString($pair[1]); break}}
    }
   }
   if ($id -cnotmatch '^[a-zA-Z0-9_-]{11}$') {throw 'Paste a YouTube watch link, youtu.be link, or 11-character video ID.'}
   return $id
  }
  'allowedUrlPrefixes' {
   $uri=$null
   if (![Uri]::TryCreate($value,[UriKind]::Absolute,[ref]$uri) -or $uri.Scheme -notin @('http','https')) {throw 'Enter a full URL starting with https:// or http://.'}
   return $uri.AbsoluteUri
  }
  'allowedTitlePatterns' {
   try {$null=[regex]::new($value)} catch {throw 'Invalid regular expression. Check the title pattern.'}
   return $value
  }
 }
 throw 'Unknown rule type.'
}

function New-RulesEditor($Config,[string]$ConfigPath) {
 $dialog=New-Object Windows.Forms.Form
 $dialog.Text='StudyGuard - Rules & reminders'; $dialog.ClientSize=New-Object Drawing.Size(780,590)
 $dialog.Font=New-Object Drawing.Font('Segoe UI',10); $dialog.StartPosition='CenterParent'
 $dialog.FormBorderStyle='FixedDialog'; $dialog.MaximizeBox=$false; $dialog.MinimizeBox=$false
 $tabs=New-Object Windows.Forms.TabControl; $tabs.Location=New-Object Drawing.Point(15,15); $tabs.Size=New-Object Drawing.Size(750,475)
 $dialog.Controls.Add($tabs)
 $numbers=@{}; $lists=@{}
 $timing=New-Object Windows.Forms.TabPage; $timing.Text='Reminder timing'; $tabs.TabPages.Add($timing)
 $rows=@(@('idleSeconds','Keyboard / mouse idle threshold','seconds',120),@('distractionSeconds','Time on a distracting app / website','seconds',30),@('cooldownSeconds','Repeat distraction reminder cooldown','seconds',180))
 $y=30
 foreach ($row in $rows) {
  $label=New-Object Windows.Forms.Label; $label.Text=$row[1]; $label.Location=New-Object Drawing.Point(20,$y); $label.Size=New-Object Drawing.Size(420,28); $timing.Controls.Add($label)
  $input=New-Object Windows.Forms.NumericUpDown; $input.Minimum=1; $input.Maximum=86400; $input.Value=if ($Config.($row[0])) {$Config.($row[0])} else {$row[3]}
  $input.Location=New-Object Drawing.Point(460,$y); $input.Size=New-Object Drawing.Size(110,28); $timing.Controls.Add($input); $numbers[$row[0]]=$input
  $unit=New-Object Windows.Forms.Label; $unit.Text=$row[2]; $unit.Location=New-Object Drawing.Point(585,$y); $unit.AutoSize=$true; $timing.Controls.Add($unit)
  $y+=65
 }
 $help=New-Object Windows.Forms.Label
 $help.Text="120 seconds = 2 minutes. Only the foreground app / tab is checked.`r`nThese rules send reminders, not block apps or websites.`r`nPhone idle follow-ups: every 60 seconds until activity returns.`r`nBreaks and paused sessions do not send reminders.`r`nStudy plan and phone connection are on the main window."
 $help.Location=New-Object Drawing.Point(20,245); $help.Size=New-Object Drawing.Size(680,160); $timing.Controls.Add($help)
 $definitions=@(
  @('blockedDomains','Distracting websites','Enter a domain or paste a URL. All its subdomains are included.','e.g. bilibili.com'),
  @('blockedApps','Distracting apps','Only foreground apps count; background music does not.','e.g. douyin.exe'),
  @('allowedYouTubeVideoIds','Allowed courses','Paste a YouTube video link. Only this video is allowed, not the playlist.','Paste your course video link here'),
  @('allowedUrlPrefixes','Allowed URLs','Advanced: all URLs beginning with this prefix are allowed. Avoid overly broad prefixes.','e.g. https://example.com/course/'),
  @('allowedTitlePatterns','Title patterns','Advanced: matching window titles are allowed. Patterns use regular expressions.','e.g. ^My course')
 )
 foreach ($definition in $definitions) {
  $key=$definition[0]
  $page=New-Object Windows.Forms.TabPage; $page.Text=$definition[1]; $tabs.TabPages.Add($page)
  $hint=New-Object Windows.Forms.Label; $hint.Text=$definition[2]; $hint.Location=New-Object Drawing.Point(15,15); $hint.Size=New-Object Drawing.Size(690,48); $page.Controls.Add($hint)
  $list=New-Object Windows.Forms.ListBox; $list.Location=New-Object Drawing.Point(15,65); $list.Size=New-Object Drawing.Size(695,230); $list.HorizontalScrollbar=$true
  foreach ($item in @($Config.$key)) {if ($item) {$null=$list.Items.Add([string]$item)}}
  $page.Controls.Add($list); $lists[$key]=$list
  $entry=New-Object Windows.Forms.TextBox; $entry.Location=New-Object Drawing.Point(15,305); $entry.Size=New-Object Drawing.Size(555,28); $page.Controls.Add($entry)
  $add=New-Object Windows.Forms.Button; $add.Text='Add'; $add.Location=New-Object Drawing.Point(580,303); $add.Size=New-Object Drawing.Size(130,32); $page.Controls.Add($add)
  $feedback=New-Object Windows.Forms.Label; $feedback.Text=$definition[3]; $feedback.Location=New-Object Drawing.Point(15,345); $feedback.Size=New-Object Drawing.Size(690,38); $page.Controls.Add($feedback)
  $add.Tag=@{Key=$key;Entry=$entry;List=$list;Feedback=$feedback}
  $add.Add_Click({
   $ctx=$this.Tag
   try {
    $value=Convert-RuleEntry $ctx.Key $ctx.Entry.Text
    $duplicate=$false
    foreach ($existing in $ctx.List.Items) {if (($ctx.Key -eq 'allowedYouTubeVideoIds' -and $existing -ceq $value) -or ($ctx.Key -ne 'allowedYouTubeVideoIds' -and $existing -eq $value)) {$duplicate=$true}}
    if ($duplicate) {throw 'This rule is already in the list.'}
    $null=$ctx.List.Items.Add($value); $ctx.Entry.Clear(); $ctx.Feedback.ForeColor=[Drawing.Color]::DarkGreen; $ctx.Feedback.Text='Added. Click Save rules to apply.'
   } catch {$ctx.Feedback.ForeColor=[Drawing.Color]::DarkRed; $ctx.Feedback.Text=$_.Exception.Message}
  })
  $remove=New-Object Windows.Forms.Button; $remove.Text='Remove selected'; $remove.Location=New-Object Drawing.Point(15,390); $remove.Size=New-Object Drawing.Size(170,32); $remove.Tag=$list; $page.Controls.Add($remove)
  $remove.Add_Click({if ($this.Tag.SelectedIndex -ge 0) {$this.Tag.Items.RemoveAt($this.Tag.SelectedIndex)}})
  if ($key -eq 'blockedApps') {
   $browse=New-Object Windows.Forms.Button; $browse.Text='Choose app .exe...'; $browse.Location=New-Object Drawing.Point(205,390); $browse.Size=New-Object Drawing.Size(180,32); $browse.Tag=$entry; $page.Controls.Add($browse)
   $browse.Add_Click({$picker=New-Object Windows.Forms.OpenFileDialog; $picker.Filter='Applications (*.exe)|*.exe'; try {if ($picker.ShowDialog() -eq 'OK') {$this.Tag.Text=[IO.Path]::GetFileName($picker.FileName)}} finally {$picker.Dispose()}})
  }
 }
 $status=New-Object Windows.Forms.Label; $status.Text='Course / URL / title allow-rules take priority. Save applies to the next checks.'
 $status.Location=New-Object Drawing.Point(15,500); $status.Size=New-Object Drawing.Size(750,34); $dialog.Controls.Add($status)
 $save=New-Object Windows.Forms.Button; $save.Text='Save rules'; $save.Location=New-Object Drawing.Point(480,545); $save.Size=New-Object Drawing.Size(135,32); $dialog.Controls.Add($save)
 $cancel=New-Object Windows.Forms.Button; $cancel.Text='Cancel'; $cancel.Location=New-Object Drawing.Point(630,545); $cancel.Size=New-Object Drawing.Size(135,32); $cancel.DialogResult='Cancel'; $dialog.Controls.Add($cancel); $dialog.CancelButton=$cancel
 $save.Tag=@{Path=$ConfigPath;Numbers=$numbers;Lists=$lists;Dialog=$dialog;Status=$status}
 $save.Add_Click({
  $ctx=$this.Tag
  try {
   # Read the latest file, preserving phone, study plan, and future config fields.
   $saved=Get-Content -Raw -LiteralPath $ctx.Path | ConvertFrom-Json
   foreach ($key in $ctx.Numbers.Keys) {$saved | Add-Member -NotePropertyName $key -NotePropertyValue ([int]$ctx.Numbers[$key].Value) -Force}
   foreach ($key in $ctx.Lists.Keys) {$saved | Add-Member -NotePropertyName $key -NotePropertyValue @($ctx.Lists[$key].Items | ForEach-Object {[string]$_}) -Force}
   $json=$saved | ConvertTo-Json -Depth 8
   $temp=$ctx.Path+'.rules-tmp'
   [IO.File]::WriteAllText($temp,$json,[Text.UTF8Encoding]::new($false))
   [IO.File]::Replace($temp,$ctx.Path,$ctx.Path+'.before-rules.bak')
   $ctx.Dialog.Tag=$saved; $ctx.Dialog.DialogResult='OK'; $ctx.Dialog.Close()
  } catch {$ctx.Status.ForeColor=[Drawing.Color]::DarkRed; $ctx.Status.Text='Not saved: '+$_.Exception.Message}
 })
 return @{Dialog=$dialog;Tabs=$tabs;Numbers=$numbers;Lists=$lists;Save=$save}
}

function Show-RulesEditor($Owner,$Config,$ConfigPath) {
 $ui=New-RulesEditor $Config $ConfigPath
 try {if ($ui.Dialog.ShowDialog($Owner) -eq 'OK') {return $ui.Dialog.Tag}} finally {$ui.Dialog.Dispose()}
 return $null
}
