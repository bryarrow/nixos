# 配置整理说明

本目录记录整理决策。

- **`pkgs/gnome-rounded-blur` 已整体删除（2026-11-18）。** 该包是为 Blur my Shell 提供圆角模糊的 GObject 库，通过 overlay 把 `GI_TYPELIB_PATH`/`LD_LIBRARY_PATH` 注入 `gnome-shell`。上游从 v76（`Replace Shell blur with a unified pipeline backend`）起改用自带 Cogl 管线，圆角在扩展侧用 `set_corner_radius` 实现；v77（`Remove the rounded blur guide and helper`）已删掉安装引导与 helper，源码中再无 `gi://Blur` 引用，而 nixpkgs 当前打包的正是 v77。继续打包只会带来维护负担：它在 GNOME Shell 51 / mutter 51.1 上编不过（`clutter_get_default_backend()` 已被上游删除，`libmutter-18.pc` 也改名成 `libmutter-51.pc`），并会让 `gnome-shell` 变得不可替代（overlay 改了 `postFixup`，只能本地重编）。现在 `modules/desktop/gnome.nix` 只保留 `mutter-touch-fix` overlay 与 `gnomeExtensions.blur-my-shell`。原 `pkgs/gnome-rounded-blur/rounded_blur_build.sh` 是上游面向传统发行版的安装脚本，从来就不参与 NixOS flake 求值。
- 两份完全相同的 `hosts/*/network.nix` 合并为 `modules/network/networkmanager.nix`，不要再往主机目录里加同名文件。
- 原 `modules/desktop/polkit.nix` 已删除：GNOME（`services.gnome.core-os-services`）和 NetworkManager 模块都会设置 `security.polkit.enable = true`，无需重复声明。
- `modules/services/ssh.nix` 只保留 `services.openssh.enable`：原来的 `ports`、`PasswordAuthentication`、`PermitRootLogin` 写的都是 NixOS 默认值。
- `profiles/i18n/zh-cn.nix` 删除了与默认值重复的 `i18n.supportedLocales`（其默认值已自动包含 zh_CN.UTF-8），以及由 i18n/fcitx5 模块自动设置的 `LANG`、`XMODIFIERS`、`QT_IM_MODULE`、`GTK_IM_MODULE`；`LC_ALL` 会覆盖全部 `LC_*`，不要设置。只保留 `QT_IM_MODULES`。
- `hosts/Berrys-EGO/gaokun3.nix` 删除了与 gaokun3 模块重复的 `hardware.enableRedistributableFirmware = lib.mkDefault true`；`allowUnfreePredicate` 仍然必需（`linux-firmware-gaokun3` 是 unfreeRedistributable）。
- `modules/programs/cuda12.nix` 删除了无人读取的 `CUDA12_LD_PATH`；它非标准变量名，需要暴露给程序时应改用 `LD_LIBRARY_PATH`。

## Rime（ibus + rime-ice）

- **`default.custom.yaml` 不能删。** nixpkgs 的 rime-ice 把上游 `default.yaml` 改名成了 `rime_ice_suggestion.yaml`（见 `pkgs/by-name/ri/rime-ice/package.nix`），而 `ibus-engines.rime` 在数据包里找不到 `default.yaml` 时会补一个空文件。空 `default.yaml` 的 `schema_list` 为空，Rime 部署后一个方案都没有，表现就是“部署失败”、无法输入中文。`profiles/i18n/zh-cn.nix` 因此用 `writeTextDir` 额外提供 `share/rime-data/default.custom.yaml`（`patch: __include: rime_ice_suggestion:/`），并作为第二个 `rimeDataPkgs` 传给 `rime.override`；删掉它就会退回无方案状态。

## Clash Verge（Berrys-EGO）

以下几条曾被当成"冗余"清理，但它们是 nixpkgs 打包方式的固有缺陷导致的**真实故障绕过**，删除会复现故障。请先读完再动。

