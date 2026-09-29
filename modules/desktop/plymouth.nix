{ ... }:

{
  boot.initrd.kernelModules = [
    "msm"
  ];

  boot.plymouth = {
    enable = true;
    theme = "spinner";
  };

  boot.initrd.systemd.enable = true;

  boot.kernelParams = [
    "quiet"
    "splash"
  ];
}