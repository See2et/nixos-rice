# Darwin-specific rebuild abbreviation
{ ... }:
{
  programs.zsh.zsh-abbr.abbreviations.re = "darwin-rebuild switch --flake /etc/nixos#darwin";
}
