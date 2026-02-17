{ inputs, pkgs, lib, ... }:
{
  imports = [
    ./niri.nix
    ./waybar.nix
    ./packages.nix
    ./xdg.nix
  ];

  options.programs.niri.enable = lib.mkEnableOption "niri";
  config.programs.niri.enable = true;
}
