{ ... }:

{
  programs.clash-verge = {
    enable = true;
    serviceMode = true;
    tunMode = true;
  };

  # Clash Verge 的 geodata 是内核从数据目录读取的（服务以
  # `-d ~/.local/share/io.github.clash-verge-rev.clash-verge-rev` 启动内核），
  # 而 nixpkgs 包里的 lib/Clash\ Verge/resources/*.dat 只是首次运行时的播种来源。
  #
  # 问题：Rust 的 fs::copy 会保留权限位，而 Nix store 里的文件是 0444，
  # 于是播种出来的数据目录副本也是只读的 —— 应用之后更新 GeoData 时无法覆盖
  # 自己这份数据，报目录/文件权限错，并连带导致“无法激活配置”。
  #
  # 这里在每次开机时把权限与属主修正回来，让应用能自行更新 GeoData，
  # 因此不需要再在 Nix 里 pin geosite 数据集。
  # `z` 类型只调整已存在的路径（不创建、不递归），幂等。
  systemd.tmpfiles.rules = [
    "z /home/berry/.local/share/io.github.clash-verge-rev.clash-verge-rev 0755 berry users -"
    "z /home/berry/.local/share/io.github.clash-verge-rev.clash-verge-rev/geosite.dat 0644 berry users -"
    "z /home/berry/.local/share/io.github.clash-verge-rev.clash-verge-rev/geoip.dat 0644 berry users -"
    "z /home/berry/.local/share/io.github.clash-verge-rev.clash-verge-rev/Country.mmdb 0644 berry users -"
  ];
}
