{ ... }:
{
  xdg.configFile = {
    "opencode/opencode.json" = {
      source = ../dotfiles/opencode/opencode.jsonc;
      force = true;
    };
    "opencode/tui.json" = {
      source = ../dotfiles/opencode/tui.jsonc;
      force = true;
    };
    "opencode/AGENTS.md" = {
      source = ../dotfiles/opencode/AGENTS.md;
      force = true;
    };
    "opencode/agents/chiron (deep tutor).md" = {
      source = ../dotfiles/opencode/agents/chiron.md;
      force = true;
    };
  };
}
