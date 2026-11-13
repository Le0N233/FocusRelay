$testAppRoot=if(Test-Path (Join-Path $PSScriptRoot '../modules')){Split-Path $PSScriptRoot -Parent}else{Join-Path (Split-Path $PSScriptRoot -Parent) 'src/app'}
$testDataRoot=Join-Path $PSScriptRoot '.test-data'
$null=[IO.Directory]::CreateDirectory($testDataRoot)
if(!(Test-Path (Join-Path $testDataRoot 'config.json'))){Copy-Item (Join-Path $testAppRoot 'config.example.json') (Join-Path $testDataRoot 'config.json')}
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
. (Join-Path $testAppRoot 'modules/rules-editor.ps1')
function Assert($Condition,$Message) {if (!$Condition) {throw $Message}}
Assert ((Convert-RuleEntry 'blockedDomains' 'https://bilibili.com/video/test') -eq 'bilibili.com') 'Normalize website URLs'
Assert ((Convert-RuleEntry 'blockedApps' 'C:\Apps\Douyin.exe') -eq 'douyin.exe') 'Normalize executable names'
Assert ((Convert-RuleEntry 'allowedYouTubeVideoIds' 'https://www.youtube.com/watch?v=jYtIOLm8HzQ&list=abc') -ceq 'jYtIOLm8HzQ') 'Extract exact course video'
Assert ((Convert-RuleEntry 'allowedYouTubeVideoIds' 'https://youtu.be/jYtIOLm8HzQ') -ceq 'jYtIOLm8HzQ') 'Short video URL'
foreach ($case in @(@('blockedDomains','bad'),@('blockedApps','app.txt'),@('allowedYouTubeVideoIds','https://evil.com/watch?v=jYtIOLm8HzQ'),@('allowedUrlPrefixes','bad'),@('allowedTitlePatterns','['))) {
 $failed=$false; try {$null=Convert-RuleEntry $case[0] $case[1]} catch {$failed=$true}; Assert $failed ('Reject invalid '+$case[0])
}
$folder=Join-Path $testDataRoot 'logs'; $null=[IO.Directory]::CreateDirectory($folder)
$path=Join-Path $folder ('editor-test-'+[guid]::NewGuid().ToString('N')+'.json')
$config=Get-Content -Raw (Join-Path $testDataRoot 'config.json') | ConvertFrom-Json
$config.allowedYouTubeVideoIds=@('jYtIOLm8HzQ') # Test fixture only; never alter the user's configuration.
[IO.File]::WriteAllText($path,($config|ConvertTo-Json -Depth 8))
$ui=New-RulesEditor $config $path
try {
 $ui.Numbers.idleSeconds.Value=90
 $page=$ui.Tabs.TabPages[3]
 $add=@($page.Controls | Where-Object {$_.Text -eq 'Add'})[0]
 $add.Tag.Entry.Text='https://youtu.be/abcdefghijk'
 $add.PerformClick()
 # Controls on hidden forms do not dispatch PerformClick; use the actual OnClick handler.
 $flags=[Reflection.BindingFlags]'Instance,NonPublic'
 if (!$ui.Lists.allowedYouTubeVideoIds.Items.Contains('abcdefghijk')) {$null=$add.GetType().GetMethod('OnClick',$flags).Invoke($add,@([EventArgs]::Empty))}
 Assert ($ui.Lists.allowedYouTubeVideoIds.Items.Contains('abcdefghijk')) 'Add button wires correct course list'
 $ui.Dialog.Show(); [Windows.Forms.Application]::DoEvents()
 $bitmap=New-Object Drawing.Bitmap($ui.Dialog.Width,$ui.Dialog.Height)
 $ui.Dialog.DrawToBitmap($bitmap,(New-Object Drawing.Rectangle(0,0,$bitmap.Width,$bitmap.Height)))
 $bitmap.Save((Join-Path $PSScriptRoot 'rules-editor-preview.png')); $bitmap.Dispose()
 $null=$ui.Save.GetType().GetMethod('OnClick',$flags).Invoke($ui.Save,@([EventArgs]::Empty))
 Assert ($ui.Dialog.DialogResult -eq 'OK') ('Save handler: '+$ui.Save.Tag.Status.Text)
 $saved=Get-Content -Raw $path | ConvertFrom-Json
 Assert ($saved.idleSeconds -eq 90) 'Save new threshold'
 Assert ($saved.phoneTopic -eq $config.phoneTopic -and $saved.totalStudyHours -eq $config.totalStudyHours) 'Preserve other settings'
 Assert ($saved.allowedYouTubeVideoIds -ccontains 'jYtIOLm8HzQ') 'Preserve original whitelist'
 Assert ($saved.allowedYouTubeVideoIds -ccontains 'abcdefghijk') 'Save added course'
 $cancel=New-RulesEditor $saved $path
 try {$cancel.Numbers.idleSeconds.Value=10} finally {$cancel.Dialog.Dispose()}
 Assert ((Get-Content -Raw $path | ConvertFrom-Json).idleSeconds -eq 90) 'Closing without save preserves file'
} finally {$ui.Dialog.Dispose()}
'All rules editor normalization, GUI save, preservation and cancel tests passed.'
