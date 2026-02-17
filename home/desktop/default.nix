{ inputs, ... }:
{
  imports = [
    inputs.niri.homeModules.niri
    ./niri.nix
    ./waybar.nix
    ./packages.nix
    ./xdg.nix
  ];
}
