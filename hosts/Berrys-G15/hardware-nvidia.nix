{ config, lib, pkg, ... }:

{

    nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
        "nvidia-x11"
        "nvidia-settings"
        "nvidia-kernel-modules"
    ];

    services.xserver.videoDrivers = [ "nvidia" ];

    hardware.graphics.enable = true;

    hardware.nvidia = {
      open = false;
      package = config.boot.kernelPackages.nvidiaPackages.latest;

      modesetting.enable = true;
      nvidiaSettings = true;

      prime = {
        offload.enable = true;
        offload.enableOffloadCmd = true;

        intelBusId = "PCI:0:2:0";
        nvidiaBusId = "PCI:1:0:0";
      };
    };

}
