{ ... }:

{
  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = [ "*" ];
      settings = {
        main = {
          capslock = "layer(control)";
        };

        # Super+Shift 同时按住时，c 输出 caps lock。
        # 复合层（composite layer）没有 chording 的时间窗限制，
        # 且命中的绑定会忽略 Super/Shift 修饰键，输出裸 capslock。
        "meta+shift" = {
          c = "capslock";
        };
      };
    };
  };
}