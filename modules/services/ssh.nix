{ ... }:

{
  # 端口、密码登录与 root 登录策略直接使用 NixOS 默认值：
  # ports = [ 22 ]、PasswordAuthentication = true、PermitRootLogin = "prohibit-password"。
  # 如需收紧，请在这里显式覆盖 settings。
  services.openssh.enable = true;
}
