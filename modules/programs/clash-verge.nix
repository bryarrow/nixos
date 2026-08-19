{ config, lib, pkgs, ... }:

let
  metacubex-geosite = pkgs.runCommand "geosite-dir" {} ''
    mkdir -p $out/share/v2ray
    cp ${pkgs.fetchurl {
      url = "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geosite.dat";
      hash = "sha256-EXR2oO/aJsIY+kSrp3kiHFilXxzMzHkI/FoI4gq1q30=";
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
