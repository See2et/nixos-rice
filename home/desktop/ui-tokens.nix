{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.desktop.ui.tokens = {
    colors = mkOption {
      type = types.attrsOf types.str;
      description = "Shared desktop color tokens.";
    };

    typography = mkOption {
      type = types.attrsOf (
        types.oneOf [
          types.str
          types.int
          (types.attrsOf types.int)
        ]
      );
      description = "Shared desktop typography tokens.";
    };

    radii = mkOption {
      type = types.attrsOf types.int;
      description = "Shared desktop corner radius tokens.";
    };

    spacing = mkOption {
      type = types.attrsOf types.int;
      description = "Shared desktop spacing tokens.";
    };

    opacity = mkOption {
      type = types.attrsOf types.float;
      description = "Shared desktop opacity tokens.";
    };

    blur = mkOption {
      type = types.attrsOf types.int;
      description = "Shared desktop blur tokens.";
    };

    sizes = mkOption {
      type = types.attrsOf types.int;
      description = "Shared desktop component size tokens.";
    };
  };

  config.desktop.ui.tokens = {
    colors = {
      background = "#1b1b1d";
      surface = "#242526";
      surfaceElevated = "#2b2d30";
      foreground = "#e3e3e3";
      muted = "#525860";
      border = "#444950";
      accent = "#00d4ff";
      danger = "#fa383e";
      success = "#00a400";
      warning = "#ffcc66";
      info = "#99ffdd";
      lavender = "#b4befe";
      overlay = "#121315";
      transparent = "#00000000";
    };

    typography = {
      family = ''"FiraCode Nerd Font", "Noto Sans CJK JP", "Noto Sans CJK SC", "Noto Color Emoji", sans-serif'';
      iconFamily = ''"FiraCode Nerd Font", "Symbols Nerd Font Mono", "Noto Color Emoji", sans-serif'';
      monoFamily = ''"FiraCode Nerd Font", "Noto Sans CJK JP", "Noto Sans CJK SC", monospace'';
      size = {
        sm = 12;
        md = 13;
        lg = 15;
      };
    };

    radii = {
      sm = 4;
      md = 6;
      lg = 10;
      pill = 999;
    };

    spacing = {
      xs = 2;
      sm = 4;
      md = 6;
      lg = 8;
      xl = 10;
      xxl = 12;
      xxxl = 16;
    };

    opacity = {
      panel = 0.95;
      overlay = 0.92;
      dim = 0.35;
    };

    blur = {
      panel = 10;
      overlay = 18;
    };

    sizes = {
      barHeight = 28;
      barLogo = 20;
      trayIcon = 16;
      privacyIcon = 12;
      lockIndicatorRadius = 100;
      lockIndicatorThickness = 4;
    };
  };
}
