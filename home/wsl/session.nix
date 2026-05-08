# WSL-specific session variables and PATH
# Adds Windows VS Code bin directory to PATH and Windows font discovery
# CRITICAL: Only for WSL, must NOT appear in desktop or darwin
{ config, lib, ... }:
{
  home.sessionVariables = {
    TYPST_FONT_PATHS = lib.concatStringsSep ":" [
      "${config.xdg.dataHome}/fonts"
      "/run/current-system/sw/share/X11/fonts"
      "/usr/share/fonts"
      "/mnt/c/Windows/Fonts"
    ];
  };

  home.sessionPath = [
    "/mnt/c/Users/See2et/AppData/Local/Programs/Microsoft VS Code/bin"
  ];
}
