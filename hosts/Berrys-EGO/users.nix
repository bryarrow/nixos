{ pkgs, ... }:

{
  users.users.berry = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    shell = pkgs.nushell;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILLAqzFMwuJNgG7rIUNwRij3iqlyXETet8l1424LtnMn berry@Berrys-G15"
    ];
  };

  environment.shells = [ pkgs.nushell ];

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILLAqzFMwuJNgG7rIUNwRij3iqlyXETet8l1424LtnMn berry@Berrys-G15"
  ];
}
