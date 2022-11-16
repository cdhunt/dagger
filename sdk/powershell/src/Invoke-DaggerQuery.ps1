function Invoke-DaggerQuery {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [Dagger.QueryQueryBuilder]
        $Query
    )

    $queryText = $Query.Build()

    Write-Verbose "Uri: `"$Uri`""
    Write-Verbose "Query Text: `n$($Query.Build([Dagger.Formatting]::Indented))"

    Invoke-GraphQLQuery -Query $queryText -Uri $Uri

    $engineOutput = $errorEvents | Receive-Job
    $engineOutput | Write-Verbose
}