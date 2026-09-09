{ pkgs, ... }:

{
  # Gmail MCP refresh tokens use the desktop session's Secret Service vault.
  services.gnome.gnome-keyring.enable = true;
  services.displayManager = {
    gdm.enable = true;
    defaultSession = "niri";
    sessionPackages = [ pkgs.niri ];
  };
}
