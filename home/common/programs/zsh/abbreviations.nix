# Common zsh abbreviations (platform-agnostic)
{ ... }:
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
      ze = "zellij --layout 1p2p";
      up = "cd ../";
      cl = "clear";

      gcm = ''git commit -S -m "%"'';
    };
  };
}
