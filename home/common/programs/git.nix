# Common git configuration
{ ... }:
{
  programs.git = {
    enable = true;
    lfs.enable = true;
    ignores = [
      ".direnv/"
      ".chiron/"
      ".nix-mingw/"
      ".omo/"
      ".envrc"
    ];
    settings = {
      user.name = "See2et";
      user.email = "git@see2et.dev";
      safe.directory = "/etc/nixos";
      push.autoSetupRemote = true;
      branch.autoSetupMerge = true;
    };
  };
}
