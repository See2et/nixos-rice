{ ... }:
{
  home.file = {
    ".codex/config.toml" = {
      source = ../dotfiles/codex/config.toml;
      force = true;
    };
    ".agents/skills/miloa-gtd" = {
      source = ../dotfiles/codex/skills/miloa-gtd;
      force = true;
    };
  };
}
