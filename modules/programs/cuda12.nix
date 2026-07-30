{ nixpkgs-cuda12, pkgs, ... }:

let
  cudaPkgs = import nixpkgs-cuda12 {
    inherit (pkgs.stdenv.hostPlatform) system;

  config = {
      allowUnfree = true;
      cudaSupport = true;
    };
  };
in
{
  environment.systemPackages = [
    cudaPkgs.cudaPackages.cuda_cudart
    cudaPkgs.cudaPackages.cudnn
    pkgs.zlib
  ];

  environment.sessionVariables = {
    CUDA12_LD_PATH = "${cudaPkgs.cudaPackages.cuda_cudart}/lib:${cudaPkgs.cudaPackages.cudnn.lib}/lib:/run/opengl-driver/lib";
  };
}
