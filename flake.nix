{
  description = "Berry 的 NixOS 系统配置";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-cuda12.url = "github:NixOS/nixpkgs/0954f7ee2f6bb3dc7d4e3d0d8bcb8fd4bde4cfc5";
   
    gaokun3.url = "github:bryarrow/linux-gaokun-buildbot/gaokun3-nix-debug";
    gaokun3.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, nixpkgs-cuda12, gaokun3, ... }: {
    nixosConfigurations.berrysG15 = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {
        inherit nixpkgs-cuda12;
      };
      modules = [
        ./hosts/Berrys-G15/configuration.nix
      ];
    };
    nixosConfigurations.berrysEGO = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      specialArgs = { inherit gaokun3; };
      modules = [
        ./hosts/Berrys-EGO/configuration.nix
      ];
    };
  };
}
