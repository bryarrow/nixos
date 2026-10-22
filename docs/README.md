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

以下几条曾被当成"冗余"清理，但它们是 nixpkgs 打包方式的固有缺陷导致的**真实故障绕过**，删除会复现故障。请先读完再动。

- **geosite 必须落到数据目录，不能只 pin 在 Nix store。** 内核是以 `-d ~/.local/share/io.github.clash-verge-rev.clash-verge-rev` 启动的，geodata 从**数据目录**读取；包里 `lib/Clash\ Verge/resources/*.dat` 只是首次运行时的播种来源，所以只改 store 里的文件不会生效。nixpkgs 自带的 v2ray-domain-list-community 缺少订阅常用的 MetaCubeX 分类（如 `APPLE-CN`），会报 `list apple-cn not found in geosite.dat`。因此 `modules/programs/clash-verge.nix` 用 `fetchurl` 固定一份 MetaCubeX `geosite.dat`，再由 `clash-verge-geodata.service` 在开机/配置切换时覆盖到数据目录；应用内 GeoData 更新只对当前会话有效，下次开机仍会回到固定版本。只把文件 symlink 到包的 resources 不会更新已有数据目录。
- **数据目录权限必须保持可写。** Rust 的 `fs::copy` 会保留权限位，而 Nix store 里的文件是 0444，因此应用播种出来的数据目录副本也是只读的，之后它就无法覆盖自己这份数据——表现为 GeoData 更新报目录权限错、并连带"无法激活配置"。`modules/programs/clash-verge.nix` 里的 `systemd.tmpfiles.rules` 就是为修正这点而存在，**不要删**：`d` 预创建数据目录与 `logs`（避免被 root 的 service 抢先创建成 root 属主），`Z` 递归修正历史遗留的 root 属主，`z` 把播种出来的 geodata 改回 0644。geosite 的版本由 Nix 固定；要跟随上游更新时改 `metaGeosite` 的 URL/hash 再 switch。
- **内核版本只能在 Nix 侧选。** 包内磁盘上只有 `bin/verge-mihomo`（wrapGAppsHook3 包装器 → `bin/.verge-mihomo-wrapped` → `pkgs.mihomo`），没有任何其他内核文件，所以 GUI 里切换内核必然"找不到文件"（所有内核项，不只 alpha）；nixpkgs 的 `unwrapped.nix` 还主动 patch 掉了 Mihomo Alpha 选项，并注明"需要更新内核请覆盖 wrapped 包的 mihomo 输入"。原先把 `mihomo` 覆写到 1.19.26 只是"当时最新"，已随 nixpkgs 前进到 1.19.31 而成为降级，故删除，改用 nixpkgs 默认（实测从 1.19.26 升到 1.19.31）；若将来需要指定内核，请用 `clash-verge-rev.override { mihomo = ...; }`，而不要再用全局 `nixpkgs.overlays` 覆盖 `pkgs.mihomo`（那会连带影响 `services.mihomo`）。
