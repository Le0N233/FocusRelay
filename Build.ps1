$ErrorActionPreference='Stop'
$compiler=Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
if(!(Test-Path -LiteralPath $compiler)){throw 'The Windows .NET Framework C# compiler is required.'}
$automation=[psobject].Assembly.Location
if($PSVersionTable.PSEdition -eq 'Core'){throw 'Build with Windows PowerShell 5.1, not PowerShell 7.'}
Add-Type -AssemblyName System.Drawing
$iconPath=Join-Path $PSScriptRoot 'StudyGuard.ico'
$bitmap=New-Object Drawing.Bitmap(32,32)
$g=[Drawing.Graphics]::FromImage($bitmap);$g.SmoothingMode='AntiAlias'
$green=New-Object Drawing.SolidBrush([Drawing.ColorTranslator]::FromHtml('#365E43'))
$leaf=New-Object Drawing.SolidBrush([Drawing.ColorTranslator]::FromHtml('#D7E6B9'))
$g.FillEllipse($green,0,0,31,31);$g.FillRectangle($leaf,8,7,17,19)
$pen=New-Object Drawing.Pen([Drawing.ColorTranslator]::FromHtml('#365E43'),2)
$g.DrawLine($pen,12,12,21,12);$g.DrawLine($pen,12,16,21,16);$g.DrawLine($pen,12,20,18,20)
$handle=$bitmap.GetHicon();$icon=[Drawing.Icon]::FromHandle($handle)
$stream=[IO.File]::Create($iconPath);$icon.Save($stream);$stream.Dispose()
$icon.Dispose();$pen.Dispose();$green.Dispose();$leaf.Dispose();$g.Dispose();$bitmap.Dispose()
$args=@('/nologo','/target:winexe','/platform:x64','/optimize+','/reference:System.Windows.Forms.dll',('/reference:'+$automation),('/win32manifest:'+(Join-Path $PSScriptRoot 'app.manifest')),('/out:'+(Join-Path $PSScriptRoot 'StudyGuard.exe')),(Join-Path $PSScriptRoot 'Launcher.cs'))
$args+=('/win32icon:'+$iconPath)
& $compiler @args
if($LASTEXITCODE -ne 0){throw 'Compilation failed.'}
Get-FileHash -Algorithm SHA256 (Join-Path $PSScriptRoot 'StudyGuard.exe')
