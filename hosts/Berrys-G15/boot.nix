{ ... }:

{
  # 使用 systemd-boot 作为 EFI 启动加载器。
  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 5;
  };

  boot.loader.efi.canTouchEfiVariables = true;
}
