function Invoke-BuildStreamserveDocker {
    [CmdletBinding()]
    Param(
        [ValidateSet("16.2.0", "16.2.1", "16.3.0", "16.3.1", "16.4.0", "16.4.1", "16.4.2", "16.6.0", "16.6.1")]
        [string]$Version = "16.6.0",
        [int]$Build = 421,
        [string]$Tag = "sslatest",
        [string]$Release = "GA",
        [ValidateSet("lab", "bootstrap", "opensuse", "build", "push", "none")]
        [string[]]$Skip = "none",
        [switch]$CleanFirst,
        [string[]]$KeepFiles = @("Dockerfile", "docker.build.sh", "tenantconfig.json"),
        [Uri]$Registry = "ssdregistry.lab.opentext.com",
        [IO.DirectoryInfo]$DockerfileDir = "C:\Hydrogen\hydrogen\src\docker\resources\streamserve\",
        [IO.DirectoryInfo]$OpenSuseDir = "\\lexfiles.lab.opentext.com\shares\r-d\Build-Release\GBGLINUX10\builds\unixports"
    )
    Begin {
        [IO.FileInfo]$OpenSuseLocation = Join-Path $OpenSuseDir "Exstream-$Version.$Release.$Build-x86_64-suse-linux-release.tar.gz"
        if (!(Test-Path $OpenSuseLocation)) {
            throw "Could not find an OpenSuse tar for the given parameters: `nVersion:$Version`nRelease:$Release`nBuild:$Build"
        }
        [Uri]$BootstrapUrl = "http://stdevwv32.streamserve.com:8081/nexus/content/repositories/releases/com/streamserve/bootstrap/Bootstrap/$Version/Bootstrap-$Version-OTDS.Tomcat.PostgreSQL.ux.zip"
        $Request = [Net.WebRequest]::Create($BootstrapUrl)
        [int]$Status = $Request.GetResponse().StatusCode
        if ($Status -ne 200) {
            throw "Could not resolve $BootstrapUrl for given parameters: `nVersion:$Version`nRelease:$Release`nBuild:$Build`n`nStatus Code:$Status"
        }
        [Uri]$ExstreamLabUrl = "http://artifactory.lab.opentext.com:8081/artifactory/ext-release-local/ExstreamLab/ExstreamLab/1.0.0/ExstreamLab-1.0.0.zip"
        $Request = [Net.WebRequest]::Create($ExstreamLabUrl)
        [int]$Status = $Request.GetResponse().StatusCode
        if ($Status -ne 200) {
            throw "Could not resolve $ExstreamLabUrl for given parameters: `nVersion:$Version`nRelease:$Release`nBuild:$Build`n`nStatus Code:$Status"
        }
        [IO.DirectoryInfo] $ResourcesDir = Join-Path $DockerFileDir "resources"
        $OldErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = "Stop"
        Push-Location $DockerfileDir
        if ($CleanFirst) {
            Write-Verbose "Pruning all docker images"
            Invoke-Expression "docker images prune -a"
            Write-Verbose "Resetting directory to pristine state"
            Get-ChildItem -Exclude $KeepFiles -Recurse -File | Select-Object -ExpandProperty FullName | ForEach-Object {
                Write-Verbose "Removing $_"
                Remove-Item -Path $_
            }
        }
        function Invoke-Download {
            Param(
                [String]$Destination,
                [Uri]$Uri
            )
            Write-Verbose "Downloading $Uri to $Destination"
            [IO.DirectoryInfo]$ParentDir = Split-Path $Destination -Parent
            if (Get-Command aria2c) {
                Write-Verbose "Using aria2c"
                $File = Split-Path $Destination -Leaf
                Invoke-Expression "aria2c -d $ParentDir -o $File -x 16 $Uri"
            }
            elseif (Get-Command Invoke-DownloadFile) {
                Write-Verbose "Using Invoke-DownloadFile"
                Invoke-DownloadFile -Url $Uri -OutFile $Destination -BufferSize 1MB
            }
            else {
                Write-Verbose "Using Invoke-WebRequest"
                Invoke-WebRequest -Url $Uri -OutFile $Destination
            }
        }
    }
    Process {
        if ("lab" -notin $Skip) {
            Invoke-Download -Uri $ExstreamLabUrl -Destination (Join-Path $ResourcesDir "ExstreamLab.zip")
        }
        if ("opensuse" -notin $Skip) {
            Write-Verbose "Copying $OpenSuseLocation"
            Copy-Item $OpenSuseLocation "$ResourcesDir\" -Force
        }
        if ("bootstrap" -notin $skip) {
            Remove-Item (Join-Path $ResourcesDir "Bootstrap*.zip")
            Invoke-Download -Uri $BootstrapUrl -Destination (Join-Path $ResourcesDir "Bootstrap-$Version-OTDS.Tomcat.PostgreSQL.ux.zip")
        }
        if ("build" -notin $skip) {
            $DockerBuildCmd = "docker build -t $Tag --build-arg ss_build=$Build --build-arg bootstrap_version=$Version --build-arg ss_release=$Release --build-arg ss_version=$Version --no-cache ."
            Write-Verbose "Running docker build via $DockerBuildCmd"
            Invoke-Expression $DockerBuildCmd
        }
        if ("push" -notin $skip) {
            $DockerPushCmd = "docker push $Registry/streamserve:$Version.$Build"
            Write-Verbose "Pushing image via $DockerPushCmd"
        }
    }
    End {
        $ErrorActionPreference = $OldErrorActionPreference
        Pop-Location
    }
}