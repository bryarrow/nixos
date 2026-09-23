{ pkgs, ... }:

{
  time.timeZone = "Asia/Shanghai";

  # i18n.supportedLocales 无需配置：其默认值已包含 C.UTF-8、en_US.UTF-8，
  # 并根据 defaultLocale/extraLocaleSettings 自动加入 zh_CN.UTF-8。
  i18n.defaultLocale = "zh_CN.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "zh_CN.UTF-8";
    LC_IDENTIFICATION = "zh_CN.UTF-8";
    LC_MEASUREMENT = "zh_CN.UTF-8";
    LC_MONETARY = "zh_CN.UTF-8";
    LC_NAME = "zh_CN.UTF-8";
    LC_NUMERIC = "zh_CN.UTF-8";
    LC_PAPER = "zh_CN.UTF-8";
    LC_TELEPHONE = "zh_CN.UTF-8";
    LC_TIME = "zh_CN.UTF-8";
  };

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.addons = with pkgs; [
      qt6Packages.fcitx5-chinese-addons
      fcitx5-gtk
    ];
  };

  # XMODIFIERS、QT_IM_MODULE、GTK_IM_MODULE 已由 fcitx5 模块在
  # environment.variables 中设置；这里只补充 Qt6 在 Wayland 下需要的模块顺序。
  # 不要设置 LC_ALL，它会覆盖上面所有 LC_* 分类。
  environment.sessionVariables.QT_IM_MODULES = "wayland;fcitx";
}
