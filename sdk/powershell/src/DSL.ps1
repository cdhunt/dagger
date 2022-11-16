
function Query {
    param (
        [scriptblock]$ScriptBlock
    )

    $ScriptBlock.Invoke().Item(0)
}
function Container {
    param (
        [scriptblock]$ScriptBlock
    )

    [Dagger.QueryQueryBuilder]::new().WithContainer($ScriptBlock.Invoke().Item(0))
}

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
