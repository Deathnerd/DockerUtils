function Stop-DockerContainer {
    [CmdletBinding()]
    Param (
        [Parameter(ParameterSetName = "ByName", Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        [Parameter(ParameterSetName = "ById", Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [string]$Id,
        [Parameter(ParameterSetName = "FromObject", ValueFromPipeline = $true, Mandatory = $True)]
        [DockerContainerStatus]$ContainerStatus,
        [Parameter()]
        [int]$Time = 10
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
        $Command = "docker stop -t $Time $Identifier"
        Write-Verbose "Running command: $Command"
        Invoke-Expression $Command
    }
}