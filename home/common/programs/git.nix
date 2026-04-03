# Common git configuration
{ ... }:
{
  programs.git = {
    enable = true;
    lfs.enable = true;
    settings = {
      user.name = "See2et";
      user.email = "git@see2et.dev";
      safe.directory = "/etc/nixos";
    };
  };
}
