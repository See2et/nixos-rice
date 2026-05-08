# Linux-specific session variables
{ config, lib, ... }:
let
  typstFontPaths = lib.concatStringsSep ":" [
    "${config.xdg.dataHome}/fonts"
    "/run/current-system/sw/share/X11/fonts"
    "/usr/share/fonts"
  ];
in
{
  home.sessionVariables = {
    PKG_CONFIG_PATH = lib.mkForce "${config.home.profileDirectory}/lib/pkgconfig:${config.home.profileDirectory}/share/pkgconfig:/run/current-system/sw/lib/pkgconfig:/run/current-system/sw/share/pkgconfig";
    TYPST_FONT_PATHS = lib.mkDefault typstFontPaths;
  };
}
