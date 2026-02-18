# Common session variables (platform-agnostic)
# WSL-specific PATH (/mnt/c/...) belongs in home/wsl
{ config, ... }:
{
  xdg.configFile = {
    "opencode/opencode.json" = {
      source = ../../opencode.jsonc;
      force = true;
    };
    "opencode/AGENTS.md" = {
      source = ../../opencode/AGENTS.md;
      force = true;
    };
    "opencode/oh-my-opencode.jsonc" = {
      source = ../../oh-my-opencode.jsonc;
      force = true;
    };
  };

  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    SUDO_EDITOR = "nvim";
    UV_TOOL_DIR = "${config.xdg.dataHome}/uv/tools";
    UV_TOOL_BIN_DIR = "${config.xdg.dataHome}/uv/tools/bin";
  };

  home.sessionPath = [
    "$HOME/.local/bin"
    "${config.xdg.dataHome}/uv/tools/bin"
  ];
}
