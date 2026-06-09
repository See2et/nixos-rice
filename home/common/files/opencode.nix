{ lib, pkgs, ... }:
let
  opencodeSkillCreatorSrc = pkgs.fetchFromGitHub {
    owner = "antongulin";
    repo = "opencode-skill-creator";
    rev = "726ae7668ea6b82c15cbf944ff73edd4843d20f0";
    hash = "sha256-AuubLFoc/HpQUSMPFCGwHZZJji1e5J4fwd27lk1DuGQ=";
  };

  # Pre-create the version marker so the plugin skips auto-installation.
  # The plugin checks .opencode-skill-creator-version against its package
  # version (0.2.18). If they match, it does not try to overwrite files.
  opencodeSkillCreator = pkgs.runCommand "opencode-skill-creator-with-version" { } ''
    cp -r ${opencodeSkillCreatorSrc}/opencode-skill-creator $out
    chmod -R +w $out
    echo "0.2.18" > $out/.opencode-skill-creator-version
  '';
in
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
    "opencode/oh-my-openagent.jsonc" = {
      source = ../dotfiles/opencode/oh-my-openagent.jsonc;
      force = true;
    };
    "opencode/agents/chiron (deep tutor).md" = {
      source = ../dotfiles/opencode/agents/chiron.md;
      force = true;
    };
    "opencode/skills/opencode-skill-creator" = {
      source = opencodeSkillCreator;
      recursive = true;
      force = true;
    };
  };
}
