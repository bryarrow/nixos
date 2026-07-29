{ ... }:

{
  imports = [
    ./boot.nix
    ./hardware-configuration.nix
    ./network.nix
    ./users.nix

    ../../modules/desktop/gnome.nix
    ../../modules/fixes/gio-extra-modules.nix
    ../../modules/services/mihomo.nix
    ../../modules/programs/browsers.nix
    ../../modules/programs/basic-dev-tools.nix
    ../../profiles/i18n/zh-cn.nix
  ];

  # 主机名。
  networking.hostName = "Berrys-G15";

  # 启用新版 nix 命令和 flakes。
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # 这是首次安装该机器时的 NixOS 版本，用来维持旧版本创建的数据和服务状态兼容。
  # 安装后不要随系统升级随意修改它；修改它不会升级系统，只会改变部分模块的兼容行为。
  system.stateVersion = "26.11";
}
