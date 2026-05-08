# Linux host rebuild abbreviation
{ hostId, lib, ... }:
let
  rebuildCommands = {
    desktop = "sudo nixos-rebuild switch --flake /etc/nixos#desktop";
    laptop = "sudo nixos-rebuild switch --flake /etc/nixos#laptop";
  };
in
{
  programs.zsh.zsh-abbr.abbreviations = lib.mkIf (builtins.hasAttr hostId rebuildCommands) {
    re = rebuildCommands.${hostId};
  };
}