- **geosite 必须落到数据目录，不能只 pin 在 Nix store。** 内核是以 `-d ~/.local/share/io.github.clash-verge-rev.clash-verge-rev` 启动的，geodata 从**数据目录**读取；包里 `lib/Clash\ Verge/resources/*.dat` 只是首次运行时的播种来源，所以只改 store 里的文件不会生效。nixpkgs 自带的 v2ray-domain-list-community 缺少订阅常用的 MetaCubeX 分类（如 `APPLE-CN`），会报 `list apple-cn not found in geosite.dat`。因此 `modules/programs/clash-verge.nix` 用 `fetchurl` 固定一份 MetaCubeX `geosite.dat`，再由 `clash-verge-geodata.service` 在开机/配置切换时覆盖到数据目录；应用内 GeoData 更新只对当前会话有效，下次开机仍会回到固定版本。只把文件 symlink 到包的 resources 不会更新已有数据目录。
- **数据目录权限必须保持可写。** Rust 的 `fs::copy` 会保留权限位，而 Nix store 里的文件是 0444，因此应用播种出来的数据目录副本也是只读的，之后它就无法覆盖自己这份数据——表现为 GeoData 更新报目录权限错、并连带"无法激活配置"。`modules/programs/clash-verge.nix` 里的 `systemd.tmpfiles.rules` 就是为修正这点而存在，**不要删**：`d` 预创建数据目录与 `logs`（避免被 root 的 service 抢先创建成 root 属主），`Z` 递归修正历史遗留的 root 属主，`z` 把播种出来的 geodata 改回 0644。geosite 的版本由 Nix 固定；要跟随上游更新时改 `metaGeosite` 的 URL/hash 再 switch。
- **内核版本只能在 Nix 侧选。** 包内磁盘上只有 `bin/verge-mihomo`（wrapGAppsHook3 包装器 → `bin/.verge-mihomo-wrapped` → `pkgs.mihomo`），没有任何其他内核文件，所以 GUI 里切换内核必然"找不到文件"（所有内核项，不只 alpha）；nixpkgs 的 `unwrapped.nix` 还主动 patch 掉了 Mihomo Alpha 选项，并注明"需要更新内核请覆盖 wrapped 包的 mihomo 输入"。原先把 `mihomo` 覆写到 1.19.26 只是"当时最新"，已随 nixpkgs 前进到 1.19.31 而成为降级，故删除，改用 nixpkgs 默认（实测从 1.19.26 升到 1.19.31）；若将来需要指定内核，请用 `clash-verge-rev.override { mihomo = ...; }`，而不要再用全局 `nixpkgs.overlays` 覆盖 `pkgs.mihomo`（那会连带影响 `services.mihomo`）。

## Droidloom（Berrys-EGO）

上游只发 Arch 的 pacman 包，所以这里是**源码移植**：`pkgs/droidloom/package.nix` 编译上游 `0.1.0-49` source tarball 里的 host 端 Rust 程序（supervisor、ctl、wayland、applications、audio、devices、doctor、gpu-server），Android 载荷（`droidloom-base` + `droidloom-image`）原样解包进 store。Android 里的 ELF 是 bionic 程序，**绝不能 patchelf**；只有 host 程序参与路径替换。EGO 的机器参数（`renderNode`、`graphicsBackend`、`cellDns`）在 `hosts/Berrys-EGO/droidloom.nix`，共享模块只提供默认值。

