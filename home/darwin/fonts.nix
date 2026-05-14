{ pkgs, ... }:
{
  home.packages = import ../../shared/font-packages.nix { inherit pkgs; };
}
