Add-Type -Path C:\source\github\dagger\sdk\powershell\lib\Newtonsoft.Json.dll
Add-Type -Path C:\source\github\dagger\sdk\powershell\lib\DaggerSdk.dll

. "$PSScriptRoot\Start-DaggerEngineSession.ps1"
. "$PSScriptRoot\Stop-DaggerEngineSession.ps1"
. "$PSScriptRoot\DSL.ps1"
. "$PSScriptRoot\Invoke-DaggerQuery.ps1"

$Writer = $null
$Port = Start-DaggerEngineSession
$Uri = 'http://localhost:{0}/query' -f $Port