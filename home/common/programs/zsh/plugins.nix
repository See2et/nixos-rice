# Common zsh plugins
{ lib, pkgs, ... }:
let
  plugins = pkgs.writeText "hm_antidote-files" ''
    ohmyzsh/ohmyzsh
    zsh-users/zsh-autosuggestions
    zsh-users/zsh-syntax-highlighting
    romkatv/powerlevel10k
    Tarrasch/zsh-bd
  '';
in
{
  home.packages = [ pkgs.antidote ];

  # Keep generated source paths with their actual plugin cache, never in shared /tmp.
  programs.zsh.initContent = lib.mkOrder 550 ''
    source ${pkgs.antidote}/share/antidote/antidote.zsh
    source ${./antidote-load.zsh} ${plugins}
  '';
}
