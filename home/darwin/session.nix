# Darwin-specific session variables
{ config, lib, ... }:
{
  home.sessionVariables = {
    TYPST_FONT_PATHS = import ../../shared/typst-font-paths.nix {
      inherit lib config;
      extraPaths = [
        "/System/Library/Fonts"
        "/Library/Fonts"
        "${config.home.homeDirectory}/Library/Fonts"
      ];
    };
  };
}
