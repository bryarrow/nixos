{ pkgs, ... }:

{
  users.users.berry = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    shell = pkgs.nushell;
  };
}
