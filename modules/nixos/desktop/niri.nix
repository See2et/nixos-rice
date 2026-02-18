{ pkgs, ... }:

{
  programs.niri.enable = true;
  programs.niri.package = pkgs.niri;

  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gnome
      xdg-desktop-portal-gtk
    ];
    config.common = {
      default = [ "gnome" "gtk" ];
      "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
      "org.freedesktop.impl.portal.ScreenCast" = [ "gnome" ];
      "org.freedesktop.impl.portal.Screenshot" = [ "gnome" ];
    };
  };

  systemd.user.services = {
    xdg-desktop-portal.environment = {
      XDG_CURRENT_DESKTOP = "niri:GNOME";
    };

    xdg-desktop-portal-gnome.environment = {
      XDG_CURRENT_DESKTOP = "niri:GNOME";
    };
  };
}
