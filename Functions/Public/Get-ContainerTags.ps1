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