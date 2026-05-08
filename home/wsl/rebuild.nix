# WSL-specific rebuild abbreviation
{ ... }:
{
  programs.zsh.zsh-abbr.abbreviations.re = "sudo nixos-rebuild switch --flake /etc/nixos#wsl";
}
