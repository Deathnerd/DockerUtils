function Start-DockerContainer {
    [CmdletBinding()]
    Param (
        [Parameter(ParameterSetName = "ByName", Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        [Parameter(ParameterSetName = "ById", Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [string]$Id,
        [Parameter(ParameterSetName = "FromObject", ValueFromPipeline = $true, Mandatory = $True)]
        [DockerContainerStatus]$ContainerStatus
    )
    Process {
        if ($Name) {
            $Identifier = $Name
        }
        elseif ($Id) {
            $Identifier = $Id
        }
        else {
            $Identifier = $ContainerStatus.Id
        }
        $Command = "docker start $Identifier"
        Write-Verbose "Running command: $Command"
        Invoke-Expression $Command
    }
}