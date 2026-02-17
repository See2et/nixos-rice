{ pkgs, ... }:

{
  services.displayManager = {
    gdm.enable = true;
    defaultSession = "niri";
    sessionPackages = [ pkgs.niri ];
  };
}
