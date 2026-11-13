# Presentation layer only. Original planner, accounting and monitoring remain in StudyGuard.ps1.

function Forest-Color($hex) { [Drawing.ColorTranslator]::FromHtml($hex) }
function Forest-Place($c,$x,$y,$w,$h) { $c.SetBounds($x,$y,$w,$h) }
function Forest-Label($text,$x,$y,$w,$h,$size=10,$bold=$false) {
 $l=New-Object Windows.Forms.Label
 $l.Text=$text; $l.BackColor=[Drawing.Color]::Transparent; $l.ForeColor=Forest-Color '#345442'
 $l.Font=New-Object Drawing.Font('Segoe UI',$size,$(if($bold){[Drawing.FontStyle]::Bold}else{[Drawing.FontStyle]::Regular}))
 Forest-Place $l $x $y $w $h; $form.Controls.Add($l); $l.BringToFront(); return $l
}
$form.SuspendLayout()
$form.AutoScaleMode='None'; $form.Text='StudyGuard | The Quiet Desk'
$form.ClientSize=New-Object Drawing.Size(1080,790)
$form.BackColor=Forest-Color '#F5F5EC'
$form.Font=New-Object Drawing.Font('Segoe UI',9)
$form.AutoScroll=$true
# Move low-frequency tools into a separate settings window.
$script:forestSettings=New-Object Windows.Forms.Form
$script:forestSettings.Text='StudyGuard · Reminders & settings'
$script:forestSettings.ClientSize=New-Object Drawing.Size(650,550)
$script:forestSettings.BackColor=$form.BackColor
$script:forestSettings.Font=$form.Font; $script:forestSettings.StartPosition='CenterParent'
$script:forestSettings.FormBorderStyle='FixedDialog'; $script:forestSettings.MaximizeBox=$false
$script:forestSettings.Add_FormClosing({param($sender,$e) if($e.CloseReason -eq 'UserClosing'){$e.Cancel=$true;$sender.Hide()}})
$all=@($form.Controls)
$settingsButtons=@('Test alert','Edit rules','Chrome extension','Activity dashboard','Diagnostic log','Save phone settings','Test phone','Get ntfy app')
foreach($c in $all) {
 if($c -is [Windows.Forms.Button] -and $settingsButtons -contains $c.Text) { $script:forestSettings.Controls.Add($c) }
 elseif($c -eq $phoneCheck -or $c -eq $phoneTopic -or $c -eq $phoneStatus) {$script:forestSettings.Controls.Add($c)}
 elseif($c -is [Windows.Forms.Label] -and $c -notin @($preview,$status,$health,$notice,$statsLabel,$dailyLabel)) {$c.Visible=$false}
}
foreach($c in @($form.Controls)+@($script:forestSettings.Controls)) {
 $c.ForeColor=Forest-Color '#345442'
 if($c -is [Windows.Forms.Button]) {
  $c.FlatStyle='Flat'; $c.FlatAppearance.BorderSize=0; $c.BackColor=Forest-Color '#E0E8D7'
  $c.FlatAppearance.MouseOverBackColor=Forest-Color '#CDDCC2';$c.Cursor=[Windows.Forms.Cursors]::Hand
 } elseif($c -is [Windows.Forms.TextBox]) {$c.BackColor=Forest-Color '#FAFBF5';$c.BorderStyle='FixedSingle'}
}
$sy=240; $sx=24
foreach($c in @($script:forestSettings.Controls | Where-Object {$_ -is [Windows.Forms.Button]})) {
 Forest-Place $c $sx $sy 190 38; $sx+=204
 if($sx -gt 450){$sx=24;$sy+=50}
}
Forest-Place $phoneCheck 24 34 290 30
Forest-Place $phoneTopic 24 83 595 28
Forest-Place $phoneStatus 24 132 595 72

