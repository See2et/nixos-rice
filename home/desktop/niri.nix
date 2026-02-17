{ pkgs, lib, config, ... }:
{
  config = lib.mkIf config.programs.niri.enable {
    programs.niri.settings = {
      binds = {
        "Mod+Return".action.spawn = "alacritty";
        "Ctrl+Space".action.spawn = "rofi-launcher";
        "Mod+V".action.spawn = "cliphist-picker";
        "Mod+Shift+Space".action.show-hotkey-overlay = { };

        "Mod+Q".action.close-window = { };

        "Mod+H".action.focus-column-left = [ ];
        "Mod+J".action.focus-window-down = [ ];
        "Mod+K".action.focus-window-up = [ ];
        "Mod+L".action.focus-column-right = [ ];
        "Mod+U".action.focus-workspace-down = [ ];
        "Mod+I".action.focus-workspace-up = [ ];

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

      spawn-at-startup = [
        # { command = [ "mako" ]; }
        { command = [ "wayber" ]; }
        { command = [ "swaybg -i /etc/nixos/tori.webp -m fill" ]; }
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
