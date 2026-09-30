{ pkgs, ... }:

{
  services.netbird.enable = true; # NetBird service and CLI
  environment.systemPackages = [ pkgs.netbird-ui ]; # Desktop app
}