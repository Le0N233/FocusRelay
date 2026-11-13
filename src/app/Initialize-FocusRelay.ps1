$ErrorActionPreference='Stop'
$dataRoot=Join-Path (Split-Path $PSScriptRoot -Parent) 'data'
$null=[IO.Directory]::CreateDirectory($dataRoot)
$path=Join-Path $dataRoot 'config.json'
if (!(Test-Path -LiteralPath $path)) {
 $legacy=Split-Path $PSScriptRoot -Parent
 $oldConfig=Join-Path $legacy 'config.json'
 if(Test-Path -LiteralPath $oldConfig){
  if(Test-Path -LiteralPath (Join-Path $legacy 'logs')){Copy-Item -LiteralPath (Join-Path $legacy 'logs') -Destination $dataRoot -Recurse -Force}
  Copy-Item -LiteralPath $oldConfig -Destination $path
  return
 }
 $config=Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'config.example.json') | ConvertFrom-Json
 $config.phoneTopic='focusrelay-'+[guid]::NewGuid().ToString('N')
 [IO.File]::WriteAllText($path,($config|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
}
