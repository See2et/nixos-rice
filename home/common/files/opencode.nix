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
    "opencode/skills/review-work" = {
      source = ../dotfiles/opencode/skills/review-work;
      recursive = true;
      force = true;
    };
    "opencode/skills/visual-qa" = {
      source = ../dotfiles/opencode/skills/visual-qa;
      recursive = true;
      force = true;
    };
    "opencode/agents/chiron (deep tutor).md" = {
      source = ../dotfiles/opencode/agents/chiron.md;
      force = true;
    };
    "opencode/agents/visual-director.md" = {
      source = ../dotfiles/opencode/agents/visual-director.md;
      force = true;
    };
  };
}
