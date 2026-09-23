# 配置整理说明

本目录记录整理决策。

- 原 `pkgs/gnome-rounded-blur/rounded_blur_build.sh` 是上游面向传统发行版的安装脚本，不参与当前 NixOS flake 求值；整理后不再放入配置目录，原文件仍保留在执行脚本时创建的备份目录中。
- 两份完全相同的 `hosts/*/network.nix` 合并为 `modules/network/networkmanager.nix`，不要再往主机目录里加同名文件。
- 原 `modules/desktop/polkit.nix` 已删除：GNOME（`services.gnome.core-os-services`）和 NetworkManager 模块都会设置 `security.polkit.enable = true`，无需重复声明。
- `modules/services/ssh.nix` 只保留 `services.openssh.enable`：原来的 `ports`、`PasswordAuthentication`、`PermitRootLogin` 写的都是 NixOS 默认值。
- `profiles/i18n/zh-cn.nix` 删除了与默认值重复的 `i18n.supportedLocales`（其默认值已自动包含 zh_CN.UTF-8），以及由 i18n/fcitx5 模块自动设置的 `LANG`、`XMODIFIERS`、`QT_IM_MODULE`、`GTK_IM_MODULE`；`LC_ALL` 会覆盖全部 `LC_*`，不要设置。只保留 `QT_IM_MODULES`。
- `hosts/Berrys-EGO/gaokun3.nix` 删除了与 gaokun3 模块重复的 `hardware.enableRedistributableFirmware = lib.mkDefault true`；`allowUnfreePredicate` 仍然必需（`linux-firmware-gaokun3` 是 unfreeRedistributable）。
- `modules/programs/cuda12.nix` 删除了无人读取的 `CUDA12_LD_PATH`；它非标准变量名，需要暴露给程序时应改用 `LD_LIBRARY_PATH`。

## Clash Verge（Berrys-EGO）

以下两条曾被当成"冗余"清理，但它们是 nixpkgs 打包方式的固有缺陷导致的**真实故障绕过**，删除会复现故障。请先读完再动。

- **不要试图在 Nix 里 pin geosite 数据集。** 内核是以 `-d ~/.local/share/io.github.clash-verge-rev.clash-verge-rev` 启动的，geodata 从**数据目录**读取；包里 `lib/Clash\ Verge/resources/*.dat` 只是首次运行时的播种来源。所以任何 Nix 侧的数据 pin 都到不了内核，换了也不生效（实测：pin 为 4,246,665 字节，而内核实际读的是数据目录里 4,247,789 字节的那份）。
- **数据目录权限必须保持可写。** Rust 的 `fs::copy` 会保留权限位，而 Nix store 里的文件是 0444，因此应用播种出来的数据目录副本也是只读的，之后它就无法覆盖自己这份数据——表现为 GeoData 更新报目录权限错、并连带"无法激活配置"。`modules/programs/clash-verge.nix` 里的 `systemd.tmpfiles.rules`（`z` 类型）就是为修正这点而存在，**不要删**。geosite 的日常更新交给应用自身的 GeoData 更新即可。
- **内核版本只能在 Nix 侧选。** 包内磁盘上只有 `bin/verge-mihomo`（wrapGAppsHook3 包装器 → `bin/.verge-mihomo-wrapped` → `pkgs.mihomo`），没有任何其他内核文件，所以 GUI 里切换内核必然"找不到文件"（所有内核项，不只 alpha）；nixpkgs 的 `unwrapped.nix` 还主动 patch 掉了 Mihomo Alpha 选项，并注明"需要更新内核请覆盖 wrapped 包的 mihomo 输入"。原先把 `mihomo` 覆写到 1.19.26 只是"当时最新"，已随 nixpkgs 前进到 1.19.31 而成为降级，故删除，改用 nixpkgs 默认（实测从 1.19.26 升到 1.19.31）；若将来需要指定内核，请用 `clash-verge-rev.override { mihomo = ...; }`，而不要再用全局 `nixpkgs.overlays` 覆盖 `pkgs.mihomo`（那会连带影响 `services.mihomo`）。
