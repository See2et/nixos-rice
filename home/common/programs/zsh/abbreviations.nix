# Common zsh abbreviations (platform-agnostic)
{ config, lib, ... }:
{
  programs.zsh.zsh-abbr = {
    enable = true;
    abbreviations = {
      v = "nvim";
      ll = "lsd -alF";
      ls = "lsd";
      la = "lsd -altr";
      lg = "lazygit";
      bat = "batcat";
      up = "cd ../";
      cl = "clear";

      gcm = ''git commit -S -m "%"'';
    }
    // lib.optionalAttrs config.programs.zellij.enable {
      ze = "zellij --layout 1p2p";
    };
  };
}
