function Stop-DaggerEngineSession {
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
    $binaryName = 'dagger-engine-session_{0}_{1}' -f $platform, $bit

    $oldProcess = Get-Process -Name $binaryName -ErrorAction SilentlyContinue

    if ($oldProcess) {
        $oldProcess.Kill()
    }
}

