{ config, pkgs, ... }:

{
  # 允许系统运行 x86_64 二进制文件（上一问的配置）
  boot.binfmt.registrations.box64 = {
  interpreter = "${pkgs.box64}/bin/box64";
  magicOrExtension = "\\x7fELF\\x02\\x01\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x02\\x00\\x3e\\x00";
  mask = "\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\x00\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\xfe\\xff\\xff\\xff";
  
  # 显式关闭 Shell 包装，允许开启 fixBinary
  wrapInterpreterInShell = false; 
  fixBinary = true;
};

  # 告诉 Nix 你的系统“假装”支持 x86_64-linux 的求值与构建
  nix.settings.extra-platforms = [ "x86_64-linux" ];
}
