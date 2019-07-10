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
        $cmd += if ($All) {" -a"}
        [DockerContainerStatus[]](Invoke-Expression $cmd | ConvertFrom-Json)
    }
}

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

function Restart-DockerContainer {
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
        $Command = "docker restart $Identifier"
        Write-Verbose "Running command: $Command"
        Invoke-Expression $Command
    }
}

function Remove-DockerContainer {
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
        [switch]$Force
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
        $Command = "docker rm $(if($Force){'-f'}) $Identifier"
        Write-Verbose "Running command: $Command"
        Invoke-Expression $Command
    }
}

function Get-ContainerTags {
    [CmdletBinding()]
    Param (
        <# The url where the versions are #>
        [string]$RegistryUrl = "https://ssdregistry.lab.opentext.com/v2/streamserve/tags/list"
    )
    Process {
        try {
            return Invoke-RestMethod $RegistryUrl -Method Get | Select-Object -ExpandProperty tags | Sort-Object
        }
        catch {
            Write-Error "Could not get tags at $RegistryUrl`n$_"
        }
    }
}

function Enable-SSHInContainer {
    [CmdletBinding()]
    Param (
        [ValidateScript( {
                if ((Get-DockerContainerStatus | Where-Object -Property Names -Match $_).Count -eq 0) {
                    throw "No container running with the name $_"
                }
                return $true
            })]
        [string]$Container = "streamserve",
        [System.IO.FileInfo]$KeyFile = "$($env:userprofile)\.ssh\id_rsa.pub"
    )
    Process {
        Invoke-Expression "docker exec -t $Container zypper --non-interactive install openssh"
        Invoke-Expression "docker exec -t $Container mkdir /root/.ssh"
        Invoke-Expression "docker cp $KeyFile $Container`:/root/.ssh/authorized_keys"
        Invoke-Expression "docker exec -t $Container dos2unix /root/.ssh/authorized_keys"
        Invoke-Expression "docker exec -t $Container ssh-keygen -A"
        Invoke-Expression "docker exec -t $Container /usr/sbin/sshd"
    }
}

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
            Where-Object { $EnvironmentContents -notcontains $_} |
            ForEach-Object {
            Invoke-Expression "docker exec -t $Container echo '$_' >> /etc/environment"
        }
    }
}

function Invoke-BuildStreamserveDocker {
    [CmdletBinding(SupportsShouldProcess)]
    Param(
        [string]$Release = "GA",
        [string]$Version = "16.6.0",
        [int]$Build = 421,
        [string]$Tag = "sslatest",
        [ValidateSet("lab", "bootstrap", "opensuse", "none")]
        [string[]]$Skip = "none",
        [switch]$CleanFirst
    )
    Process {
        [FileInfo]$OpenSuseLocation = "\\lexfiles.lab.opentext.com\shares\r-d\Build-Release\GBGLINUX10\builds\unixports\Exstream-$Version.$Release.$Build-x86_64-suse-linux-release.tar.gz"
        [Uri]$BootstrapUrl = "http://stdevwv32.streamserve.com:8081/nexus/content/repositories/releases/com/streamserve/bootstrap/Bootstrap/$Version/Bootstrap-$Version-OTDS.Tomcat.PostgreSQL.ux.zip"
        $ExstreamLabUrl = "http://artifactory.lab.opentext.com:8081/artifactory/ext-release-local/ExstreamLab/ExstreamLab/1.0.0/ExstreamLab-1.0.0.zip"
        $DockerBuildCmd = "docker build streamserve -t $Tag --build-arg ss_build=$Build --build-arg bootstrap_version=$Version --build-arg ss_release=$Release --build-arg ss_version=$Version --no-cache"
        if ($CleanFirst) {
            Invoke-Expression "docker images prune -a"
        }
        Invoke-AtLocation -Location "C:\Hydrogen\hydrogen\src\docker\resources" {
            if ("lab" -notin $Skip) {
                Write-Verbose "Downloading $ExstreamLabUrl"
                Invoke-DownloadFile -Url $ExstreamLabUrl -TargetFile ".\streamserve\resources\ExstreamLab.zip" -ErrorAction Stop
            }
            if ("opensuse" -notin $Skip) {
                Write-Verbose "Copying $OpenSuseLocation"
                Copy-Item $OpenSuseLocation ".\streamserve\resources\" -Force -ErrorAction Stop
            }
            if ("bootstrap" -notin $skip) {
                Write-Verbose "Downloading $BootstrapUrl"
                Remove-Item .\streamserve\resources\Bootstrap*.zip
                Invoke-Expression "aria2c -d C:\Hydrogen\hydrogen\src\docker\resources\streamserve\resources -x 16 $BootstrapUrl"
                # Invoke-DownloadFile -Url $BootstrapUrl -TargetFile ".\streamserve\resources\Bootstrap-$Version-OTDS.Tomcat.PostgreSQL.ux.zip" -ErrorAction Stop
            }
            Write-Verbose "Running docker build via $DockerBuildCmd"
            Invoke-Expression $DockerBuildCmd
        }
    }
}

function Get-ResolvedPath {
    [CmdletBinding()]
    Param(
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )
    return $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
}
function Start-StreamserveDocker {
    [CmdletBinding(SupportsShouldProcess)]
    Param(
        [string]$ContainerName = "streamserve",
        [string]$Tag = "sslatest",
        [switch]$DeployFulfillmentWar,
        [switch]$DeployExstreamWar
    )
    Process {
        Invoke-Expression "docker rm -f $ContainerName"
        Invoke-Expression "docker run -tdi -p 8080:8080 -p 8443:8443 -p 21843:21843 -p 2022:22 -p 28801:28801 -p 28600:28600 -p 28700:28700 -p 28701:28701 -p 2718:2718 -p 2719:2719 -p 2720:2720 -p 2721:2721 -p 2722:2722 -p 2723:2723 -p 2724:2724 -p 2725:2725 -p 5432:5432 -p 9009:9009 -e MGW_PORT=28600 --add-host ExstreamMGWHost.opentext.net:127.0.0.1 --add-host ExstreamOTDShost.opentext.net:127.0.0.1 --name $ContainerName $Tag`:latest"
        Invoke-AtLocation -Location "C:\Hydrogen\hydrogen\" {
            $expression = "gradle"
            if ($DeployFulfillmentWar) {
                $expression += " deployFulfillmentWarLocal"
            }
            if ($DeployExstreamWar) {
                $expression += " deployWar2LocalContainer"
                ".\editor", ".\shared-components", ".\designer" | ForEach-Object {
                    Invoke-AtLocation (Get-ResolvedPath $_) { Invoke-Expression "npm install" }
                }
            }
            if ($expression -ne "gradle") {
                Invoke-Expression $expression
            }
        }
    }
}

Export-ModuleMember -Function *-*