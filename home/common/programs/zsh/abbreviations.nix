# Common zsh abbreviations (platform-agnostic)
{ isDarwin, ... }:
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

      re =
        if isDarwin then
          "home-manager switch --flake /etc/nixos#darwin"
        else
          "sudo nixos-rebuild switch --flake /etc/nixos#nixos";

      gcm = ''git commit -S -m "%"'';
    };
  };
}
