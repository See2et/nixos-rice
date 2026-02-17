{ pkgs, ... }:

{
  programs.niri.enable = true;
  programs.niri.package = pkgs.niri;

  xdg.portal.enable = true;
  xdg.portal.xdgOpenUsePortal = true;
}
