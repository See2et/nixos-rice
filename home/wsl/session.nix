# WSL-specific session variables and PATH
# Adds Windows VS Code bin directory to PATH
# CRITICAL: Only for WSL, must NOT appear in desktop or darwin
{ config, ... }:
{
  home.sessionVariables = {
    EDITOR = "nvim";
    UV_TOOL_DIR = "${config.xdg.dataHome}/uv/tools";
    UV_TOOL_BIN_DIR = "${config.xdg.dataHome}/uv/tools/bin";
    PATH = ''
      $PATH:/mnt/c/Users/See2et/AppData/Local/Programs/Microsoft\ VS\ Code/bin
    '';
  };

  home.sessionPath = [
    "$HOME/.local/bin"
    "${config.xdg.dataHome}/uv/tools/bin"
  ];
}
