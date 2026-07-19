# Linux host rebuild abbreviation
{ hostId, lib, ... }:
let
  rebuildCommands = {
    desktop = "sudo nixos-rebuild dry-activate --flake /etc/nixos#desktop";
  };
in
{
  programs.zsh.zsh-abbr.abbreviations = lib.mkIf (builtins.hasAttr hostId rebuildCommands) {
    re = rebuildCommands.${hostId};
  };
}
