# 请不要手动修改本文件。
# 它由 nixos-generate-config 生成，之后再次执行硬件扫描时可能会被覆盖。
# 需要调整系统行为时，请优先修改同目录下的其他主机配置文件。
{ config, lib, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "nvme" "usb_storage" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/dfc0a546-ffb3-4d6b-886a-d0a8e373be45";
    fsType = "btrfs";
    options = [ "subvol=@" ];
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-uuid/dfc0a546-ffb3-4d6b-886a-d0a8e373be45";
    fsType = "btrfs";
    options = [ "subvol=@home" ];
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-uuid/dfc0a546-ffb3-4d6b-886a-d0a8e373be45";
    fsType = "btrfs";
    options = [ "subvol=@nix" ];
  };

  fileSystems."/swap" = {
    device = "/dev/disk/by-uuid/dfc0a546-ffb3-4d6b-886a-d0a8e373be45";
    fsType = "btrfs";
    options = [ "subvol=@swap" ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/EBED-9510";
    fsType = "vfat";
    options = [ "fmask=0022" "dmask=0022" ];
  };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
