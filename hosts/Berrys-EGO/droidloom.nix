{ ... }:

{
  # EGO 是 Adreno（msm）原生渲染；render node 与 users.nix 里的 berry 对应。
  services.droidloom = {
    enable = true;
    user = "berry";
    renderNode = "/dev/dri/renderD128";
    graphicsBackend = "drm";

    # Android 的 opportunistic Private DNS 会对 DHCP 下发的 DNS 做 DoT；
    # 上游默认的 1.1.1.1/8.8.8.8 在这里会被绕开 Clash，单次解析 300-600 ms。
    cellDns = [
      "223.5.5.5"
      "119.29.29.29"
    ];
  };
}
