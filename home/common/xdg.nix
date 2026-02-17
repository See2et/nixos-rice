{ ... }:
{
  xdg.enable = true;

  xdg.configFile = {
    "nvim" = {
      source = ../../nvim;
      recursive = true;
      force = true;
    };
    "zellij" = {
      source = ../../zellij;
      recursive = true;
      force = true;
    };
  };
}
