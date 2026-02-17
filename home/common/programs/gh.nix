# Common GitHub CLI configuration
{ pkgs, ... }:
{
  programs.gh = {
    enable = true;
    extensions = [ pkgs.gh-notify ];
  };
}
