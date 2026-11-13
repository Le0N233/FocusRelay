param([string]$BuildDirectory='',[string]$ArchivePath='')
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
if(!$BuildDirectory){$BuildDirectory=Join-Path $root 'artifacts/FocusRelay'}
if(!$ArchivePath){$ArchivePath=Join-Path $root 'artifacts/FocusRelay-win-x64.zip'}
if(!(Test-Path (Join-Path $BuildDirectory 'FocusRelay.exe'))){throw 'Build FocusRelay before packaging.'}
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.IO.Compression
$null=[IO.Directory]::CreateDirectory((Split-Path $ArchivePath))
if(Test-Path -LiteralPath $ArchivePath){Remove-Item -LiteralPath $ArchivePath}
$zip=[IO.Compression.ZipFile]::Open($ArchivePath,[IO.Compression.ZipArchiveMode]::Create)
try{
 foreach($file in Get-ChildItem -LiteralPath $BuildDirectory -File -Recurse -Force){
  $relative=$file.FullName.Substring($BuildDirectory.TrimEnd('\','/').Length+1).Replace('\','/')
  if($relative -match '(^|/)(data|\.test-data|logs|backup-[^/]*)(/|$)' -or $relative -match '(^|/)config\.json($|\.)'){continue}
  $null=[IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,$file.FullName,('FocusRelay/'+$relative),[IO.Compression.CompressionLevel]::Optimal)
 }
}finally{$zip.Dispose()}
Get-FileHash -Algorithm SHA256 $ArchivePath