- **`/usr/share/droidloom/package.json` 必须替换到不存在的路径。** 它是上游判断"这是 pacman 安装"的开关：存在时 `droidloomctl start` 会先 `pkexec /usr/lib/droidloom/droidloom-package-helper` 做首次 setup。NixOS 侧由模块声明式完成同样的事，所以把两个路径都换到 `/var/empty/...`，`droidloomctl` 就会直接 `systemctl --user start`，不会去跑一个架构/解释器都不匹配的 Arch ELF。
- **setup 改成声明式。** 模块用 runtime 包里的 `cell-template.json` 生成 `/etc/droidloom/cell.json`：把 `/usr/lib/droidloom` 前缀改写为 base+image 合并后的 store 路径（`current -> runtime` 是相对链接，跟着前缀走不会断），再补 `host_uid`、`render_node`、`data_dir`、`runtime_dir`、`denial_socket`、`graphics_backend`。同时写 `runtime.env`（`DROIDLOOM_HOST_PEER_*`、`DROIDLOOM_RENDER_NODE`、可选 `DROIDLOOM_GPU`），并创建 `/var/lib/droidloom/users/<uid>/{data,data/data,data/metadata}`。
- **不能用 `environment.etc` 放 cell.json。** 它生成 `/etc/static` 符号链接，而上游会校验 spec 是 root 拥有的普通文件、拒绝符号链接。模块改用 `system.activationScripts.droidloom`（`install -m 0644`），覆盖前把旧文件备份成 `cell.json.before-nixos`。
- **每个 unit 都要显式 PATH。** 上游在多个地方按裸命令名 exec `mount`、`unshare`、`losetup`、`ip`、`iptables`、`pw-cli`、`pw-link`、`timeout`…；systemd 默认 PATH 是 `/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin`，NixOS 上全是空的。`package.nix` 用同一份清单替换源码里的 `"/usr/bin:/bin"`，模块再给 `droidloomd` 和所有 user unit 设置 `path`。删掉任一处都会表现为 "No such file or directory" 或某个阶段静默失败。
- **`Delegate=memory pids` + `DelegateSubgroup=supervisor` 不能动。** 这是上游为"NixOS 把进程放在 unit 的 cgroup 根"专门加的：netd 要把 BPF 程序挂到 cell 的 cgroup 根上，宿主自己的进程在同组会让 attach 失败。unit 原样从 runtime 包复制，只替换 `/usr/bin/*` 路径。
- **GBM 后端来自 `/run/opengl-driver`。** nixpkgs 的 `libgbm` 把 `gbm-backends-path` 编译成 `/run/opengl-driver/lib/gbm`，所以必须保留 `hardware.graphics.enable`（EGO 已开）。不要在包装器里硬设 `GBM_BACKENDS_PATH` 指向某个 mesa 输出：那会绕过系统匹配的驱动版本，Adreno 上表现为 `failed to create gbm device`。
- **内核要求。** `CONFIG_ANDROID_BINDERFS=y`（gaokun3 内核已内置 binder，所以 EGO 上**不要**再加 `boot.kernelModules = [ "binder_linux" ]`，那会加载失败）。只有 `forwarding` / `dma_heap` 后端需要 `/dev/dma_heap/system`，模块按 `graphicsBackend` 自动加 `system_heap`；`drm` 后端（Adreno/Mali/AMD/Intel 原生）不需要。
- **网络慢的根因（2026-11-21 实测）：cell 的 DHCP DNS 是编译期常量 1.1.1.1/8.8.8.8。** Android 的 opportunistic Private DNS 会对它做 DoT（TCP 853），这条流会被宿主 Clash/TUN 代理，绕过 Clash 对 UDP 53 的拦截；实测每次解析 270–614 ms，返回的还是海外 CDN IP。视频 CDN 用已缓存的 IP 所以正常，详情页/评论区这种大量 API + 图片的首屏就明显慢。模块新增 `services.droidloom.cellDns`（EGO 设为 223.5.5.5 / 119.29.29.29），`package.nix` 在 `development_network.rs` 里替换 DHCP 租约的 DNS。临时绕过（不改 Nix）：`adb -s device:droidloom shell settings put global private_dns_mode off`，让 Android 走明文 DNS，被 Clash 的 UDP 53 拦截成 fake-ip，实测解析 12–30 ms；这个设置存在 Android data 里，清数据会恢复默认。
- **GNOME 上没有 Android 的返回/主页/多任务手势。** 底部手势条和 `denial_insets_v1` 的导航间距是 Denial 专有；presenter 对 `InputEvent::Navigation` 直接返回 "navigation injection is not implemented"，所以边缘滑动不会变成返回。现在能用的是：`droidloom-nav back|home|recents`（模块提供，内部 `adb -s device:droidloom shell input keyevent 4/3/187`），或在键盘上按真正发 evdev 158 的浏览器 Back 键（Droidloom 的映射表只有 `158 -> BACK`；Esc 是 `1 -> ESCAPE`，Home/Recents 根本没映射）。要手势得在 presenter 里加边缘/三指滑动到 BACK 的映射，目前没有。
- **UID 必须显式。** NixOS 的可变用户只在激活阶段分配 UID，`config.users.users.<name>.uid` 默认是 null；模块因此提供 `services.droidloom.uid`，未设置时回退到 `users.users.<name>.uid`。EGO 在 `hosts/Berrys-EGO/users.nix` 给 `berry` 写 `uid = 1000`，cell 的 `host_uid`、数据目录、`denial_socket` 都依赖它。
- **`droidloomctl gpu`、`droidloomctl update` 在 NixOS 上不可用。** 它们被 `/usr/share/droidloom/package.json` 判定为 pacman 安装后才工作；这里那条路径已被替换成不存在的文件。换 GPU 请改 `services.droidloom.gpu` / `graphicsBackend` 再 `nixos-rebuild switch`；升级请改 `pkgs/droidloom/package.nix` 的 `version`。
- **升级流程。** 改 `package.nix` 的 `version`；三个包的新 hash 从上游客服端 `https://denialwm.github.io/droidloom/<arch>/droidloom.db` 的 `%SHA256SUM%` 取十六进制后转 SRI（`nix hash convert --hash-algo sha256 --to sri`），`cargoHash` 让 nix 构建报新值。不要给 Android 载荷套 overlay、不要 patch 里面的 ELF。
- **未做/未验证：** GApps（要用户自备 add-on 镜像）、`Berrys-G15`（x86_64 + NVIDIA 需要 `graphicsBackend = "forwarding"`、`gpu` 和宿主 Vulkan ICD，未在真机验证）、自动启动（默认关闭，`autoStart = true` 时写 XDG autostart，由 uid 守卫）。

