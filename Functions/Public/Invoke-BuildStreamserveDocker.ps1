function Invoke-BuildStreamserveDocker {
    [CmdletBinding(SupportsShouldProcess = $true)]
    Param(
        [ValidateSet("16.2.0", "16.2.1", "16.3.0", "16.3.1", "16.4.0", "16.4.1", "16.4.2", "16.6.0", "16.6.1", "20.2.0")]
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
        [IO.DirectoryInfo]$OpenSuseDir = "\\lexfiles.lab.opentext.com\shares\r-d\Build-Release\GBGLINUX10\builds\unixports",
        [IO.DirectoryInfo]$CacheDir = $null,
        [string]$SSVersion = $Version,
        [string]$BootstrapVersion = $Version
    )
    Begin {
        function Invoke-Download {
            Param(
                [String]$Destination,
                [Uri]$Uri
            )
            Write-Verbose "Downloading $Uri to $Destination"
            [IO.DirectoryInfo]$ParentDir = Split-Path $Destination -Parent
            if (Get-Command aria2c -ErrorAction SilentlyContinue) {
                Write-Verbose "Using aria2c"
                $File = Split-Path $Destination -Leaf
                Invoke-Expression "aria2c -d $ParentDir -o $File -x 16 $Uri"
            }
            elseif (Get-Command Invoke-DownloadFile -ErrorAction SilentlyContinue) {
                Write-Verbose "Using Invoke-DownloadFile"
                Invoke-DownloadFile -Url $Uri -OutFile $Destination -BufferSize 1MB
            }
            else {
                Write-Verbose "Using Invoke-WebRequest"
                Invoke-WebRequest -Url $Uri -OutFile $Destination
            }
        }

        function Test-UriResponse {
            Param(
                [uri]$Uri,
                [int]$ExpectedCode = 200,
                [string]$ErrorMessage = "Could not resolve $Uri."
            )
            $Request = [Net.WebRequest]::Create($Uri)
            [int]$Status = $Request.GetResponse().StatusCode
            if ($Status -ne $ExpectedCode) {
                throw $ErrorMessage + "`n`nStatus Code: $Status"
            }
            Write-Verbose "$Uri responded okay with expected code of $ExpectedCode"
        }
    }
    Process {
        try {
            [IO.DirectoryInfo] $ResourcesDir = Join-Path $DockerFileDir "resources"
            Push-Location $DockerfileDir
            $ErrorActionPreference = "Stop"
            $DockerBuildCmd = "docker build -t $Tag --build-arg ss_build=$Build --build-arg bootstrap_version=$BootstrapVersion --build-arg ss_release=$Release --build-arg ss_version=$SSVersion --no-cache ."
            $DockerPushCmd = "docker push $Registry/streamserve:$Version.$Build"
            $BootstrapFileName = "Bootstrap-$Version-OTDS.Tomcat.PostgreSQL.ux.zip"
            $SuseLinuxReleaseFileName = "Exstream-$Version.$Release.$Build-x86_64-suse-linux-release.tar.gz"
            [Uri]$BootstrapUrl = "http://stdevwv32.streamserve.com:8081/nexus/content/repositories/releases/com/streamserve/bootstrap/Bootstrap/$Version/Bootstrap-$Version-OTDS.Tomcat.PostgreSQL.ux.zip"
            [Uri]$ExstreamLabUrl = "http://artifactory.lab.opentext.com:8081/artifactory/ext-release-local/ExstreamLab/ExstreamLab/1.0.0/ExstreamLab-1.0.0.zip"
            if(!$CacheDir) {
                if("bootstrap" -notin $Skip) {
                    Test-UriResponse -Uri $BootstrapUrl -ErrorMessage "Could not resolve $BootstrapUrl for given parameters: `nVersion:$Version`nRelease:$Release`nBuild:$Build"
                }
                if("lab" -notin $Skip) {
                    Test-UriResponse -Uri $ExstreamLabUrl -ErrorMessage "Could not resolve $ExstreamLabUrl for given parameters: `nVersion:$Version`nRelease:$Release`nBuild:$Build"
                }
            }

            if ($CleanFirst) {
                Write-Verbose "Pruning all docker images"
                Invoke-Expression "docker images prune -a"
                Write-Verbose "Resetting directory to pristine state"
                Get-ChildItem -Exclude $KeepFiles -Recurse -File |
                    Select-Object -ExpandProperty FullName |
                    ForEach-Object {
                    Write-Verbose "Removing $_"
                    Remove-Item -Path $_
                }
            }
            $Steps = [ordered]@{
                lab       = [scriptblock] {
                    if ($CacheDir) {
                        [IO.FileInfo]$LabZipLocation = Join-Path $CacheDir "ExstreamLab.zip"
                        Write-Verbose "Copying $LabZipLocation"
                        Copy-Item -Path $LabZipLocation -Destination $ResourcesDir -Force -Verbose
                    }
                    else {
                        Invoke-Download -Uri $ExstreamLabUrl -Destination (Join-Path $ResourcesDir "ExstreamLab.zip")
                    }
                }
                opensuse  = [scriptblock] {
                    [IO.FileInfo]$OpenSuseLocation = if ($CacheDir) {
                        Join-Path $CacheDir $SuseLinuxReleaseFileName
                    }
                    else {
                        Join-Path $OpenSuseDir $SuseLinuxReleaseFileName
                    }
                    if (!(Test-Path $OpenSuseLocation)) {
                        throw "Could not find an OpenSuse tar for the given parameters: `nVersion:$Version`nRelease:$Release`nBuild:$Build"
                    }
                    Write-Verbose "Copying $OpenSuseLocation"
                    Copy-Item $OpenSuseLocation $ResourcesDir -Force
                }
                bootstrap = [scriptblock] {
                    if ($CacheDir) {
                        [IO.FileInfo]$BootstrapZipLocation = Join-Path $CacheDir $BootstrapFileName
                        Write-Verbose "Copying $BootstrapZipLocation"
                        Copy-Item -Path $BootstrapZipLocation -Destination $ResourcesDir -Force -Verbose
                    }
                    else {
                        Join-Path $ResourcesDir "Bootstrap*.zip" | Remove-Item
                        Invoke-Download -Uri $BootstrapUrl -Destination (Join-Path $ResourcesDir $BootstrapFileName)
                    }
                }
                build     = [scriptblock] {
                    Write-Verbose "Running docker build via $DockerBuildCmd"
                    if ($PSCmdlet.ShouldProcess($DockerBuildCmd, "EXECUTE")) {
                        Invoke-Expression $DockerBuildCmd
                    }
                }
                push      = [scriptblock] {
                    Write-Verbose "Pushing image via $DockerPushCmd"
                    if ($PSCmdlet.ShouldProcess($DockerPushCmd, "EXECUTE")) {
                        Invoke-Expression $DockerPushCmd
                    }
                }
            }

            $Steps.GetEnumerator() |
                Where-Object Key -notin $Skip |
                ForEach-Object { Invoke-Command -ScriptBlock $_.Value }
        }
        finally {
            Pop-Location
        }
    }
}