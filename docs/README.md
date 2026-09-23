# 配置整理说明

本目录记录整理决策。

- 原 `pkgs/gnome-rounded-blur/rounded_blur_build.sh` 是上游面向传统发行版的安装脚本，不参与当前 NixOS flake 求值；整理后不再放入配置目录，原文件仍保留在执行脚本时创建的备份目录中。
- 两份完全相同的 `hosts/*/network.nix` 合并为 `modules/network/networkmanager.nix`，不要再往主机目录里加同名文件。
- 原 `modules/desktop/polkit.nix` 已删除：GNOME（`services.gnome.core-os-services`）和 NetworkManager 模块都会设置 `security.polkit.enable = true`，无需重复声明。
- `modules/services/ssh.nix` 只保留 `services.openssh.enable`：原来的 `ports`、`PasswordAuthentication`、`PermitRootLogin` 写的都是 NixOS 默认值。
- `profiles/i18n/zh-cn.nix` 删除了与默认值重复的 `i18n.supportedLocales`（其默认值已自动包含 zh_CN.UTF-8），以及由 i18n/fcitx5 模块自动设置的 `LANG`、`XMODIFIERS`、`QT_IM_MODULE`、`GTK_IM_MODULE`；`LC_ALL` 会覆盖全部 `LC_*`，不要设置。只保留 `QT_IM_MODULES`。
- `hosts/Berrys-EGO/gaokun3.nix` 删除了与 gaokun3 模块重复的 `hardware.enableRedistributableFirmware = lib.mkDefault true`；`allowUnfreePredicate` 仍然必需（`linux-firmware-gaokun3` 是 unfreeRedistributable）。
- `modules/programs/cuda12.nix` 删除了无人读取的 `CUDA12_LD_PATH`；它非标准变量名，需要暴露给程序时应改用 `LD_LIBRARY_PATH`。
