{ pkgs, ... }:

{
  nix.settings.trusted-users = [ "root" "@wheel" ];

  users.users.berry = {
    isNormalUser = true;
    # Droidloom 的 cell host_uid、数据目录和 denial socket 都依赖这个固定值。
    uid = 1000;
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
