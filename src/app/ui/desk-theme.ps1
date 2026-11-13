# Presentation layer only. Original planner, accounting and monitoring remain in FocusRelay.ps1.

function Desk-Color($hex) { [Drawing.ColorTranslator]::FromHtml($hex) }
function Desk-Place($c,$x,$y,$w,$h) { $c.SetBounds($x,$y,$w,$h) }
function Desk-Label($text,$x,$y,$w,$h,$size=10,$bold=$false) {
 $l=New-Object Windows.Forms.Label
 $l.Text=$text; $l.BackColor=[Drawing.Color]::Transparent; $l.ForeColor=Desk-Color '#345442'
 $l.Font=New-Object Drawing.Font('Segoe UI',$size,$(if($bold){[Drawing.FontStyle]::Bold}else{[Drawing.FontStyle]::Regular}))
 Desk-Place $l $x $y $w $h; $form.Controls.Add($l); $l.BringToFront(); return $l
}
$form.SuspendLayout()
$form.AutoScaleMode='None'; $form.Text='FocusRelay | The Quiet Desk'
$form.ClientSize=New-Object Drawing.Size(1080,790)
$form.BackColor=Desk-Color '#F5F5EC'
$form.Font=New-Object Drawing.Font('Segoe UI',9)
$form.AutoScroll=$true
# Move low-frequency tools into a separate settings window.
$script:deskSettings=New-Object Windows.Forms.Form
$script:deskSettings.Text='FocusRelay · Reminders & settings'
$script:deskSettings.ClientSize=New-Object Drawing.Size(650,550)
$script:deskSettings.BackColor=$form.BackColor
$script:deskSettings.Font=$form.Font; $script:deskSettings.StartPosition='CenterParent'
$script:deskSettings.FormBorderStyle='FixedDialog'; $script:deskSettings.MaximizeBox=$false
$script:deskSettings.Add_FormClosing({param($sender,$e) if($e.CloseReason -eq 'UserClosing'){$e.Cancel=$true;$sender.Hide()}})
$all=@($form.Controls)
$settingsButtons=@('Test alert','Edit rules','Chrome extension','Activity dashboard','Diagnostic log','Save phone settings','Test phone','Get ntfy app')
foreach($c in $all) {
 if($c -is [Windows.Forms.Button] -and $settingsButtons -contains $c.Text) { $script:deskSettings.Controls.Add($c) }
 elseif($c -eq $phoneCheck -or $c -eq $phoneTopic -or $c -eq $phoneStatus) {$script:deskSettings.Controls.Add($c)}
 elseif($c -is [Windows.Forms.Label] -and $c -notin @($preview,$status,$health,$notice,$statsLabel,$dailyLabel)) {$c.Visible=$false}
}
foreach($c in @($form.Controls)+@($script:deskSettings.Controls)) {
 $c.ForeColor=Desk-Color '#345442'
 if($c -is [Windows.Forms.Button]) {
  $c.FlatStyle='Flat'; $c.FlatAppearance.BorderSize=0; $c.BackColor=Desk-Color '#E0E8D7'
  $c.FlatAppearance.MouseOverBackColor=Desk-Color '#CDDCC2';$c.Cursor=[Windows.Forms.Cursors]::Hand
 } elseif($c -is [Windows.Forms.TextBox]) {$c.BackColor=Desk-Color '#FAFBF5';$c.BorderStyle='FixedSingle'}
}
$sy=240; $sx=24
foreach($c in @($script:deskSettings.Controls | Where-Object {$_ -is [Windows.Forms.Button]})) {
 Desk-Place $c $sx $sy 190 38; $sx+=204
 if($sx -gt 450){$sx=24;$sy+=50}
}
Desk-Place $phoneCheck 24 34 290 30
Desk-Place $phoneTopic 24 83 595 28
Desk-Place $phoneStatus 24 132 595 72

