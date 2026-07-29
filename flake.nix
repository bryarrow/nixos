{
  description = "Berry 的 NixOS 系统配置";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { nixpkgs, ... }: {
    nixosConfigurations.berrysG15 = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hosts/Berrys-G15/configuration.nix
      ];
    };
  };
}
