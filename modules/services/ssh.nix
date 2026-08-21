{ ... }:

{
  services.openssh = {
    enable = true;
    ports = [ 22 ]; # 可修改默认端口以提高安全性
    settings = {
      PasswordAuthentication = true; # 允许密码登录（建议生产环境关闭）
      PermitRootLogin = "prohibit-password"; # 禁止 root 直接用密码登录
      AllowUsers = [ "berry" ]; # 限制允许登录的用户
    };
  };
}