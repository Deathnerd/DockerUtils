class DockerPortMapping {
    [string]$Protocol
    [string]$ContainerInterface
    [string]$ContainerRange
    [int]$ContainerRangeStart
    [int]$ContainerRangeEnd
    [string]$HostRange
    [int]$HostRangeStart
    [int]$HostRangeEnd
    DockerPortMapping([string]$Response) {
        [regex]$Pattern = "^(((?<ContainerInterface>[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}):(?<ContainerRange>(?<ContainerRangeStart>[\d]+)((-)(?<ContainerRangeEnd>[\d]+))?))->)?(?<HostRange>(?<HostRangeStart>[\d]+)((-)(?<HostRangeEnd>[\d]+))?)\/(?<Protocol>.*)$"
        $MatchedGroups = [hashtable]@{}
        ($Response | Select-String -Pattern $Pattern -AllMatches).Matches.Groups | ForEach-Object { $MatchedGroups[$_.Name] = $_.Value }
        $this.PSObject.Properties | ForEach-Object { $this.$($_.Name) = $MatchedGroups[$_.Name] -as ($_.TypeNameOfValue) }
    }
}

class DockerContainerStatus {
    [String]$Id
    [String]$Image
    [String]$Command
    [String]$CreatedAt
    [String]$Status
    [DockerPortMapping[]]$Ports = @()
    [String]$Names
    [boolean]$IsRunning
    [int]$ExitCode

    DockerContainerStatus([object]$Response) {
        $this.Id = $Response.Id
        $this.Image = $Response.Image
        $this.Command = $Response.Command -replace "\u2026", "..." #TODO: Figure out why this isn't working in Cmder
        $this.CreatedAt = $Response.CreatedAt
        $this.Status = $Response.Status
        if ($Response.Ports) {
            $this.Ports = $Response.Ports -split ', ' | ForEach-Object {
                [DockerPortMapping]::new($_)
            }
        }
        $this.Names = $Response.Names
        $this.IsRunning = $this.Status.StartsWith("Up")
    }
}