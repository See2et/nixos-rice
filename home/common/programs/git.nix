# Common git configuration
{ ... }:
{
  programs.git = {
    enable = true;
    lfs.enable = true;
  };
}
