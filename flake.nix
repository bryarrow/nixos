{
  description = "Berry 的 NixOS 系统配置";

  nixConfig = {
    extra-substituters = [
      "https://berrys-nixos.cachix.org"
      "https://gaokun3.cachix.org"
    ];
    extra-trusted-public-keys = [
      "berrys-nixos.cachix.org-1:N4MjZIxrYDxyIQwm+95J63GhYehDnqs+LBLQUMtXkaY="
      "gaokun3.cachix.org-1:ikL6EofK55QEwKucrUo44SPKewscvAMJr7ibBxJtIsI="
    ];
  };

  inputs = {
    gaokun3.url = "github:bryarrow/linux-gaokun-buildbot/gaokun3-nix";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-cuda12.url = "github:NixOS/nixpkgs/0954f7ee2f6bb3dc7d4e3d0d8bcb8fd4bde4cfc5";
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
