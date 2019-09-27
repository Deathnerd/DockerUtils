function Get-DockerContainerStatus {
    [OutputType([DockerContainerStatus[]])]
    [CmdletBinding()]
    Param(
        <# Get status for all containers (not just running ones) #>
        [Parameter()]
        [Alias("a")]
        [switch]$All
    )
    Process {
        $cmd = "docker ps --format `"{{ . | json}}`""
        $cmd += if ($All) { " -a" }
        [DockerContainerStatus[]](Invoke-Expression $cmd | ConvertFrom-Json)
}
}