# Droidloom 的 NixOS 模块：声明式完成上游 pacman 包在首次 `droidloomctl start`
# 时用 pkexec 包助手做的事（/etc/droidloom、Android 数据目录、polkit 规则），
# 并安装 package.nix 里编译好的 host 程序与上游 systemd unit。
#
# 与 Arch 的差异（详见 docs/README.md）：
#   * 不做 /usr 兼容层，也不运行 droidloom-package-helper；cell.json 由 Nix 生成，
#     image/runtime 路径指向 store。
#   * `droidloomctl start` 仍然可用：package.nix 已把 "/usr/share/droidloom/package.json"
#     判定替换到不存在的路径，所以它不会尝试 pkexec，而是直接寻找模块声明的 unit。
#   * 数据目录 /var/lib/droidloom/users/<uid> 由 droidloomd 的 preStart 创建，
#     已存在的目录不改权限（Android 在里面写过数据后不能再重置属主）。
{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    optionalAttrs
    optionalString
    types
    ;

  cfg = config.services.droidloom;

  droidloom = pkgs.callPackage ../../pkgs/droidloom/package.nix {
    inherit (cfg) cellDns;
  };

  userAttrs =
    config.users.users.${cfg.user}
      or (throw "services.droidloom.user = \"${cfg.user}\" 不是已存在的 NixOS 用户");

  # NixOS 的自动 UID 分配只发生在激活阶段，config.users.users.<name>.uid 默认是 null，
  # 所以这里允许显式指定；两者都没有时直接给出可读的错误，而不是 toString null。
  uid =
    if cfg.uid != null then
      cfg.uid
    else if userAttrs.uid != null then
      userAttrs.uid
    else
      throw "services.droidloom: 无法确定 ${cfg.user} 的 UID。请在 hosts/*/users.nix 设置 uid = 1000，或设置 services.droidloom.uid";
  uidText = toString uid;

  dataDir = "/var/lib/droidloom/users/${uidText}/data";

  # 上游模板里的 /usr/lib/droidloom 同时覆盖 image_dir、vendor_image、android_init、
  # android_file_overrides 和 android_runtime_directories；统一改写到 base+image 合并后的
  # store 路径。current -> runtime 是相对符号链接，跟着前缀一起搬不会断。
  rewritePath =
    value:
    if builtins.isString value && lib.hasPrefix "/usr/lib/droidloom" value then
      "${droidloom.androidArtifacts}/usr/lib/droidloom" + lib.removePrefix "/usr/lib/droidloom" value
    else if builtins.isList value then
      map rewritePath value
    else if builtins.isAttrs value then
      lib.mapAttrs (_: rewritePath) value
    else
      value;

  template = lib.importJSON "${droidloom.runtimeMetadata}/usr/share/droidloom/cell-template.json";

  cellSpecFile = pkgs.writeText "droidloom-cell.json" (
    builtins.toJSON (
      rewritePath template
      // {
        host_uid = uid;
        render_node = cfg.renderNode;
        data_dir = dataDir;
        runtime_dir = "/run/droidloom/cells/u${uidText}";
        denial_socket = "/run/user/${uidText}/droidloom/native-bridge.sock";
        graphics_backend = cfg.graphicsBackend;
      }
      // optionalAttrs (cfg.gpu != null) { gpu = cfg.gpu; }
    )
  );

  # 上游 setup 写出的 runtime.env；droidloom.service 和 droidloom-gpu.service 都读它。
  runtimeEnv = pkgs.writeText "droidloom-runtime.env" (
    ''
      DROIDLOOM_HOST_PEER_PID=0
      DROIDLOOM_HOST_PEER_UID=${uidText}
      DROIDLOOM_HOST_PEER_GID=${uidText}
      DROIDLOOM_RENDER_NODE=${cfg.renderNode}
    ''
    + optionalString (cfg.gpu != null) "DROIDLOOM_GPU=${cfg.gpu}\n"
  );

  # 开机自启走 XDG autostart：此时 GNOME 已经导出 WAYLAND_DISPLAY。
  # 用 uid 判断保证多用户主机上只有配置里那个用户启动。
  autostartScript = pkgs.writeShellScript "droidloom-autostart" ''
    if [ "$(${pkgs.coreutils}/bin/id -u)" != "${uidText}" ]; then
      exit 0
    fi
    exec ${droidloom.host}/bin/droidloomctl start --no-wait
  '';

  apkInstaller = pkgs.writeShellScript "droidloom-install-declared-apks" ''
    set -eu
    ${droidloom.host}/bin/droidloomctl wait
    ${lib.concatMapStringsSep "\n" (apk: ''
      ${droidloom.host}/bin/droidloomctl install --user 0 ${lib.escapeShellArg (toString apk)}
    '') cfg.applications}
  '';

  # Droidloom 的 Android 导航在 GNOME 上没有任何宿主手势：presenter 的
  # InputEvent::Navigation 注入未实现，底部手势条是 Denial 专有协议。
  # 这个脚本把 adb keyevent 包成一条命令，方便绑 GNOME 自定义快捷键。
  navScript = pkgs.writeShellScriptBin "droidloom-nav" ''
    set -eu
    case "''${1:-}" in
      back) key=4 ;;
      home) key=3 ;;
      recents | overview) key=187 ;;
      *) echo "usage: droidloom-nav back|home|recents" >&2; exit 2 ;;
    esac
    exec ${pkgs.android-tools}/bin/adb -s device:droidloom shell input keyevent "$key"
  '';

  graphicsBackend = types.enum [
    "drm"
    "drm_dma_heap"
    "kgsl_dma_heap"
    "forwarding"
  ];
