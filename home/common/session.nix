# Common session variables (platform-agnostic)
# WSL-specific PATH (/mnt/c/...) belongs in home/wsl
{ config, isDarwin, lib, ... }:
let
  pkgConfigPathEntries =
    [
      "${config.home.profileDirectory}/lib/pkgconfig"
      "${config.home.profileDirectory}/share/pkgconfig"
    ]
    ++ lib.optionals (!isDarwin) [
      "/run/current-system/sw/lib/pkgconfig"
      "/run/current-system/sw/share/pkgconfig"
    ];
in
{
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    SUDO_EDITOR = "nvim";
    UV_TOOL_DIR = "${config.xdg.dataHome}/uv/tools";
    UV_TOOL_BIN_DIR = "${config.xdg.dataHome}/uv/tools/bin";
    PKG_CONFIG_PATH = lib.concatStringsSep ":" pkgConfigPathEntries;
  };

  home.sessionPath = [
    "$HOME/.local/bin"
    "${config.xdg.dataHome}/uv/tools/bin"
  ];
}
