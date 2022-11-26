param (
    [Parameter(Mandatory = $true, Position = 0)]
    [string] $Title
)

$isMatch = $Title -match '^\s*(\w+-\d+)\s*:'
$isMatch ? $matches[1] : $null
