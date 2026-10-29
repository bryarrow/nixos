{ pkgs, ... }:

let
  dataDir = "/home/berry/.local/share/io.github.clash-verge-rev.clash-verge-rev";

  # nixpkgs 的 v2ray-domain-list-community 缺少部分订阅引用的 MetaCubeX 分类
  # （如 APPLE-CN）。这里固定一份 MetaCubeX geosite.dat，并由下面的 service
  # 在开机/配置切换时覆盖到数据目录；只放进 Nix store 或包的 resources
  # 不会更新已有的数据目录。
  metaGeosite = pkgs.fetchurl {
    name = "geosite.dat";
    url = "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geosite.dat";
    hash = "sha256-OKrCoQdIWjgYUBEGKS77vJIhRYiqHWKsX7XYodGjNfc=";
  };
in
{
  programs.clash-verge = {
    enable = true;
    serviceMode = true;
    tunMode = true;
  };

  # Clash Verge 的 geodata 是内核从数据目录读取的（服务以
  # `-d /home/berry/.local/share/io.github.clash-verge-rev.clash-verge-rev` 启动内核），
  # 而 nixpkgs 包里的 lib/Clash\ Verge/resources/*.dat 只是首次运行时的播种来源。
  #
  # 数据目录必须由 berry 拥有且可写，否则 GUI 无法播种资源、保存配置或下载订阅
  # （journal 中表现为 PermissionDenied、“下载失败: failed to write to file”）。
  # 只用 `z` 不够：`z` 不会创建路径，如果目录在 tmpfiles 运行时尚不存在，
  # 之后被 root 的 clash-verge-service 先创建，就会一直保持 root 属主。
  # 因此用 `d` 预创建目录，用 `Z` 递归修正历史遗留的 root 属主文件。
  #
  # 另外 Rust 的 fs::copy 会保留权限位，而 Nix store 里的文件是 0444，
  # 于是播种出来的 geodata 副本也是只读的 —— 应用之后更新 GeoData 时无法覆盖
  # 自己这份数据，报目录/文件权限错，并连带导致“无法激活配置”。
  # `z` 规则在每次开机时把 geodata 权限改回 0644。
  systemd.tmpfiles.rules = [
    "d ${dataDir} 0755 berry users -"
    "d ${dataDir}/logs 0755 berry users -"
    "Z ${dataDir} - berry users -"
    "z ${dataDir}/geosite.dat 0644 berry users -"
    "z ${dataDir}/geoip.dat 0644 berry users -"
    "z ${dataDir}/Country.mmdb 0644 berry users -"
  ];

  systemd.services.clash-verge-geodata = {
    description = "Install pinned MetaCubeX geosite.dat for Clash Verge";
    wantedBy = [ "multi-user.target" ];
    restartTriggers = [ metaGeosite ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "clash-verge-geodata" ''
        set -eu
        ${pkgs.coreutils}/bin/install -d -o berry -g users -m 0755 "${dataDir}"
        ${pkgs.coreutils}/bin/install -o berry -g users -m 0644 "${metaGeosite}" "${dataDir}/.geosite.dat.tmp"
        ${pkgs.coreutils}/bin/mv -f "${dataDir}/.geosite.dat.tmp" "${dataDir}/geosite.dat"
      '';
    };
  };
}
