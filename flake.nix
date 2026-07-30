{
  description = "Berry 的 NixOS 系统配置";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-cuda12.url = "github:NixOS/nixpkgs/0954f7ee2f6bb3dc7d4e3d0d8bcb8fd4bde4cfc5";
  };

  outputs = { nixpkgs, nixpkgs-cuda12, ... }: {
    nixosConfigurations.berrysG15 = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {
        inherit nixpkgs-cuda12;
      };
      modules = [
        ./hosts/Berrys-G15/configuration.nix
      ];
    };
  };
}
