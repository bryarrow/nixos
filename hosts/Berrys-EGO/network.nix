{ ... }:

{
  # 使用 NetworkManager 管理无线和有线网络。
  networking.networkmanager.enable = true;

  # 固定 DNS，避免 NetworkManager 覆盖 resolv.conf。
  networking.networkmanager.dns = "none";
  networking.nameservers = [ "114.114.114.114" ];

  # 预加载 netfilter 模块：iptables-nft 首次调用时 request_module 自动加载
  # 在 boot 时与 udev 竞态，偶发导致 firewall.service 永久挂起。这里改为
  # systemd-modules-load（先于防火墙单元）加载。
  boot.kernelModules = [
    "nf_tables" "nf_conntrack" "nft_compat"
    "xt_conntrack" "xt_pkttype" "xt_state"
  ];

  # 如需系统级代理，可在这里启用并改成自己的地址。
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";
}