in
{
  options.services.droidloom = {
    enable = mkEnableOption "Droidloom（把 Android 应用放进原生 Wayland 窗口，早期预览）";

    user = mkOption {
      type = types.str;
      example = "berry";
      description = ''
        拥有图形会话的本地用户。cell 的 host_uid、subuid 映射、polkit 规则和
        /var/lib/droidloom/users/<uid> 都以这个用户为准，必须与 `id -u` 一致。
      '';
    };

    uid = mkOption {
      type = types.nullOr types.ints.positive;
      default = null;
      example = 1000;
      description = ''
        cell 里使用的数字 UID，必须等于该用户实际的 `id -u`。NixOS 只在激活时
        分配自动 UID（`config.users.users.<name>.uid` 默认是 null），所以通常
        需要在 hosts 的 users.nix 里显式 `uid = 1000`，或在这里写一次。
      '';
    };

    renderNode = mkOption {
      type = types.str;
      default = "/dev/dri/renderD128";
      example = "/dev/dri/renderD129";
      description = ''
        暴露给 Android 的唯一 DRM render node（`ls /dev/dri`）。多 GPU 主机上
        要选合成器实际使用的那个，否则 GBM 分配不到可导入的 buffer。
      '';
    };

    gpu = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "0000:01:00.0";
      description = ''
        `graphicsBackend = "forwarding"` 时 Android Vulkan 走哪块 GPU：厂商名
        （`nvidia`/`amd`/`intel`）或 PCI 地址。写进 cell.json 的 `gpu` 和
        runtime.env 的 `DROIDLOOM_GPU`。native（drm）后端不需要。
      '';
    };

    graphicsBackend = mkOption {
      type = graphicsBackend;
      default = "drm";
      description = ''
        Android 的图形后端。Adreno/Mali/AMD/Intel 用 `drm`；NVIDIA 没有 Android
        驱动，x86_64 上用 `forwarding`。`drm_dma_heap`/`kgsl_dma_heap` 只在
        特定设备上需要。
      '';
    };

    cellDns = mkOption {
      type = types.listOf types.str;
      default = [
        "1.1.1.1"
        "8.8.8.8"
      ];
      example = [
        "223.5.5.5"
        "119.29.29.29"
      ];
      description = ''
        cell 里 DHCP 下发的两个 DNS。上游写死 1.1.1.1/8.8.8.8；Android 的
        opportunistic Private DNS 会用它们做 DoT，若宿主在 Clash/TUN 或受限网络里，
        每次解析会多出几百毫秒。改成就近解析器（如 AliDNS / DNSPod）即可。
      '';
    };

    applications = mkOption {
      type = types.listOf (types.either types.path types.package);
      default = [ ];
      example = lib.literalExpression "[ ./apks/example.apk ]";
      description = ''
        每次 droidloom.service 启动后安装或更新的 standalone APK。文件会进
        Nix store；从列表里删掉不会卸载 Android 里已安装的应用。
      '';
    };

    autoStart = mkOption {
      type = types.bool;
      default = false;
      description = ''
        登录图形会话后自动 `droidloomctl start --no-wait`（XDG autostart）。
        上游默认是手动启动，开着会常驻约 1-2 GiB 内存。
      '';
    };

    # 生成的 cell.json 本身，便于 `nix build` 检查改写结果与排查启动失败。
    cellSpec = mkOption {
      type = types.path;
      readOnly = true;
      internal = true;
      default = cellSpecFile;
      description = "生成的 /etc/droidloom/cell.json（内部调试用）";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = uid != 0;
        message = "services.droidloom 的 UID 不能是 0";
      }
      {
        assertion = cfg.uid == null || userAttrs.uid == null || cfg.uid == userAttrs.uid;
        message = "services.droidloom.uid 与 users.users.${cfg.user}.uid 不一致";
      }
      {
        assertion = lib.hasPrefix "/dev/dri/" cfg.renderNode;
        message = "services.droidloom.renderNode 必须是 /dev/dri/ 下的 render node";
      }
      {
        assertion = cfg.graphicsBackend != "forwarding" || cfg.gpu != null;
        message = "graphicsBackend = \"forwarding\" 时必须设置 services.droidloom.gpu";
      }
    ];

    environment.systemPackages = [
      droidloom.host
      pkgs.android-tools
      navScript
    ];

    # Android 需要能挂 binderfs（内核 CONFIG_ANDROID_BINDERFS=y；gaokun3 内核已内置）。
    # forwarding 和 dma_heap 后端还要 /dev/dma_heap/system，由 system_heap 模块提供。
    boot.kernelModules = lib.optionals (cfg.graphicsBackend != "drm") [ "system_heap" ];

    security.polkit.enable = true;
    # 只授权该用户 start/stop 这一个 unit，等价于上游 49-droidloom.rules。
    # 权限提示由 droidloom.service 的 ExecStartPre 触发（用户 unit 启动系统 daemon）。
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (action.id === "org.freedesktop.systemd1.manage-units" &&
            subject.user === ${builtins.toJSON cfg.user} &&
            action.lookup("unit") === "droidloomd.service" &&
            (action.lookup("verb") === "start" || action.lookup("verb") === "stop")) {
          return polkit.Result.YES;
        }
      });
    '';

    # 上游 unit 直接来自 host 包（system 与 user 两套都会被 NixOS 链接进 /etc/systemd）。
    systemd.packages = [ droidloom.host ];

    systemd.services.droidloomd = {
      # 上游按裸命令名 exec mount/unshare/losetup/ip/iptables/pw-cli…，
      # 系统 unit 默认 PATH 在 NixOS 上什么都不存在。
      path = droidloom.runtimePathPackages;

      preStart = ''
        # 只补缺失目录，绝不重置已有目录的属主/权限：Android 已经在里面初始化过数据。
        for dir in /var/lib/droidloom /var/lib/droidloom/users /var/lib/droidloom/users/${uidText}; do
          if [ -L "$dir" ]; then
            echo "refusing symlinked Droidloom storage path: $dir" >&2
            exit 1
          fi
          [ -d "$dir" ] || ${pkgs.coreutils}/bin/install -d -m 0755 "$dir"
        done
        for dir in ${dataDir} ${dataDir}/data ${dataDir}/metadata; do
          if [ -L "$dir" ]; then
            echo "refusing symlinked Droidloom storage path: $dir" >&2
            exit 1
          fi
          [ -d "$dir" ] || ${pkgs.coreutils}/bin/install -d -m 0700 "$dir"
        done
      '';
    };

    systemd.user.services = {
      droidloom = {
        path = droidloom.runtimePathPackages;
        # 多用户主机上其它用户不该启动同一份 /etc/droidloom/cell.json。
        unitConfig.ConditionUser = cfg.user;
      };

      droidloom-audio.path = droidloom.runtimePathPackages;
      droidloom-devices.path = droidloom.runtimePathPackages;
      droidloom-gpu.path = droidloom.runtimePathPackages;
      droidloom-applications.path = droidloom.runtimePathPackages;
      droidloom-recovery.path = droidloom.runtimePathPackages;

      droidloom-apks = mkIf (cfg.applications != [ ]) {
        description = "Install APKs declared in services.droidloom.applications";
        after = [ "droidloom.service" ];
        wantedBy = [ "droidloom.service" ];
        unitConfig.ConditionUser = cfg.user;
        serviceConfig = {
          Type = "oneshot";
          ExecStart = apkInstaller;
          TimeoutStartSec = "900s";
        };
      };
    };

    # 上游把配置放在 /etc/droidloom（root:root 0644、普通文件），并且拒绝符号链接，
    # 所以不能用 environment.etc（它生成 /etc/static 的符号链接）。
    system.activationScripts.droidloom = {
      deps = [ "etc" ];
      text = ''
        if [ -L /etc/droidloom ]; then
          echo "refusing symlinked /etc/droidloom" >&2
          exit 1
        fi
        ${pkgs.coreutils}/bin/install -d -m 0755 /etc/droidloom
        if [ -e /etc/droidloom/cell.json ] &&
           ! ${pkgs.diffutils}/bin/cmp -s ${cellSpecFile} /etc/droidloom/cell.json; then
          ${pkgs.coreutils}/bin/cp -a /etc/droidloom/cell.json /etc/droidloom/cell.json.before-nixos
        fi
        ${pkgs.coreutils}/bin/install -m 0644 ${cellSpecFile} /etc/droidloom/cell.json
        ${pkgs.coreutils}/bin/install -m 0644 ${runtimeEnv} /etc/droidloom/runtime.env
      '';
    };

    environment.etc = optionalAttrs cfg.autoStart {
      "xdg/autostart/droidloom.desktop".text = ''
        [Desktop Entry]
        Type=Application
        Name=Droidloom
        Comment=Start Android apps in native Wayland windows
        Exec=${autostartScript}
        Terminal=false
        NoDisplay=true
        X-GNOME-Autostart-enabled=true
      '';
    };
  };
}
