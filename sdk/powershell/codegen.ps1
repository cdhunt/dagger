$queryType = [Dagger.QueryQueryBuilder]::new()

$code = [Text.StringBuilder]::new()

function FunctionHeader ([string]$Name, [int]$Level = 0, [hashtable]$Parameters) {

    $function = [Text.StringBuilder]::new()
    $indent = " " * 4 * $Level

    $function.Append($indent).AppendLine("function $Name {") | Out-Null
    $function.Append($indent).AppendLine('    param (') | Out-Null

    if ($Parameters.Count -ge 1) {
        foreach ($key in $Parameters.Keys) {

            $parameterName = $key
            $parameterType = $Parameters[$key].GetType().Name

            $function.Append($indent).Append("        [$parameterType] $")  | Out-Null
            $function.Append($parameterName) | Out-Null
            $function.AppendLine(',') | Out-Null

        }
    }

    $function.Append($indent).Append('        [scriptblock]$ScriptBlock') | Out-Null
    $function.AppendLine().Append($indent).AppendLine('    )') | Out-Null

    $function.ToString()

}

$code.AppendLine((FunctionHeader Query)) | Out-Null

$queryType.AllFields | ForEach-Object {

    $fieldName = $_.Name
    $queryBuilderType = $_.QueryBuilderType

    $fh = FunctionHeader $fieldName 1

    $code.AppendLine($fh) | Out-Null

    if ($queryBuilderType) {
        $instance = New-Object -TypeName $queryBuilderType.UnderlyingSystemType

        $methods = $instance | Get-Member -MemberType Method

        $fields = $instance.AllFields

        foreach ($method in $methods) {
            $methodDefinition = $instance.GetType().GetMethod($method.Name)
            $field = $fields.Where({ $_.Name -eq $method.Name })
            $methodParameters = $methodDefinition.GetParameters().Where({ !$_.HasDefaultValue })

            $parameterHash = [ordered]@{}
            $methodParameters.Where({ $_.ParameterType.BaseType -eq [Dagger.QueryBuilderParameter] }) | ForEach-Object {
                $parameterHash.Add($_.Name, $_.ParameterType.GenericTypeArguments.Name)
            }

            $fh = FunctionHeader $method.Name 2 $parameterHash
            $code.Append($fh) | Out-Null

            if ($field.IsComplex) {
                $typeFullName = $field.QueryBuilderType
            }
            else {
                $typeFullName = $queryBuilderType
            }

            $code.Append("            [$typeFullName]::new().")  | Out-Null
            $code.Append($method.Name) | Out-Null
            $code.Append('($ScriptBlock.Invoke().Item(0)') | Out-Null

            if ($parameterHash.Count -ge 1) {
                foreach ($key in $parameterHash.Keys) {
                    $code.Append(', ') | Out-Null
                    $code.Append('$') | Out-Null
                    $code.Append($key) | Out-Null
                }
            }
            $code.AppendLine(')') | Out-Null

            $code.AppendLine().AppendLine('        }') | Out-Null

        }
        $code.Append("    [$queryBuilderType]::new().") | Out-Null
        $code.Append($fieldName) | Out-Null
        $code.Append('($ScriptBlock.Invoke().Item(0)') | Out-Null

        if ($parameterHash.Count -ge 1) {
            foreach ($key in $parameterHash.Keys) {
                $code.Append(', ') | Out-Null
                $code.Append('$') | Out-Null
                $code.Append($key) | Out-Null
            }
        }
        $code.AppendLine(')') | Out-Null

        $code.AppendLine('    }') | Out-Null
    }
    else {
        $code.Append("    [$queryBuilderType]::new().") | Out-Null
        $code.Append($fieldName) | Out-Null
        $code.AppendLine(')') | Out-Null
        $code.AppendLine('    }') | Out-Null
    }


}

$code.AppendLine('}') | Out-Null
$code.ToString()