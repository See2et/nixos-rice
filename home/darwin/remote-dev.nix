{ pkgs, ... }:
{
  home.packages = with pkgs; [
    mosh
  ];

  programs.ssh = {
    settings.home = {
      HostName = "nixos.taile209b8.ts.net";
      User = "see2et";
      IdentitiesOnly = true;
    };
  };
}