$card=New-Object Windows.Forms.Panel; $card.BackColor=Forest-Color '#FFFFFF';Forest-Place $card 24 105 284 492;$form.Controls.Add($card);$card.SendToBack()
$scene=New-Object ForestScene;Forest-Place $scene 332 105 724 397;$form.Controls.Add($scene);$scene.SendToBack()
$base=New-Object Windows.Forms.Panel;$base.BackColor=Forest-Color '#E6EEDC';Forest-Place $base 332 105 724 492;$form.Controls.Add($base);$base.SendToBack()
$footer=New-Object Windows.Forms.Panel;$footer.BackColor=Forest-Color '#EAEDE1';Forest-Place $footer 24 618 1032 148;$form.Controls.Add($footer);$footer.SendToBack()
$null=Forest-Label 'StudyGuard' 28 22 260 36 22 $true
$null=Forest-Label 'Your time, made visible. One quiet page at a time.' 30 65 630 25 10
$setting=New-Object Windows.Forms.Button;$setting.Text='Settings  ···';$setting.FlatStyle='Flat';$setting.FlatAppearance.BorderSize=0;$setting.BackColor=Forest-Color '#E0E8D7';Forest-Place $setting 900 34 156 38;$form.Controls.Add($setting)
$setting.Add_Click({$null=$script:forestSettings.ShowDialog($form)})
$null=Forest-Label 'One step at a time.' 44 126 245 30 15 $true
$null=Forest-Label 'Start small. Stay with this moment.' 44 164 245 25 9
$fields=@(@($total,'Study goal · hours',211),@($session,'Focus session · minutes',279),@($recess,'Each break · minutes',347),@($breaks,'Number of breaks · linked',415))
foreach($f in $fields){$null=Forest-Label $f[1] 44 $f[2] 240 24 9;Forest-Place $f[0] 44 ($f[2]+26) 244 29;$f[0].Font=New-Object Drawing.Font('Segoe UI',12)}
Forest-Place $preview 44 491 240 86;$preview.Font=New-Object Drawing.Font('Segoe UI',9)
Forest-Place $start 394 533 188 42;$start.Text='Start focus  →';$start.BackColor=Forest-Color '#365E43';$start.ForeColor=[Drawing.Color]::White
Forest-Place $pause 594 533 100 42
foreach($c in @($form.Controls)) {if($c -is [Windows.Forms.Button] -and $c.Text -eq 'Stop'){Forest-Place $c 706 533 100 42}}
Forest-Place $beginBreak 818 533 188 42;$beginBreak.Text='Start break';$beginBreak.BackColor=Forest-Color '#CFDDBF'
Forest-Place $status 354 503 682 26;$status.BackColor=Forest-Color '#E6EEDC';$status.Font=New-Object Drawing.Font('Segoe UI',9)
$status.Text='Ready. A small beginning is enough.'
$null=Forest-Label 'THE QUIET DESK  /  STUDYGUARD' 354 110 450 22 9
Forest-Place $dailyLabel 44 635 500 28;$dailyLabel.Font=New-Object Drawing.Font('Segoe UI',12,[Drawing.FontStyle]::Bold);$dailyLabel.BackColor=$footer.BackColor
Forest-Place $statsLabel 44 678 670 43;$statsLabel.BackColor=$footer.BackColor;$statsLabel.Font=New-Object Drawing.Font('Segoe UI',9)
Forest-Place $focusBar 44 735 660 8
Forest-Place $health 740 637 290 55;$health.BackColor=$footer.BackColor;$health.Font=New-Object Drawing.Font('Segoe UI',9)
Forest-Place $notice 740 698 290 58;$notice.BackColor=$footer.BackColor;$notice.Font=New-Object Drawing.Font('Segoe UI',9)
$hint=Forest-Label 'Rest, stretch, drink some water. Return with one small step.' 336 602 720 16 8
$hint.Visible=$false
function Update-ForestView {
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
$timer.Add_Tick({Update-ForestView})
$session.Add_TextChanged({Update-ForestView})
Update-ForestView
Update-StatsView
# All geometry is retained in 96-DPI logical units. Reflow at native display DPI.
foreach($panel in @($card,$base,$footer)) {$form.Controls.Remove($panel);$panel.Dispose()}
foreach($c in @($form.Controls)) {
 if($c -is [Windows.Forms.Label] -and $c.Left -ge 40 -and $c.Left -lt 308 -and $c.Top -ge 105 -and $c.Top -lt 597){$c.BackColor=[Drawing.Color]::White}
 if($c -is [Windows.Forms.Label] -and $c.Top -eq 110){$c.BackColor=Forest-Color '#E6EEDC'}
}
$script:forestBounds=@{}
foreach($window in @($form,$script:forestSettings)){
 foreach($c in @($window.Controls)){
  $script:forestBounds[$c]=@{Bounds=$c.Bounds; Font=$c.Font}
 }
}
function Set-ForestDpi($window,$width,$height){
 $dpi=[GuardDpi]::GetDpiForWindow($window.Handle)
 if($dpi -le 0){$dpi=96}
 $factor=$dpi/96.0
 if(($SmokeTest -or $ForestPreview) -and $env:STUDYGUARD_TEST_SCALE){$factor=[double]$env:STUDYGUARD_TEST_SCALE}
 $window.SuspendLayout();$window.AutoScrollPosition=New-Object Drawing.Point(0,0)
 foreach($c in @($window.Controls)){
  $b=$script:forestBounds[$c]
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
$form.Add_Shown({Set-ForestDpi $form 1080 790})
$form.Add_DpiChanged({Set-ForestDpi $form 1080 790})
$script:forestSettings.AutoScaleMode='None'
$script:forestSettings.Add_Shown({Set-ForestDpi $script:forestSettings 650 550})
$script:forestSettings.Add_DpiChanged({Set-ForestDpi $script:forestSettings 650 550})
$form.Add_FormClosed({$script:forestSettings.Dispose()})
$form.ResumeLayout($false)
