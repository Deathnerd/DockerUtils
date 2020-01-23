function Test-Uri {
    [CmdletBinding()]
    [OutputType([Boolean])]
    Param(
        [ValidateNotNullOrEmpty()]
        [Parameter(ValueFromPipeline = $true)]
        [uri]$Uri,
        [int]$ExpectedStatusCode = 200
    )
    Process {
        try {
            Write-Verbose "Opening connection to $Uri"
            $HTTP_Request = [Net.WebRequest]::Create($Uri)
            Write-Verbose "Getting response from $Uri"
            $HTTP_Response = $HTTP_Request.GetResponse()
            Write-Verbose "Asserting status code is $ExpectedStatusCode"
            return $HTTP_Response.StatusCode -eq $ExpectedStatusCode
        }
        catch {
            return $false
        }
        finally {
            if ($HTTP_Response) {
                Write-Verbose "Closing connection to $Uri"
                $HTTP_Response.Close()
            }
        }
    }
}