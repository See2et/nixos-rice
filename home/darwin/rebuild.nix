# Darwin-specific rebuild abbreviation
{ ... }:
{
  programs.zsh.zsh-abbr.abbreviations.re =
    "sudo darwin-rebuild switch --flake path:/etc/nixos#darwin";
}
