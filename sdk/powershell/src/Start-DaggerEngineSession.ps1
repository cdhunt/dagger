function Start-DaggerEngineSession {
    [CmdletBinding()]
    param (
        [Parameter(Position = 1)]
        [int]
        $RetryLimit = 10
    )

    $bit = [Environment]::Is64BitOperatingSystem ? "amd64" : "386"

    $platform = switch ([Environment]::OSVersion.Platform) {
        "Win32NT" { "windows" }
        "Darwtin" { "darwin" }
        "Unix" { "linux" }
    }

    $ext = $platform -eq "windows" ? ".exe" : [string]::Empty

    $binaryName = 'dagger-engine-session_{0}_{1}' -f $platform, $bit
    $binaryPath = Join-Path -Path "$PSScriptRoot" -ChildPath bin -AdditionalChildPath "$binaryName$ext"

    $oldProcess = Get-Process -Name $binaryName -ErrorAction SilentlyContinue

    if ($oldProcess) {
        $oldProcess.Kill()
    }

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $binaryPath
    $startInfo.RedirectStandardError = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardInput = $true
    $startInfo.UseShellExecute = $false

    $engineProcess = New-Object System.Diagnostics.Process
    $engineProcess.StartInfo = $startInfo
    $startResult = $engineProcess.Start()

    $Writer = $engineProcess.StandardInput
    $Writer.WriteLine("ping")

    if ($startResult) {
        $i = 0
        do {
            $output = $engineProcess.StandardOutput.ReadLine()
            Start-Sleep -Milliseconds 250
        } until ($output -match "\d{4,5}" -or $i++ -ge $RetryLimit)
    }
    if ($output -notmatch "\d{4,5}") {
        Write-Error -Message "Failed to start `"$binaryPath`". No TCP Port available." -Category InvalidResult -RecommendedAction "Check that the user has access to run `"$binaryPath`"."
    }
    Write-Verbose "localhost:$output"
    Write-Output $output
}

