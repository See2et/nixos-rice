{ ... }:
{
  home.file.".omo/omo.jsonc" = {
    source = ../dotfiles/opencode/omo.jsonc;
    force = true;
  };

  # Shared domain/specification skills live in the independently managed
  # ~/.agents/skills checkout (https://github.com/See2et/agent-skills).
  # OpenCode discovers them directly; do not deploy duplicate copies here.
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
