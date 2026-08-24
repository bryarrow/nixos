{ pkgs, ... }:

{
  nixpkgs.overlays = [
    (import ../../pkgs/gnome-rounded-blur/overlay.nix)
    (import ../../pkgs/mutter-touch-fix/overlay.nix)
  ];

  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  environment.systemPackages = with pkgs; [
    gnome-rounded-blur
    gnomeExtensions.blur-my-shell
    gnomeExtensions.just-perfection
    gnomeExtensions.dash-to-dock
    gnomeExtensions.kimpanel
    gnomeExtensions.night-theme-switcher
    gnomeExtensions.coverflow-alt-tab
    gnomeExtensions.appindicator

    refine
  ];
}