## nix-output-monitor 与 nixos-rebuild

`modules/programs/nix-tools.nix` 把 `nix-output-monitor` 装进系统，并让交互式 `nixos-rebuild` 自动经过 nom 显示构建树。下面几条是实现约束，别当成可以化简的冗余：

- **走人类可读解析（`nixos-rebuild … |& nom`），不用 `--log-format internal-json`。** nom 的 JSON 模式要求整条流都是 internal-json，而 nixos-rebuild 自己还会输出“building NixOS system…”和激活阶段文本，混进去只会让 nom 报坏行；nom README 也明确把 nixos-rebuild 归到普通管道用法。包装器因此不改任何参数，只接管 stdout/stderr。
- **覆写 `pkgs.nixos-rebuild-ng`，而不是关掉 `system.tools.nixos-rebuild` 再塞自己的包。** NixOS 的 tools 模块把 `config.system.build.nixos-rebuild`（= `pkgs.nixos-rebuild-ng`）放进 `environment.systemPackages`；overlay 包住它就能覆盖 PATH 里的 `nixos-rebuild`，同时保住 man page、shell 补全和 `system.tools.*` 语义。若改用“disable + 自己加包”，`man nixos-rebuild` 会一起消失。
- **替换点在 `postFixup`，且真入口用绝对 store 路径。** `postFixup` 跑在 `wrapPythonPrograms` 之后，此时把 `bin/nixos-rebuild` 改名为同目录的 `.nixos-rebuild-unwrapped` 再放新脚本即可。新脚本里必须写死自身输出路径（`$out/bin/.nixos-rebuild-unwrapped`），不能靠 `$0`：ng 的 `reexec` 会 `os.execve(新 store 路径/bin/nixos-rebuild, argv, …)`，但 `argv[0]` 仍是旧一代的路径，按 `$0` 解析会跑回旧版本。
- **re-exec 不会叠出第二个 nom。** switch/boot/test 每次都会触发 reexec（`argv[0]` 是 `/run/current-system/sw/bin/...` 符号链接，和 store 路径永不相等），所以 reexec 出来的新包装器总会被调用一次。外层包装器把 stdout/stderr 接进 nom 之后，新包装器看到的 stdout 是那根管道而不是终端，`[ -t 1 ]` 判断让它只透传，画面始终只有外层这一个 nom。反过来，第一次 switch 时当前一代还是未包装的 ng，reexec 出来的包装器 stdout 仍是终端，会自己画树。
- **只接管构建类动作，且只在 stdout 是终端时启用。** `edit`、`repl`、`list-generations` 需要原始终端；`--help`、`--json`、`--log-format` 要么是给人看的说明，要么要求机器可读输出；CI、重定向、`| tee` 时套 nom 会把转义码写进日志。这些情况一律 `exec` 真入口，行为与未包装时完全一致（退出码也由 `set -o pipefail` 保证不被 nom 的 0 掩盖）。
