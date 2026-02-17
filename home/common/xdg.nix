# Common XDG configuration
{ ... }:
{
  xdg.configFile = {
    "nvim".source = ../../nvim;
    "zellij".source = ../../zellij;
  };

  xdg.enable = true;
}
