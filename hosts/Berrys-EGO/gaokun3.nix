{ lib, ... }:

{
  # gaokun3 模块已处理：内核、DTB、cmdline、模块加载、蓝牙 NVM、UCM2、屏幕旋转。
  hardware.gaokun3.enable = true;  

  # 固件许可。
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [ "linux-firmware-gaokun3" ];

  # gaokun3 模块默认开启 redistributableFirmware，
  # 但 nixpkgs 的 linux-firmware 也需要允许。
  hardware.enableRedistributableFirmware = lib.mkDefault true;
}
