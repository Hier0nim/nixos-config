# NVIDIA RTX 4060 suspend/resume workaround.
# The GPU's dynamic power management is unreliable on the RTX 4060
# (hangs after a few cycles per nixos-hardware).
#
# Instead, we use NVIDIA's kernel-based VRAM preservation which
# enables the driver to save/restore GPU state across S2idle cycles.
# This avoids the systemd-based nvidia-suspend/nvidia-resume services
# that cause the hangs.
{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf mkForce;
in
mkIf (config.hardware.nvidia.modesetting.enable or false) {
  # Preserve video memory allocations across suspend/resume.
  # This is the kernel-level mechanism that replaces the systemd
  # nvidia-suspend/nvidia-resume services which are unreliable on 4060.
  boot.kernelParams = [
    "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
    "nvidia.NVreg_TemporaryFilePath=/var/tmp"
  ];

  # Needed for PreserveVideoMemoryAllocations to work
  systemd.tmpfiles.rules = [
    "d /var/tmp 1777 root root -"
  ];

  # Explicitly disable the broken systemd-based power management
  hardware.nvidia.powerManagement.enable = mkForce false;
  hardware.nvidia.powerManagement.finegrained = mkForce false;
}
