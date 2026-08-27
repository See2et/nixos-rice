{ ... }:
{
  home.file.".omo/omo.jsonc" = {
    source = ../dotfiles/opencode/omo.jsonc;
    force = true;
  };

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
    "opencode/skills/domain-contract-design" = {
      source = ../dotfiles/opencode/skills/domain-contract-design;
      recursive = true;
      force = true;
    };
    "opencode/skills/executable-specification" = {
      source = ../dotfiles/opencode/skills/executable-specification;
      recursive = true;
      force = true;
    };
    "opencode/agents/chiron (deep tutor).md" = {
      source = ../dotfiles/opencode/agents/chiron.md;
      force = true;
    };
  };
}
