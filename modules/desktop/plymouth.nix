{ ... }:

{
  boot.plymouth = {
    enable = true;
    theme = "spinner";
  };

  boot.kernelParams = [
    "quiet"
    "splash"
  ];
}