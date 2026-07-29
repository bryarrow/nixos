{ lib, pkgs, ... }:

{
  # 规避 Nix 二进制包装器对路径去重时的边界问题：
  # 如果被前缀追加的路径已经位于 GIO_EXTRA_MODULES 末尾，包装器可能读到下一个环境变量，
  # 生成类似下面的错误值：
  #
  #   GIO_EXTRA_MODULES=.../dconf/lib/gio/modules:GTK_IM_MODULE=fcitx
  #
  # GNOME 会话包装器会前缀追加 dconf 和 glib-networking。
  # 这里把 gvfs 放在末尾，因为这些包装器不会前缀追加它。
  environment.sessionVariables.GIO_EXTRA_MODULES = lib.mkForce (
    lib.makeSearchPathOutput "lib" "lib/gio/modules" [
      pkgs.dconf
      pkgs.glib-networking
      pkgs.gvfs
    ]
  );

  # Firefox 由 GNOME Shell 通过 systemd 应用作用域启动时，GTK_PATH 不够稳定。
  # 直接指向 NixOS 生成的 GTK3 输入法模块缓存，确保 fcitx5 immodule 可被找到。
  environment.sessionVariables.GTK_IM_MODULE_FILE =
    "/run/current-system/sw/etc/gtk-3.0/immodules.cache";
}
