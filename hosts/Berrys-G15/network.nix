{ ... }:

{
  # 使用 NetworkManager 管理无线和有线网络。
  networking.networkmanager.enable = true;

  # 固定 DNS，避免 NetworkManager 覆盖 resolv.conf。
  networking.networkmanager.dns = "none";
  networking.nameservers = [ "114.114.114.114" ];

  # 如需系统级代理，可在这里启用并改成自己的地址。
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";
}
