{ pkgs, ... }:

let
  # nixpkgs 的 rime-ice 把上游 default.yaml 改名成了 rime_ice_suggestion.yaml
  #（pkgs/by-name/ri/rime-ice/package.nix），而 ibus-rime 在数据包里找不到
  # default.yaml 时会自己补一个空文件。空 default.yaml 的 schema_list 为空，
  # Rime 部署后没有任何可用方案，无法输入中文（看起来就像部署失败）。
  # 按 rime-ice 上游的说明补一份 default.custom.yaml，把它的默认配置包含进来。
  rimeIceDefaultCustom = pkgs.writeTextDir "share/rime-data/default.custom.yaml" ''
    patch:
      __include: rime_ice_suggestion:/
  '';
in

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
    type = "ibus";
    ibus.engines = with pkgs.ibus-engines; [
      (rime.override {
        rimeDataPkgs = [
          pkgs.rime-ice
          rimeIceDefaultCustom
        ];
      })
    ];
  };

  environment.sessionVariables.QT_IM_MODULES = "wayland;ibus";
}
