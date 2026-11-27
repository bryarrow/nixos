{
  description = "Berry 的 NixOS 系统配置";

  nixConfig = {
    extra-substituters = [
      "https://berrys-nixos.cachix.org"
      "https://gaokun3.cachix.org"
      "https://wvhulle.cachix.org"
    ];
    extra-trusted-public-keys = [
      "berrys-nixos.cachix.org-1:N4MjZIxrYDxyIQwm+95J63GhYehDnqs+LBLQUMtXkaY="
      "gaokun3.cachix.org-1:ikL6EofK55QEwKucrUo44SPKewscvAMJr7ibBxJtIsI="
      "wvhulle.cachix.org-1:heXx8DZMiRsKUx6l1TxNoF+Nmtmz66QEdsonQzc1ir0="
    ];
  };

  inputs = {
    gaokun3.url = "github:bryarrow/linux-gaokun-buildbot/gaokun3-nix";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-cuda12.url = "github:NixOS/nixpkgs/0954f7ee2f6bb3dc7d4e3d0d8bcb8fd4bde4cfc5";

    bootvine = {
      url = "git+https://codeberg.org/wvhulle/bootvine";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs = { nixpkgs, nixpkgs-cuda12, gaokun3, bootvine, ... }: {
    # Droidloom 的 host 包与 Android 载荷；`nix build .#droidloom` 即可单独构建，
    # 不必等整台机器的 toplevel。模块见 modules/programs/droidloom.nix。
    packages = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (system: {
      droidloom =
        (nixpkgs.legacyPackages.${system}.callPackage ./pkgs/droidloom/package.nix { }).host;
      droidloom-android =
        (nixpkgs.legacyPackages.${system}.callPackage ./pkgs/droidloom/package.nix { }).androidArtifacts;
    });

    checks = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        droidloom = pkgs.callPackage ./pkgs/droidloom/package.nix { };
      in
      {
        # 上游 unit 的 cgroup 委托是 Android 能起来的前提；同时确认没有 /usr 残留，
        # 且包装器 PATH 里带着 mount/unshare/modprobe 这些裸命令。
        droidloom-host = pkgs.runCommand "check-droidloom-host" { } ''
          grep -qx 'Delegate=memory pids' ${droidloom.host}/lib/systemd/system/droidloomd.service
          grep -qx 'DelegateSubgroup=supervisor' ${droidloom.host}/lib/systemd/system/droidloomd.service
          if grep -rq '/usr/' ${droidloom.host}/lib/systemd; then
            echo "units still reference /usr paths" >&2
            exit 1
          fi
          grep -q 'kmod' ${droidloom.host}/bin/droidloomctl
          test -x ${droidloom.host}/bin/droidloom-supervisor
          touch $out
        '';
      }
    );

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
        bootvine.nixosModules.default
        ./hosts/Berrys-EGO/configuration.nix
      ];
    };
  };
}
