{ config, lib, pkgs, ... }:

let
  metacubex-geosite = pkgs.runCommand "geosite-dir" {} ''
    mkdir -p $out/share/v2ray
    cp ${pkgs.fetchurl {
      url = "https://cdn.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@2f48b0534e59710bf45837236e1884158c0c8478/geosite.dat";
      hash = "sha256-OvFgtWc74CDEBCKuOwOzIKOa+buaUrUm9u4YAj/lrd0=";
    }} $out/share/v2ray/geosite.dat
  '';
in
{
  nixpkgs.overlays = [
    (final: prev: {
      mihomo = prev.mihomo.overrideAttrs (old: rec {
        version = "1.19.26";
        src = prev.fetchFromGitHub {
          owner = "MetaCubeX";
          repo = "mihomo";
          rev = "v${version}";
          hash = "sha256-As0MqIGHs1Gn+aUWpeFsC231n9v7lBNmGlQdAwVWcJs=";
        };
        vendorHash = "sha256-ySpBMR/djPPs1aTw7yiCrCFxDFsvRfTJEChg8v1C408=";
      });

      clash-verge-rev = prev.clash-verge-rev.override {
        v2ray-domain-list-community = metacubex-geosite;
      };
    })
  ];

  programs.clash-verge = {
    enable = true;
    serviceMode = true;
    tunMode = true;
  };
}
