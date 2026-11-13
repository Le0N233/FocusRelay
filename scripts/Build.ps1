param([string]$OutputDirectory='')
$ErrorActionPreference='Stop'
if($PSVersionTable.PSEdition -eq 'Core'){throw 'Use Windows PowerShell 5.1 to build FocusRelay.'}
$root=Split-Path $PSScriptRoot -Parent
if(!$OutputDirectory){$OutputDirectory=Join-Path $root 'artifacts/FocusRelay'}
$out=[IO.Path]::GetFullPath($OutputDirectory)
$null=[IO.Directory]::CreateDirectory($out)
Copy-Item -LiteralPath (Join-Path $root 'src/app') -Destination $out -Recurse -Force
Copy-Item -LiteralPath (Join-Path $root 'tests') -Destination (Join-Path $out 'app') -Recurse -Force
Copy-Item -LiteralPath (Join-Path $root 'src/launcher/FocusRelay.exe.config') -Destination $out -Force
Copy-Item -LiteralPath (Join-Path $root 'README.md') -Destination $out -Force
foreach($folder in @('docs','assets')){Copy-Item -LiteralPath (Join-Path $root $folder) -Destination $out -Recurse -Force}
$compiler=Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
$arguments=@('/nologo','/target:winexe','/platform:x64','/optimize+','/reference:System.Windows.Forms.dll',('/reference:'+([psobject].Assembly.Location)),('/win32manifest:'+(Join-Path $root 'src/launcher/app.manifest')),('/win32icon:'+(Join-Path $root 'src/app/assets/FocusRelay.ico')),('/out:'+(Join-Path $out 'FocusRelay.exe')),(Join-Path $root 'src/launcher/Program.cs'))
& $compiler @arguments
if($LASTEXITCODE -ne 0){throw 'FocusRelay compilation failed.'}
Write-Output ('Built '+(Join-Path $out 'FocusRelay.exe'))
