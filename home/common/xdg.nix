{ ... }:
{
  xdg.enable = true;

  xdg.configFile = {
    "nvim" = {
      source = ./dotfiles/nvim;
      recursive = true;
      force = true;
    };
    "zellij" = {
      source = ./dotfiles/zellij;
      recursive = true;
      force = true;
    };
  };
}
