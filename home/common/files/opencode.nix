{ ... }:
{
  xdg.configFile = {
    "opencode/opencode.json" = {
      source = ../dotfiles/opencode/opencode.jsonc;
      force = true;
    };
    "opencode/AGENTS.md" = {
      source = ../dotfiles/opencode/AGENTS.md;
      force = true;
    };
    "opencode/oh-my-opencode.jsonc" = {
      source = ../dotfiles/opencode/oh-my-opencode.jsonc;
      force = true;
    };
  };
}
