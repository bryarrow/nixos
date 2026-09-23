# NixOS 配置（Berry）

用 flake 管理的个人 NixOS 配置，覆盖两台机器：一台 x86_64 的 G15 笔记本，一台 aarch64 的 EGO 平板。两机共享桌面、网络、语言环境等模块，主机差异只保留在 `hosts/` 下。

## 主机

| 主机 | 架构 | 入口 | 特点 |
| --- | --- | --- | --- |
| `berrysG15` | `x86_64-linux` | `hosts/Berrys-G15/configuration.nix` | Intel + NVIDIA 双显卡（PRIME offload）、CUDA 12、mihomo 服务、btrfs 子卷 |
| `berrysEGO` | `aarch64-linux` | `hosts/Berrys-EGO/configuration.nix` | gaokun3 平板（`bryarrow/linux-gaokun-buildbot` 内核）、box64 运行 x86_64 程序、Clash Verge、Waydroid、OpenSSH |

两机都用 systemd-boot（保留 5 个历史代）、GNOME + GDM、NetworkManager、Firefox、nushell，用户名为 `berry`（`wheel` + `networkmanager` 组）。

## Flake 输入

| 输入 | 用途 |
| --- | --- |
| `nixpkgs`（`nixos-unstable`） | 默认软件源 |
| `nixpkgs-cuda12`（固定 commit `0954f7e`） | 为 G15 提供 CUDA 12 组件，避免跟随 unstable 前进 |
| `gaokun3`（`bryarrow/linux-gaokun-buildbot/main`） | EGO 的内核、DTB、固件与硬件模块 |

`flake.nix` 内置了 `berrys-nixos.cachix.org` 和 `gaokun3.cachix.org` 两个 substituter 及其公钥，因此求值时请带 `--accept-flake-config`（CI 也是这么做的）。

## 使用

```bash
# 查看配置能求值通过
nix flake check --accept-flake-config

# 构建系统（不切换）
nix build .#nixosConfigurations.berrysG15.config.system.build.toplevel --accept-flake-config
nix build .#nixosConfigurations.berrysEGO.config.system.build.toplevel --accept-flake-config

# 直接切换到新配置（需在对应主机上以 root 执行）
sudo nixos-rebuild switch --flake .#berrysG15 --accept-flake-config
sudo nixos-rebuild switch --flake .#berrysEGO --accept-flake-config

# 更新依赖
nix flake update
```

CI（`.github/workflows/build.yml`）在 push 到 `main`/`unstable` 或提 PR 时，会分别用 `ubuntu-latest` 和 `ubuntu-24.04-arm` 构建两台主机，并把结果推到 `berrys-nixos` Cachix 缓存。

## 目录结构

```
flake.nix                  # 输入、缓存、两台主机的 nixosConfigurations
flake.lock
hosts/
  Berrys-G15/              # x86_64 主机：boot、hardware-configuration、NVIDIA、users
  Berrys-EGO/              # aarch64 主机：boot、hardware-configuration、gaokun3、users
modules/
  arch/arm64-to-x64.nix    # box64 + binfmt + extra-platforms，让 aarch64 能跑 x86_64
  desktop/gnome.nix        # GDM/GNOME、GNOME 扩展、两个本地 overlay
  fixes/                   # 绕过上游/打包怪癖的修正
  network/networkmanager.nix
  programs/                # browsers、basic-dev-tools、cuda12、clash-verge、waydroid
  services/                # mihomo、ssh
pkgs/
  gnome-rounded-blur/      # 自打包：Blur my Shell 的圆角模糊 GObject 库，注入 gnome-shell
  mutter-touch-fix/        # 自打包：mutter 触摸 grab 空指针崩溃补丁
profiles/i18n/zh-cn.nix    # 时区、中文 locale、fcitx5 输入法
docs/README.md             # 配置整理决策记录（含踩坑说明，改配置前请先读）
```

## 值得注意的实现

- **主机与模块分离**：`hosts/*/configuration.nix` 只做 `imports`、主机名、`system.stateVersion` 等主机级声明；可复用逻辑一律放进 `modules/`，两台机器需要同样行为时改模块而不是复制文件。`hardware-configuration.nix` 由 `nixos-generate-config` 生成，不要手改。
- **`system.stateVersion = "26.11"`** 表示首次安装时的版本，用于维持旧数据/服务状态兼容。升系统时**不要**跟着改。
- **自定义包**：`modules/desktop/gnome.nix` 通过 `nixpkgs.overlays` 引入两个 overlay —— `gnome-rounded-blur` 额外暴露给 `gnome-shell` 的 `GI_TYPELIB_PATH`/`LD_LIBRARY_PATH`，`mutter` 打上触摸 grab 的 NULL 解引用补丁。
- **`nixpkgs-cuda12` 只作用于 G15**：通过 `specialArgs` 注入，`modules/programs/cuda12.nix` 独立 `import` 该 nixpkgs，不污染全局。
- **EGO 固件是 unfreeRedistributable**：`linux-firmware-gaokun3` 必须用 `allowUnfreePredicate` 显式放行，故 `hosts/Berrys-EGO/gaokun3.nix` 里的许可声明不能删。
- **`docs/README.md` 里有几条"看着冗余、删了就坏"的记录**：Clash Verge 的 geodata 播种权限（`systemd.tmpfiles` 的 `z` 规则）、内核版本只能在 Nix 侧选等。清理配置前务必先读这份文档。

## 已知取舍

- `modules/network/networkmanager.nix` 固定 DNS 为 `114.114.114.114`，并设 `dns = "none"` 阻止 NetworkManager 改写 `resolv.conf`；要换 DNS 就改这里。
- `modules/services/ssh.nix` 只开 `services.openssh.enable`，其余用 NixOS 默认值（22 端口、允许密码登录、root 仅密钥）。EGO 的 `users.nix` 里放的是 G15 的公钥，换机器时注意同步。
- `pkgs/gnome-rounded-blur/package.nix` 的 `version` 是形如 `1.0.0-unstable-2026-04-08` 的日期版本，跟上游 commit 走；更新 `rev` 时记得同步 `hash`。
