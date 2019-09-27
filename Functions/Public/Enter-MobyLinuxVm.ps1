function Enter-MobyLinuxVm {
    [CmdletBinding()]
    Param(
        [string]$Container = "alpine",
        [string]$Command = "/bin/sh",
        [string]$MountRoot = "/",
        [string]$ContainerMountPoint = "/host"
    )
    Write-Host "MobyLinuxVM FileSystem at '$MountRoot' is mounted as '$ContainerMountPoint' inside the container"
    Write-Host "REMEMBER TO DO 'chroot $ContainerMountPoint' FIRST!"
    # Via https://stackoverflow.com/questions/40867501/how-to-connect-to-docker-vm-mobylinux-from-windows-shell
    docker run --net=host --ipc=host --uts=host --pid=host -it --security-opt=seccomp=unconfined --privileged --rm -v $MountRoot`:$ContainerMountPoint $Container $Command
}