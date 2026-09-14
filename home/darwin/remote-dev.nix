{ pkgs, ... }:
{
  home.packages = with pkgs; [
    mosh
  ];

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings.home = {
      HostName = "nixos.taile209b8.ts.net";
      User = "see2et";
      IdentityFile = "~/.ssh/id_ed25519";
      IdentitiesOnly = true;
    };
  };
}
