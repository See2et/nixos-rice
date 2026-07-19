# WSL-specific rebuild abbreviation
{ ... }:
{
  programs.zsh.zsh-abbr.abbreviations.re = "sudo nixos-rebuild dry-activate --flake /etc/nixos#wsl";
}
