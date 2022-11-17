# Experimental PowerShell language support

This "SDK" is a proof-of-concept exploring a PowerShell language interface for Dagger.

## How to build

1. Run `cloak dev`.
    - Update `DaggerSdk.csproj` if you need to change the port for the service.

     ```xml
     <GraphQlClientGenerator_ServiceUrl>http://localhost:8080/query</GraphQlClientGenerator_ServiceUrl>
     ```

1. Run `build.ps1` from the `sdk\powershell` directory.

```powershell
ps > .\build.ps1

        Directory: C:\source\github\dagger\sdk\powershell\output


Mode     LastWritten         Length Name
----     -----------         ------ ----
d----    now                        Dagger
Generate Source Types to "C:\...\sdk\powershell\output\Dagger\lib"

MSBuild version 17.4.0+18d5aef85 for .NET
  Determining projects to restore...
  All projects are up-to-date for restore.
  DaggerSdk -> C:\...\sdk\powershell\bin\Release\netstandard2.0\DaggerSdk.dll
  DaggerSdk -> C:\...\sdk\powershell\output\Dagger\lib\
Build Dagger to "C:\...\sdk\powershell\output\Dagger\bin\dagger-engine-session_{{.OS}}_{{.Arch}}"

Number of parallel builds: 15

-->      darwin/arm: github.com/dagger/dagger/cmd/engine-session
-->     linux/amd64: github.com/dagger/dagger/cmd/engine-session
-->   windows/amd64: github.com/dagger/dagger/cmd/engine-session
-->       linux/arm: github.com/dagger/dagger/cmd/engine-session
-->    darwin/amd64: github.com/dagger/dagger/cmd/engine-session

1 errors occurred:
--> darwin/arm error: exit status 2
Stderr: go: unsupported GOOS/GOARCH pair darwin/arm

Copy PowerShell files to "C:\...\sdk\powershell\output\Dagger"
```

The build script will:

1. Build the .Net DaggerSdk.dll with the types dynamically generated from the GraphSQL Schema
2. Build the `dagger-engine-session` binaries for multiple platforms
3. Copy the necessary PowerShell files into the folder structure expected for `Publish-Module`

## To Use

Follow the above build instructions and then run `Import-Module output\Dagger`.

\- or -

Run `Install-Module -Name Dagger` to get the lasted published version from [owershellgallery.com](https://www.powershellgallery.com/packages/Dagger/0.0.4).
The Dagger binaries are packaged with the module so no external dependencies are necessary.

## Examples

### Example 1: Run the Demo Get-Weather cmdlet

```powershell
    PS > Get-Weather washington+dc -Options u0
    Get the current weather for Washington DC in USCS units

    Weather report: washington+dc

         \  /       Partly cloudy
       _ /"".-.     +53(48) °F
         \_(   ).   ↘ 13 mph
         /(___(__)  9 mi
                0.0 in
```

The `Write-EngineOutput` cmdlet will show you the output from the Dagger engine.
Output is logged asynchronously and may not line up exactly with commands you've run.

## Prior Art

This project heavily leans on two existing projects

- [GraphQlClientGenerator](https://github.com/Husqvik/GraphQlClientGenerator) by [Husqvik](https://github.com/Husqvik)
- [PSGraphQL](https://github.com/anthonyg-1/PSGraphQL) by [Tony Guimelli](https://github.com/anthonyg-1)