$card=New-Object Windows.Forms.Panel; $card.BackColor=Desk-Color '#FFFFFF';Desk-Place $card 24 105 284 492;$form.Controls.Add($card);$card.SendToBack()
$scene=New-Object DeskScene;Desk-Place $scene 332 105 724 397;$form.Controls.Add($scene);$scene.SendToBack()
$base=New-Object Windows.Forms.Panel;$base.BackColor=Desk-Color '#E6EEDC';Desk-Place $base 332 105 724 492;$form.Controls.Add($base);$base.SendToBack()
$footer=New-Object Windows.Forms.Panel;$footer.BackColor=Desk-Color '#EAEDE1';Desk-Place $footer 24 618 1032 148;$form.Controls.Add($footer);$footer.SendToBack()
$null=Desk-Label 'FocusRelay' 28 22 260 36 22 $true
$null=Desk-Label 'Your time, made visible. One quiet page at a time.' 30 65 630 25 10
$setting=New-Object Windows.Forms.Button;$setting.Text='Settings  ···';$setting.FlatStyle='Flat';$setting.FlatAppearance.BorderSize=0;$setting.BackColor=Desk-Color '#E0E8D7';Desk-Place $setting 900 34 156 38;$form.Controls.Add($setting)
$setting.Add_Click({$null=$script:deskSettings.ShowDialog($form)})
$null=Desk-Label 'One step at a time.' 44 126 245 30 15 $true
$null=Desk-Label 'Start small. Stay with this moment.' 44 164 245 25 9
$fields=@(@($total,'Study goal · hours',211),@($session,'Focus session · minutes',279),@($recess,'Each break · minutes',347),@($breaks,'Number of breaks · linked',415))
foreach($f in $fields){$null=Desk-Label $f[1] 44 $f[2] 240 24 9;Desk-Place $f[0] 44 ($f[2]+26) 244 29;$f[0].Font=New-Object Drawing.Font('Segoe UI',12)}
Desk-Place $preview 44 491 240 86;$preview.Font=New-Object Drawing.Font('Segoe UI',9)
Desk-Place $start 394 533 188 42;$start.Text='Start focus  →';$start.BackColor=Desk-Color '#365E43';$start.ForeColor=[Drawing.Color]::White
Desk-Place $pause 594 533 100 42
foreach($c in @($form.Controls)) {if($c -is [Windows.Forms.Button] -and $c.Text -eq 'Stop'){Desk-Place $c 706 533 100 42}}
Desk-Place $beginBreak 818 533 188 42;$beginBreak.Text='Start break';$beginBreak.BackColor=Desk-Color '#CFDDBF'
Desk-Place $status 354 503 682 26;$status.BackColor=Desk-Color '#E6EEDC';$status.Font=New-Object Drawing.Font('Segoe UI',9)
$status.Text='Ready. A small beginning is enough.'
$null=Desk-Label 'THE QUIET DESK  /  FOCUSRELAY' 354 110 450 22 9
Desk-Place $dailyLabel 44 635 500 28;$dailyLabel.Font=New-Object Drawing.Font('Segoe UI',12,[Drawing.FontStyle]::Bold);$dailyLabel.BackColor=$footer.BackColor
Desk-Place $statsLabel 44 678 670 43;$statsLabel.BackColor=$footer.BackColor;$statsLabel.Font=New-Object Drawing.Font('Segoe UI',9)
Desk-Place $focusBar 44 735 660 8
Desk-Place $health 740 637 290 55;$health.BackColor=$footer.BackColor;$health.Font=New-Object Drawing.Font('Segoe UI',9)
Desk-Place $notice 740 698 290 58;$notice.BackColor=$footer.BackColor;$notice.Font=New-Object Drawing.Font('Segoe UI',9)
$hint=Desk-Label 'Rest, stretch, drink some water. Return with one small step.' 336 602 720 16 8
$hint.Visible=$false
function Update-DeskView {
 $scene.PhaseText='MAKE ROOM FOR FOCUS';$scene.Progress=0
 $scene.Resting=$false;$scene.Paused=[bool]$script:paused
 $totals=Get-CombinedTotals
 $seconds=if($script:plan){$script:plan.Sessions[0]}else{1500}
 if($script:running) {
  if($script:waitingBreak){$scene.PhaseText='A MOMENT TO RESET';$scene.Progress=1;$seconds=0}
  else {
   $p=Get-PlanPhase $script:plan (Get-SessionElapsed)
   $seconds=$p.Remaining
   if($p.Kind -eq 'break'){
    $scene.Resting=$true;$scene.PhaseText='REST IS PART OF THE WORK';$length=$script:plan.BreakSeconds
   }else{
    $scene.PhaseText=('FOCUS  {0} / {1}' -f ($p.Index+1),$script:plan.Sessions.Count)
    $length=$script:plan.Sessions[$p.Index]
    $key=$script:sessionId+':'+$p.Index
    if($script:deskPhaseKey -ne $key){
     $script:deskFocusBaseline=if($p.Index -eq 0){0}else{[double]$script:deskLastTotal}
     $script:deskPhaseKey=$key
    }
    $script:deskIntervalSeconds=$length
   }
   if($length -gt 0){$scene.Progress=1-$seconds/$length}
  }
  if($script:paused){$scene.PhaseText='PAUSED · PICK UP WHERE YOU LEFT OFF'}
 }
 if($script:deskIntervalSeconds -gt 0){$scene.NoteProgress=[math]::Max(0.0,[math]::Min(1.0,($totals.focusSeconds-$script:deskFocusBaseline)/$script:deskIntervalSeconds))}
 $script:deskLastTotal=$totals.focusSeconds
 $seconds=[math]::Max(0,[math]::Ceiling($seconds))
 $scene.TimeText=('{0:00}:{1:00}' -f [int][math]::Floor($seconds/60),[int]($seconds%60))
 $scene.Invalidate()
}
$timer.Add_Tick({Update-DeskView})
$session.Add_TextChanged({Update-DeskView})
Update-DeskView
Update-StatsView
# All geometry is retained in 96-DPI logical units. Reflow at native display DPI.
foreach($panel in @($card,$base,$footer)) {$form.Controls.Remove($panel);$panel.Dispose()}
foreach($c in @($form.Controls)) {
 if($c -is [Windows.Forms.Label] -and $c.Left -ge 40 -and $c.Left -lt 308 -and $c.Top -ge 105 -and $c.Top -lt 597){$c.BackColor=[Drawing.Color]::White}
 if($c -is [Windows.Forms.Label] -and $c.Top -eq 110){$c.BackColor=Desk-Color '#E6EEDC'}
}
$script:deskBounds=@{}
foreach($window in @($form,$script:deskSettings)){
 foreach($c in @($window.Controls)){
  $script:deskBounds[$c]=@{Bounds=$c.Bounds; Font=$c.Font}
 }
}
function Set-DeskDpi($window,$width,$height){
 $dpi=[GuardDpi]::GetDpiForWindow($window.Handle)
 if($dpi -le 0){$dpi=96}
 $factor=$dpi/96.0
 if(($SmokeTest -or $DeskPreview) -and $env:FOCUSRELAY_TEST_SCALE){$factor=[double]$env:FOCUSRELAY_TEST_SCALE}
 $window.SuspendLayout();$window.AutoScrollPosition=New-Object Drawing.Point(0,0)
 foreach($c in @($window.Controls)){
  $b=$script:deskBounds[$c]
  if(!$b){continue}
  $r=$b.Bounds
  $c.SetBounds([int]($r.X*$factor),[int]($r.Y*$factor),[int]($r.Width*$factor),[int]($r.Height*$factor))
  $font=$b.Font
  $c.Font=New-Object Drawing.Font($font.FontFamily,([single]($font.Size*$factor/($dpi/96.0))),$font.Style)
 }
 if($window -eq $form){$form.LayoutScale=[single]$factor}
 $area=[Windows.Forms.Screen]::FromHandle($window.Handle).WorkingArea
 $window.AutoScroll=$true
 $window.AutoScrollMinSize=New-Object Drawing.Size([int]($width*$factor),[int]($height*$factor))
 $window.ClientSize=New-Object Drawing.Size([int][math]::Min($width*$factor,$area.Width-48),[int][math]::Min($height*$factor,$area.Height-80))
 $window.Left=[int][math]::Max($area.Left,[math]::Min($window.Left,$area.Right-$window.Width))
 $window.Top=[int][math]::Max($area.Top,[math]::Min($window.Top,$area.Bottom-$window.Height))
 $window.ResumeLayout($false);$window.Invalidate($true)
}
$form.Add_Shown({Set-DeskDpi $form 1080 790})
$form.Add_DpiChanged({Set-DeskDpi $form 1080 790})
$script:deskSettings.AutoScaleMode='None'
$script:deskSettings.Add_Shown({Set-DeskDpi $script:deskSettings 650 550})
$script:deskSettings.Add_DpiChanged({Set-DeskDpi $script:deskSettings 650 550})
$form.Add_FormClosed({$script:deskSettings.Dispose()})
$form.ResumeLayout($false)
