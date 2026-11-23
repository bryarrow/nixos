{ pkgs, ... }:

{
  nix.settings.trusted-users = [ "root" "@wheel" ];

  users.users.berry = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    shell = pkgs.nushell;
  };

  environment.shells = [ pkgs.nushell ];
}
