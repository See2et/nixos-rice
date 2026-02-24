# Common git configuration
{ ... }:
{
  programs.git = {
    enable = true;
    lfs.enable = true;
    settings = {
      safe.directory = "/etc/nixos";
    };
  };
}
