function Get-ContainerFileContents {
    [CmdletBinding()]
    [OutputType([string[]])]
    Param (
        [ValidateScript( {
                if ((Get-DockerContainerStatus | Where-Object -Property Names -Match $_).Count -eq 0) {
                throw "No container running with the name $_"
                return $false
            }
            return $true
        })]
    [string]$Container = "streamserve",
    [ValidateNotNullOrEmpty()]
    [string]$ContainerFilePath
    )
    Process {
        return Invoke-Expression "docker exec -t $Container cat $ContainerFilePath"
    }
}