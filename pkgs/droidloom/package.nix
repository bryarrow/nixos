# Droidloom（Android 应用作为原生 Wayland 窗口）的 NixOS 移植。
#
# 上游只发 Arch 的 pacman 包。Android 侧载荷（system/vendor/product 分区、
# framework、surfaceflinger 等）是 AOSP 17 的构建产物，无法在 Nix 里重建，
# 所以这里编译上游 source release 里的 host 侧 Rust 程序，Android 载荷直接
# 解包上游 base + image 包原样放进 store——它们运行在 cell 里（bionic 链接器），
# 绝不能 patchelf。
#
# host 程序把 Arch 的 FHS 路径写死在源码里（/usr/bin/systemd-run、
# /usr/lib/droidloom/...、/usr/share/droidloom/package.json）。postPatch 把它们
# 替换成 store 路径；package.json 那条是"这是 pacman 安装"的判定，替换到不存在
# 的路径，让 droidloomctl 跳过 pkexec 包助手（NixOS 侧由 module 声明式完成 setup）。
{
  lib,
  stdenv,
  rustPlatform,
  fetchurl,
  runCommand,
  zstd,
  gnutar,
  pkg-config,
  clang,
  llvmPackages,
  libdrm,
  libgbm,
  mesa,
  wayland,
  libxkbcommon,
  pipewire,
  wireplumber,
  systemd,
  glibc,
  kmod,
  util-linux,
  coreutils,
  android-tools,
  polkit,
  nftables,
  iproute2,
  iptables,
  e2fsprogs,
  rsync,
  dbus,
  procps,
  findutils,
  gnugrep,
  gnused,
  glslang,
  libGL,
  libffi,
  zlib,
  vulkan-loader,
  makeWrapper,
  # 两个 IPv4 字符串：写进 cell 的 DHCP 租约。上游硬编码 1.1.1.1/8.8.8.8；
  # 在中国网络下 Android 的 opportunistic Private DNS 会用它们做 DoT，
  # 既绕过宿主的 Clash/TUN DNS，又是海外解析，单次查询 300-600 ms。
  cellDns ? [
    "1.1.1.1"
    "8.8.8.8"
  ],
}:

