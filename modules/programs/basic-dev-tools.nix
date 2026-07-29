{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    git
    jujutsu
  ];
}
