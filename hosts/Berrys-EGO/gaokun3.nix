{ lib, ... }:

{
  # gaokun3 模块已处理：内核、DTB、cmdline、模块加载、蓝牙 NVM、UCM2、屏幕旋转，
  # 并且已默认开启 hardware.enableRedistributableFirmware。
  hardware.gaokun3.enable = true;

  # 固件许可：linux-firmware-gaokun3 使用 unfreeRedistributable，需要显式允许。
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [ "linux-firmware-gaokun3" ];
}
