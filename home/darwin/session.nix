# Darwin-specific session variables
{ config, lib, ... }:
{
  home.sessionVariables = {
    TYPST_FONT_PATHS = lib.concatStringsSep ":" [
      "${config.xdg.dataHome}/fonts"
      "/System/Library/Fonts"
      "/Library/Fonts"
      "${config.home.homeDirectory}/Library/Fonts"
    ];
  };
}
