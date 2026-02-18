{
  pkgs,
  lib,
  config,
  ...
}:
let
  wallpaperPath = "${config.xdg.dataHome}/wallpapers/tori.webp";
in
{
  config = lib.mkIf config.programs.niri.enable {
    programs.niri.settings = {
      prefer-no-csd = true;

      binds = {
        "Mod+Return".action.spawn = "alacritty-cwd";
        "Mod+Shift+Return".action.spawn = "zen-beta";
        "Ctrl+Space".action.spawn = "rofi-launcher";
        "Mod+S".action.spawn = "screenshot-picker";
        "Mod+V".action.spawn = "cliphist-picker";
        "Mod+Alt+L".action.spawn = [ "swaylock" "-f" ];
        "Mod+Shift+Space".action.show-hotkey-overlay = { };
        "Mod+Shift+Slash".action.show-hotkey-overlay = { };

        "Mod+Q".action.close-window = { };

        "Mod+H".action.focus-column-left = [ ];
        "Mod+J".action.focus-window-down = [ ];
        "Mod+K".action.focus-window-up = [ ];
        "Mod+Ctrl+J".action.focus-window-down-or-top = [ ];
        "Mod+Ctrl+K".action.focus-window-up-or-bottom = [ ];
        "Mod+L".action.focus-column-right = [ ];
        "Mod+U".action.focus-workspace-down = [ ];
        "Mod+I".action.focus-workspace-up = [ ];

        "Mod+Comma".action.consume-window-into-column = [ ];
        "Mod+Period".action.expel-window-from-column = [ ];

        "Mod+Shift+H".action.move-column-left = [ ];
        "Mod+Shift+J".action.move-window-down = [ ];
        "Mod+Shift+K".action.move-window-up = [ ];
        "Mod+Shift+L".action.move-column-right = [ ];
        "Mod+Shift+U".action.move-column-to-workspace-down = [ ];
        "Mod+Shift+I".action.move-column-to-workspace-up = [ ];

        "Mod+O".action.toggle-overview = [ ];

        "Mod+C".action.center-column = [ ];
        "Mod+Ctrl+C".action.center-visible-columns = [ ];

        "Mod+T".action.toggle-window-floating = [ ];
        "Mod+F".action.fullscreen-window = [ ];
        "Mod+M".action.maximize-column = [ ];
        "Mod+W".action.toggle-column-tabbed-display = [ ];

        "Mod+BracketLeft".action.set-column-width = "-10%";
        "Mod+BracketRight".action.set-column-width = "+10%";
        "Mod+Shift+BracketLeft".action.set-window-height = "-10%";
        "Mod+Shift+BracketRight".action.set-window-height = "+10%";

        "Mod+Ctrl+WheelScrollDown".action.set-window-height = "-5%";
        "Mod+Ctrl+WheelScrollUp".action.set-window-height = "+5%";
      };

      layer-rules = [
        {
          matches = [
            { namespace = "^wallpaper$"; }
          ];
          place-within-backdrop = true;
        }
      ];

      window-rules = [
        {
          geometry-corner-radius = {
            top-left = 10.0;
            top-right = 10.0;
            bottom-right = 10.0;
            bottom-left = 10.0;
          };
          clip-to-geometry = true;
        }
        {
          matches = [
            { "app-id" = "^Alacritty$"; }
          ];
          draw-border-with-background = false;
        }
      ];

      layout = {
        gaps = 10;
        background-color = "transparent";
        focus-ring = {
          width = 3.0;
          active.color = "#7fc8ff80";
          inactive.color = "#5fa7d180";
          urgent.color = "#9ad9ff80";
        };
      };

      spawn-at-startup = [
        # { command = [ "mako" ]; }
        {
          command = [
            "${pkgs.swaybg}/bin/swaybg"
            "-i"
            wallpaperPath
            "-m"
            "fill"
          ];
        }
        { command = [ "xwayland-satellite" ]; }
      ];
    };

    systemd.user.services.cliphist-store-text = {
      Unit = {
        Description = "Store clipboard text history";
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --type text --watch ${pkgs.cliphist}/bin/cliphist store";
        Type = "simple";
        Restart = "on-failure";
        RestartSec = 2;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    systemd.user.services.cliphist-store-image = {
      Unit = {
        Description = "Store clipboard image history";
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --type image --watch ${pkgs.cliphist}/bin/cliphist store";
        Type = "simple";
        Restart = "on-failure";
        RestartSec = 2;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
