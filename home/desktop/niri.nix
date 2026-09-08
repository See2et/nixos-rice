{
  config,
  lib,
  pkgs,
  ...
}:
let
  t = config.desktop.ui.tokens;
  pipWorkspaceFollower = pkgs.writeShellApplication {
    name = "niri-pip-workspace-follower";
    runtimeInputs = [
      config.programs.niri.package
      pkgs.jq
      pkgs.socat
    ];
    text = builtins.readFile ./niri-pip-workspace-follower;
  };
in
{
  config = lib.mkIf config.programs.niri.enable {
    home.packages = [ pipWorkspaceFollower ];

    systemd.user.services.niri-pip-workspace-follower = {
      Unit = {
        Description = "Keep browser picture-in-picture windows on the focused niri workspace";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = lib.getExe pipWorkspaceFollower;
        Restart = "always";
        RestartSec = 1;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    programs.niri.settings = {
      prefer-no-csd = true;

      binds = {
        "Mod+Return".action.spawn = "alacritty-cwd";
        "Mod+Shift+Return".action.spawn = "zen-twilight";
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
        "Mod+1".action.focus-workspace = 1;
        "Mod+2".action.focus-workspace = 2;
        "Mod+3".action.focus-workspace = 3;
        "Mod+4".action.focus-workspace = 4;
        "Mod+5".action.focus-workspace = 5;
        "Mod+6".action.focus-workspace = 6;
        "Mod+7".action.focus-workspace = 7;
        "Mod+8".action.focus-workspace = 8;
        "Mod+9".action.focus-workspace = 9;

        "Mod+Comma".action.consume-window-into-column = [ ];
        "Mod+Period".action.expel-window-from-column = [ ];

        "Mod+Shift+H".action.move-column-left = [ ];
        "Mod+Shift+J".action.move-window-down = [ ];
        "Mod+Shift+K".action.move-window-up = [ ];
        "Mod+Shift+L".action.move-column-right = [ ];
        "Mod+Shift+U".action.move-column-to-workspace-down = [ ];
        "Mod+Shift+I".action.move-column-to-workspace-up = [ ];

        "Mod+O".action.toggle-overview = [ ];
        "Mod+Tab".action.switch-focus-between-floating-and-tiling = [ ];

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
        {
          matches = [
            { namespace = "^dms:clipboard.*$"; }
          ];
          block-out-from = "screencast";
        }
      ];

      window-rules = [
        {
          geometry-corner-radius = {
            top-left = t.radii.lg * 1.0;
            top-right = t.radii.lg * 1.0;
            bottom-right = t.radii.lg * 1.0;
            bottom-left = t.radii.lg * 1.0;
          };
          clip-to-geometry = true;
        }
        {
          matches = [
            { "app-id" = "^(Alacritty|kitty|org\\.wezfurlong\\.wezterm)$"; }
          ];
          draw-border-with-background = false;
        }
        {
          matches = [
            { "app-id" = "^(org\\.pulseaudio\\.pavucontrol|pavucontrol|org\\.gnome\\.Calculator|gcolor3)$"; }
          ];
          open-floating = true;
        }
        {
          matches = [
            { title = "^(Picture-in-Picture|Picture in Picture|Picture in picture)$"; }
          ];
          open-floating = true;
        }
        {
          matches = [
            {
              "app-id" = "^(discord|discordcanary|Slack|slack|firefox|zen|zen-twilight)$";
              "is-active" = false;
            }
          ];
          opacity = 0.96;
        }
        {
          matches = [
            { "is-floating" = true; }
          ];
          opacity = 0.98;
        }
      ];

      layout = {
        gaps = 10;
        background-color = "transparent";
        focus-ring = {
          width = 3.0;
          active.color = "#00d4ff80";
          inactive.color = "#44495080";
          urgent.color = "#ffcc6680";
        };
      };

      overview = {
        "backdrop-color" = "transparent";
      };

      spawn-at-startup = [
        # { command = [ "mako" ]; }
      ];
    };
  };
}