let
  version = "0.1.0-49";

  # 上游 release 按架构发布，base/image 只随目标架构变化。
  artifacts = {
    aarch64-linux = {
      runtime = "sha256-blzxjHwZbz/6WnnKk44Mr4MVVIYQ8hu220ra4ONdvCg=";
      image = "sha256-glfv+tETUD7F0O02ngstbWHNl283+TzluaIG+IOpYGI=";
      base = "sha256-QHEqbrG8xFHIxL3SylspUfhF0EHEdGpLsqB7Mlm0lHM=";
    };
    x86_64-linux = {
      runtime = "sha256-pQow/GZPEoRVbRztUaOGRBqytMIXeuWBKFoOsAKkaEw=";
      image = "sha256-ptzEnodycmKmskm9etDtFA0RSSULmD81HRUeW9r69p8=";
      base = "sha256-qjE9By+JNcbFZzKnRAote6uOt5dUDjDgdBHKkblfcm4=";
    };
  };

  arch = if stdenv.hostPlatform.isAarch64 then "aarch64" else "x86_64";
  hashes =
    artifacts.${stdenv.hostPlatform.system}
      or (throw "droidloom: unsupported system ${stdenv.hostPlatform.system}");

  release = "https://github.com/denialwm/droidloom/releases/download/packages";

  # DHCP 租约里 DNS 是编译期常量，这里把它变成可配置的 Rust 字面量。
  cellDnsRust =
    assert lib.asserts.assertMsg (
      builtins.length cellDns == 2
      && builtins.all (address: builtins.match "[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+" address != null) cellDns
    ) "droidloom: cellDns 必须是两个 IPv4 地址";
    lib.concatMapStringsSep ", " (
      address:
      let
        octets = lib.splitString "." address;
      in
      "Ipv4Addr::new(${lib.concatStringsSep ", " octets})"
    ) cellDns;

  sourceArchive = fetchurl {
    name = "droidloom-source-${version}.tar.gz";
    url = "${release}/droidloom-source-${version}.tar.gz";
    hash = "sha256-R/NozoN/dBHJhJSfdNe5QGTVsL8ibPpa67E8HpfQVwQ=";
  };

  runtimeArchive = fetchurl {
    name = "droidloom-runtime-${version}-${arch}.pkg.tar.zst";
    url = "${release}/droidloom-runtime-${version}-${arch}.pkg.tar.zst";
    hash = hashes.runtime;
  };

  imageArchive = fetchurl {
    name = "droidloom-image-${version}-${arch}.pkg.tar.zst";
    url = "${release}/droidloom-image-${version}-${arch}.pkg.tar.zst";
    hash = hashes.image;
  };

  baseArchive = fetchurl {
    name = "droidloom-base-${version}-${arch}.pkg.tar.zst";
    url = "${release}/droidloom-base-${version}-${arch}.pkg.tar.zst";
    hash = hashes.base;
  };

  unpackPackage =
    kind: archive:
    runCommand "droidloom-${kind}-${version}-${arch}"
      {
        nativeBuildInputs = [
          zstd
          gnutar
        ];
      }
      ''
        mkdir -p "$out"
        # 只取 usr/，不保留 pacman 的 .PKGINFO/.MTREE；--no-same-owner 让 store 里保持 root:root。
        ${zstd}/bin/unzstd -c ${archive} | tar --no-same-owner -xf - -C "$out" usr
      '';

  # 两份包合并成同一个前缀：base 提供 system/system_ext/product.img，
  # image 提供 vendor.raw.img、runtime（surfaceflinger 等）以及 current -> runtime 符号链接。
  androidArtifacts =
    runCommand "droidloom-android-${version}-${arch}"
      {
        nativeBuildInputs = [
          zstd
          gnutar
        ];
      }
      ''
        mkdir -p "$out/usr/lib/droidloom"
        ${zstd}/bin/unzstd -c ${baseArchive} | tar --no-same-owner -xf - -C "$out" usr
        ${zstd}/bin/unzstd -c ${imageArchive} | tar --no-same-owner -xf - -C "$out" usr
      '';

  runtimeMetadata = unpackPackage "runtime" runtimeArchive;
  runtimeShare = "${runtimeMetadata}/usr/share/droidloom";

  # 上游在多个地方按裸命令名 exec（mount/unshare/losetup/ip/iptables/pw-cli…），
  # host 程序本身没有 PATH，NixOS 的 /usr/bin 又不存在，所以统一给一个 store PATH：
  # 既用于替换源码里写死的 "/usr/bin:/bin"，也用于模块里各 unit 的 path。
  runtimePathPackages = [
    coreutils
    util-linux
    systemd
    glibc.bin
    kmod
    android-tools
    iproute2
    nftables
    iptables
    e2fsprogs
    gnutar
    zstd
    rsync
    polkit
    dbus
    procps
    findutils
    gnugrep
    gnused
    pipewire
    wireplumber
  ];

  runtimePath = lib.makeBinPath runtimePathPackages;

  # 源码替换顺序有依赖：
  #   1. 先把 package.json 判定改到不存在的路径（避免被下一条 /usr/share/droidloom 规则变成存在的文件）；
  #   2. /usr/share/droidloom 指向 runtime 包里的 cell-template.json；
  #   3. 先把包助手换成不存在的路径，避免被 /usr/lib/droidloom 规则变成"存在的 Arch ELF"；
  #   4. 其余 /usr/lib/droidloom 指向 Android 载荷（镜像、runtime、current 链接都在里面）。
  substituteHostPaths =
    {
      out,
      android,
      runtime,
    }:
    ''
      substituteInPlace $(find runtime graphics -name '*.rs') \
        --replace-quiet "/usr/share/droidloom/package.json" "/var/empty/droidloom-not-a-pacman-install" \
        --replace-quiet "/usr/share/droidloom" "${runtime}" \
        --replace-quiet "/usr/lib/droidloom/droidloom-package-helper" "/var/empty/droidloom-no-package-helper" \
        --replace-quiet "/usr/lib/droidloom" "${android}" \
        --replace-quiet "/usr/bin:/bin" "${runtimePath}" \
        --replace-quiet "/usr/bin/droidloom-" "${out}/bin/droidloom-" \
        --replace-quiet "/usr/bin/droidloomctl" "${out}/bin/droidloomctl" \
        --replace-quiet "/usr/bin/droidloomd" "${out}/bin/droidloomd" \
        --replace-quiet "/usr/bin/adb" "${android-tools}/bin/adb" \
        --replace-quiet "/usr/bin/systemctl" "${systemd}/bin/systemctl" \
        --replace-quiet "/usr/bin/systemd-run" "${systemd}/bin/systemd-run" \
        --replace-quiet "/usr/bin/getent" "${glibc.bin}/bin/getent" \
        --replace-quiet "/usr/bin/runuser" "${util-linux}/bin/runuser" \
        --replace-quiet "/usr/bin/nsenter" "${util-linux}/bin/nsenter" \
        --replace-quiet "/usr/bin/pkexec" "${polkit}/bin/pkexec" \
        --replace-quiet "/usr/bin/timeout" "${coreutils}/bin/timeout" \
        --replace-quiet "/usr/bin/sleep" "${coreutils}/bin/sleep" \
        --replace-quiet "/usr/bin/cat" "${coreutils}/bin/cat" \
        --replace-quiet "/usr/bin/env" "${coreutils}/bin/env"
    '';

  host = rustPlatform.buildRustPackage {
    pname = "droidloom-host";
    inherit version;

    src =
      runCommand "droidloom-source-${version}"
        {
          nativeBuildInputs = [ gnutar ];
        }
        ''
          mkdir -p "$out"
          tar -xzf ${sourceArchive} -C "$out" --strip-components=1
        '';

    # 只编译 host 侧；Android 侧二进制来自 image 包，Cargo workspace 里那些
    # 面向 bionic 的 crate 不参与构建。
    cargoBuildFlags = [
      "-p"
      "droidloom-supervisor"
      "-p"
      "droidloom-wayland"
      "-p"
      "droidloom-applications"
      "-p"
      "droidloom-audio"
      "-p"
      "droidloom-devices"
      "-p"
      "droidloom-doctor"
      "-p"
      "droidloom-gpu-server"
    ];

    # 固定 Cargo.lock 对应的 vendor hash；升级 version 时要一起更新（nix 会报新值）。
    cargoHash = "sha256-7XFLef9cTWLHTHaOmvmidIcfiNiZioJOQSMvvysNVhg=";

    nativeBuildInputs = [
      pkg-config
      clang
      llvmPackages.libclang
      glslang
      makeWrapper
    ];

    buildInputs = [
      libdrm
      libgbm
      mesa
      wayland
      libxkbcommon
      pipewire
      libGL
      libffi
      zlib
      vulkan-loader
    ];

    LIBCLANG_PATH = "${llvmPackages.libclang.lib}/lib";

    doCheck = false;

    postPatch =
      substituteHostPaths {
        out = "$out";
        android = "${androidArtifacts}/usr/lib/droidloom";
        runtime = runtimeShare;
      }
      + ''
        # 上游把 cell 的 DHCP DNS 写死成 1.1.1.1/8.8.8.8。Android 的
        # opportunistic Private DNS 会对它做 DoT，绕过宿主 Clash/TUN 的 DNS，
        # 于是每次解析都要 300-600 ms（海外 + TLS）。换成可达的解析器后
        # 走宿主网络，国内 CDN 也能拿到就近 IP。
        substituteInPlace runtime/droidloom-supervisor/src/development_network.rs \
          --replace-fail \
            "dns: [Ipv4Addr::new(1, 1, 1, 1), Ipv4Addr::new(8, 8, 8, 8)]" \
            "dns: [${cellDnsRust}]"
      '';

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/bin"
      for name in \
        droidloomd droidloomctl droidloom-supervisor droidloom-wayland \
        droidloom-applications droidloom-audio droidloom-devices \
        droidloom-doctor droidloom-gpu-server
      do
        binary=
        for candidate in "target/release/$name" target/*/release/"$name"; do
          if [ -x "$candidate" ]; then
            binary="$candidate"
            break
          fi
        done
        if [ -z "$binary" ]; then
          echo "droidloom: cargo did not produce $name" >&2
          exit 1
        fi
        install -m755 "$binary" "$out/bin/$name"
      done

      # 裸命令（mount、unshare、pw-cli…）和 dlopen 的 Vulkan loader 都靠包装器兜底；
      # systemd 的 unit 也会再设一次 PATH（见模块），两边一致。
      for name in \
        droidloomd droidloomctl droidloom-wayland droidloom-gpu-server \
        droidloom-applications droidloom-audio droidloom-devices droidloom-doctor
      do
        wrapProgram "$out/bin/$name" \
          --prefix PATH : "${runtimePath}" \
          --prefix LD_LIBRARY_PATH : "${vulkan-loader}/lib"
      done

      # 生命周期 unit 直接沿用上游，保证 cgroup 委托（DelegateSubgroup=supervisor）、
      # OOMPolicy 等行为与 Arch 一致；只替换 host 路径。
      for kind in system user; do
        mkdir -p "$out/lib/systemd/$kind"
        cp -a "${runtimeMetadata}/usr/lib/systemd/$kind/." "$out/lib/systemd/$kind/"
        chmod 0644 "$out"/lib/systemd/"$kind"/*
        substituteInPlace "$out"/lib/systemd/"$kind"/* \
          --replace-quiet "/usr/bin/droidloom-" "$out/bin/droidloom-" \
          --replace-quiet "/usr/bin/droidloomctl" "$out/bin/droidloomctl" \
          --replace-quiet "/usr/bin/droidloomd" "$out/bin/droidloomd" \
          --replace-quiet "/usr/bin/systemctl" "${systemd}/bin/systemctl" \
          --replace-quiet "/usr/lib/environment.d/60-droidloom.conf" "/etc/droidloom/runtime.env"
      done

      install -Dm644 "${runtimeShare}/cell-template.json" "$out/share/droidloom/cell-template.json"

      runHook postInstall
    '';

    meta = {
      description = "Android apps as native Wayland windows (NixOS host build)";
      homepage = "https://denialwm.org/droidloom";
      license = lib.licenses.gpl3Plus;
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
      platforms = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      mainProgram = "droidloomctl";
      # 这里是早期预览：真正能否启动取决于内核 binderfs、GPU 与上游镜像版本，
      # 不做 broken 标记，否则 nix build 默认会拒绝求值。
    };
  };
in
{
  inherit
    host
    androidArtifacts
    runtimeMetadata
    runtimePath
    runtimePathPackages
    ;
}
