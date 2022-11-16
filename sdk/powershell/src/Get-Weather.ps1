<#
.SYNOPSIS
    Get the current weather report.
.DESCRIPTION
    Demonstrate a basic PowerShell client for Dagger by creating an alpine container
    and running curl commands.
.PARAMETER Location
    Specify a location. Supported location types:

        paris                  # city name
        ~Eiffel+tower          # any location (+ for spaces)
        Москва                 # Unicode name of any location in any language
        muc                    # airport code (3 letters)
        @stackoverflow.com     # domain name
        94107                  # area codes
        -78.46,106.79          # GPS coordinates
.PARAMETER Options
    Units:

    m                       # metric (SI) (used by default everywhere except US)
    u                       # USCS (used by default in US)
    M                       # show wind speed in m/s

    View options:

    0                       # only current weather
    1                       # current weather + today's forecast
    2                       # current weather + today's + tomorrow's forecast
    A                       # ignore User-Agent and force ANSI output format (terminal)
    F                       # do not show the "Follow" line
    n                       # narrow version (only day and night)
    q                       # quiet version (no "Weather report" text)
    Q                       # superquiet version (no "Weather report", no city name)
    T                       # switch terminal sequences off (no colors)

.LINK
    https://wttr.in/:help
.EXAMPLE
    PS > Get-Weather washington+dc -Options u0
    Get the current weather for Washington DC in USCS units

    Weather report: washington+dc

         \  /       Partly cloudy
       _ /"".-.     +53(48) °F
         \_(   ).   ↘ 13 mph
         /(___(__)  9 mi
                0.0 in
#>
function Get-Weather {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0)]
        [string]
        $Location = [string]::Empty,

        [Parameter(Position = 1)]
        [string]
        $Options
    )

    $urlQuery = [string]::Empty

    if ($PSBoundParameters.ContainsKey('Options')) {
        $urlQuery = "?$Options"
    }

    $data = Query {
        Container {
            WithFrom alpine {
                WithExec "apk", "add", "curl" {
                    WithExec "curl", "https://wttr.in/$Location$urlQuery" {
                        Stdout {
                            Contents
                        }
                    }
                }
            }
        }
    } | Invoke-DaggerQuery -Verbose:$VerbosePreference

    $data.data.container.from.exec.exec.stdout.contents
}