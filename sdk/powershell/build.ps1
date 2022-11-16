
[CmdletBinding()]
param (

)

$output = Join-Path -Path "$PSSCriptRoot" -ChildPath output -AdditionalChildPath Dagger
$src = Join-Path -Path "$PSSCriptRoot" -ChildPath src -AdditionalChildPath "*"
$lib = Join-Path -Path $output -ChildPath lib
$bin = Join-Path -Path $output -ChildPath bin -AdditionalChildPath "dagger-engine-session_{{.OS}}_{{.Arch}}"

if (Test-Path $output) { Remove-Item -Path $output -Recurse }

New-Item -ItemType Directory -Path $output -Force

Write-Host "Generate C# Source Types to `"$lib`""
Write-Host ""
dotnet publish "$PSSCriptRoot" -c Release -o $lib

Write-Host "Build Dagger to `"$bin`""
Write-Host ""
gox -output="$bin" -os="windows linux darwin" -arch="amd64 arm" ../../cmd/engine-session

Write-Host "Copy PowerShell files to `"$output`""
Write-Host ""
Copy-Item -Path $src -Destination $output -Recurse