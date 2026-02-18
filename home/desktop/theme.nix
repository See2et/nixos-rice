{ lib, pkgs, ... }:
let
  inherit (lib) mkForce;
  gtkTheme = "catppuccin-frappe-blue-standard";
  iconTheme = "Papirus-Dark";
  cursorTheme = "Bibata-Modern-Ice";
  cursorSize = 24;
in
{
  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
  };

  gtk = {
    enable = true;
    theme = {
      name = mkForce gtkTheme;
      package = mkForce pkgs.catppuccin-gtk;
    };
    iconTheme = {
      name = mkForce iconTheme;
      package = mkForce pkgs.papirus-icon-theme;
    };
    cursorTheme = {
      name = mkForce cursorTheme;
      package = mkForce pkgs.bibata-cursors;
    };
    gtk3.extraConfig.gtk-application-prefer-dark-theme = 1;
    gtk4.extraConfig.gtk-application-prefer-dark-theme = 1;
  };

  home.pointerCursor = {
    package = pkgs.bibata-cursors;
    name = cursorTheme;
    size = cursorSize;
    gtk.enable = true;
    x11.enable = true;
  };

  qt = {
    enable = true;
    platformTheme.name = "gtk3";
    style = {
      name = "kvantum";
      package = pkgs.libsForQt5.qtstyleplugin-kvantum;
    };
  };

  home.packages = [
    pkgs.catppuccin-kvantum
    pkgs.qt6Packages.qtstyleplugin-kvantum
  ];

  xdg.configFile."Kvantum/kvantum.kvconfig".text = ''
    [General]
    theme=catppuccin-frappe-blue
  '';
}
