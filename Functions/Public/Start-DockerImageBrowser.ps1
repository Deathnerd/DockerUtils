function Start-DockerImageBrowser {
    [CmdletBinding(SupportsShouldProcess = $true)]
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript(
            {
                if (!(Test-Uri -Uri $_ -ExpectedStatusCode 200)) {
                    throw "Docker registry $_ did not return a 200"
                }
                $true
            }
        )]
        [uri]$DockerRegistry,
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [int]$RegistryPort = 5000,
        [Parameter()]
        [int]$BrowserPort = 8080,
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ContainerName = ("$($DockerRegistry.Host)-registry-browser".Trim("-")),
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$BrowserImage = "klausmeyer/docker-registry-browser",
        [Parameter()]
        [switch]$AsDaemon
    )
    $DockerArgs = if ($AsDaemon) {
        @("-d ")
    }
    else {
        @("-it ")
    }
    $DockerArgs += @(
        "--name", $ContainerName
        "--rm"
        "-p", "$BrowserPort`:8080"
        "-e", "DOCKER_REGISTRY_URL=$DockerRegistry"
        "$BrowserImage"
    )
    $Cmd = "docker run $($DockerArgs -join ' ')"
    Write-Verbose "EXECUTING: $cmd"
    if ($PSCmdlet.ShouldProcess($Cmd, "Execute")) {
        Invoke-Expression $Cmd
    }
}