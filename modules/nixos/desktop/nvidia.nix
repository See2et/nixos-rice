{
  config,
  pkgs,
  ...
}:

{
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    open = true;
    modesetting.enable = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  hardware.graphics = {
    enable32Bit = true;
    extraPackages32 = with pkgs.pkgsi686Linux; [ mesa ];
  };
}
