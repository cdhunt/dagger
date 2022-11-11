Get-ChildItem .\lib\*.dll | foreach-object { Add-Type -Path $_ }

function Query {
    param (
        [scriptblock]$ScriptBlock
    )

    function Container {
        param (
            [scriptblock]$ScriptBlock
        )

        function WithFrom {
            param (
                [string]$Address,
                [scriptblock]$ScriptBlock
            )
            [Dagger.ContainerQueryBuilder]::new().WithFrom($ScriptBlock.Invoke().Item(0), $Address)
        }

        function WithExec {
            param (
                [string[]]$CommandArgs,
                [scriptblock]$ScriptBlock
            )
            $argList = [System.Collections.Generic.List[string]]::new()
            $CommandArgs | foreach-object { $argList.Add($_) }

            [Dagger.ContainerQueryBuilder]::new().WithExec($ScriptBlock.Invoke().Item(0), $argList)
        }

        function Stdout {
            param (
                [scriptblock]$ScriptBlock
            )
            [Dagger.ContainerQueryBuilder]::new().WithStdout($ScriptBlock.Invoke().Item(0))
        }

        function Contents {
            param ()
            [Dagger.FileQueryBuilder]::new().WithContents()
        }

        [Dagger.QueryQueryBuilder]::new().WithContainer($ScriptBlock.Invoke().Item(0))
    }

    $ScriptBlock.Invoke().Item(0).Build()
}

$query = Query {
    Container {
        WithFrom alpine {
            WithExec "apk", "add", "curl" {
                WithExec "curl", "https://wttr.in/" {
                    Stdout {
                        Contents
                    }
                }
            }
        }
    }
}

$data = Invoke-GraphQLQuery -Query $query -Uri "http://localhost:8080/query"

$data.data.container.from.exec.exec.stdout.contents
