function Enable-SshInContainer {
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