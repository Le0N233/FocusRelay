$ErrorActionPreference='Stop'
$path=Join-Path $PSScriptRoot 'config.json'
if (!(Test-Path -LiteralPath $path)) {
 $config=Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'config.example.json') | ConvertFrom-Json
 $config.phoneTopic='studyguard-'+[guid]::NewGuid().ToString('N')
 [IO.File]::WriteAllText($path,($config|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
}
