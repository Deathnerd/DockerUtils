function Invoke-DownloadFile {
    [CmdletBinding(SupportsShouldProcess)]
    Param(
        [System.Uri]$Uri,
        [ValidateNotNullOrEmpty()]
        [string]$OutFile,
        <# Timeout in milliseconds #>
        [int]$Timeout = 15000,
        [int]$BufferSize = 10KB
    )
    $OutFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutFile)
    if ($PSCmdlet.ShouldProcess($Uri, "Download") -and $PSCmdlet.ShouldProcess($OutFile, "Save")) {
        $filename = $Uri.AbsoluteUri.Split('/') | Select-Object -Last 1
        try {
            $request = [System.Net.HttpWebRequest]::Create($Uri)
            $request.set_Timeout($Timeout)
            $response = $request.GetResponse()
            $totalLength = [System.Math]::Floor($response.ContentLength / 1024 / 1024)
            $responseStream = $response.GetResponseStream()
            $targetStream = [System.IO.FileStream]::new($OutFile, "Create")
            $buffer = [System.Byte[]]::CreateInstance([System.Byte], $BufferSize)
            $count = $responseStream.Read($buffer, 0, $buffer.length)
            $downloadedBytes = $count
            while ($count -gt 0) {
                $targetStream.Write($buffer, 0, $count)
                $count = $responseStream.Read($buffer, 0, $buffer.length)
                $downloadedBytes = $downloadedBytes + $count
                $downloaded = [System.Math]::Floor($downloadedBytes / 1024 / 1024)
                $PercentComplete = ($downloaded / $totalLength) * 100
                if ([double]::IsNan($PercentComplete)) {
                    $PercentComplete = 0
                }
                Write-Progress -Activity "Downloading file '$filename'" -Status "Downloaded (${downloaded}M of ${totalLength}M): " -PercentComplete $PercentComplete
            }
        }
        finally {
            Write-Progress -Activity "Finished downloading file '$filename'" -Completed
            if ($targetStream) {
                $targetStream.Flush()
                $targetStream.Close()
                $targetStream.Dispose()
            }
            if ($responseStream) {
                $responseStream.Dispose()
            }
        }
    }
}