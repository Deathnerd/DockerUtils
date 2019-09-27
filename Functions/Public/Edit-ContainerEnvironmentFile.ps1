function Edit-ContainerEnvironmentFile {
    [CmdletBinding()]
    Param (
        [ValidateScript( {
                if ((Get-DockerContainerStatus | Where-Object -Property Names -Match $_).Count -eq 0) {
                throw "No container running with the name $_"
                return $false
            }
            return $true
        })]
    [string]$Container = "streamserve"
)
Process {
    $EnvironmentContents = Get-ContainerFileContents -Container $Container -ContainerFilePath "/etc/environment"
    @(
        "PS1=`"\w $ `""
        "export LD_LIBRARY_PATH=/home/bootstrap/mgwroot/:`$LD_LIBRARY_PATH"
    ) |
        Where-Object { $EnvironmentContents -notcontains $_ } |
        ForEach-Object {
            Invoke-Expression "docker exec -t $Container echo '$_' >> /etc/environment"
        }
}
}