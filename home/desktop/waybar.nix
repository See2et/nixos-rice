{ config, ... }:
let
  logoIcon = ./assets/waybar-logo.png;
  t = config.desktop.ui.tokens;
in
{
  programs.waybar = {
    enable = true;
    systemd.enable = true;
    style = ''
      * {
        border: none;
        border-radius: 0;
        min-height: 0;
      }

      button,
      button:hover {
        box-shadow: none;
      }

      window#waybar {
        color: ${t.colors.foreground};
        background-color: transparent;
        font-family: ${t.typography.family};
        font-size: ${toString t.typography.size.md}px;
        font-style: normal;
        min-height: 0;
      }

      window#waybar > box {
        background-color: ${t.colors.background};
        border: 1px solid ${t.colors.border};
        border-radius: ${toString t.radii.lg}px;
      }

      #workspaces,
      .modules-right box {
        background-color: ${t.colors.surface};
        margin: 0 ${toString t.spacing.sm}px;
        padding: ${toString t.spacing.xs}px ${toString t.spacing.sm}px;
        border-radius: ${toString t.radii.lg}px;
      }

      .modules-right label.module {
        margin: 0 ${toString t.spacing.lg}px;
      }

      .modules-left #image {
        margin: 0 ${toString t.spacing.lg}px;
      }

      .modules-right box {
        padding: ${toString t.spacing.xs}px ${toString t.spacing.md}px;
      }

      .modules-left,
      .modules-right {
        margin: ${toString t.spacing.md}px ${toString t.spacing.lg}px;
      }

      #workspaces {
        background-color: ${t.colors.surface};
        padding: 0;
      }

      #workspaces button {
        background-color: transparent;
        color: ${t.colors.foreground};
        padding: 0 ${toString t.spacing.md}px;
        transition: none;
      }

      #workspaces button:nth-child(1) {
        border-top-left-radius: ${toString t.radii.lg}px;
        border-bottom-left-radius: ${toString t.radii.lg}px;
      }

      #workspaces button:nth-last-child(1) {
        border-top-right-radius: ${toString t.radii.lg}px;
        border-bottom-right-radius: ${toString t.radii.lg}px;
      }

      #workspaces button.empty {
        color: ${t.colors.muted};
      }

      #workspaces button.visible {
        background: ${t.colors.surfaceElevated};
      }

      #workspaces button.focused {
        box-shadow: none;
      }

      #workspaces button.active {
        background: ${t.colors.accent};
        color: ${t.colors.background};
      }

      #workspaces button:hover {
        background: ${t.colors.surfaceElevated};
        color: ${t.colors.foreground};
        box-shadow: none;
      }

      #workspaces button.active:hover {
        background: ${t.colors.accent};
        color: ${t.colors.background};
      }

      #workspaces button.urgent {
        background: ${t.colors.danger};
        color: ${t.colors.background};
      }

      #window {
        background: transparent;
      }

      window#waybar.floating #window {
        color: ${t.colors.accent};
      }

      #clock {
        color: ${t.colors.lavender};
      }

      #power-profiles-daemon {
        color: ${t.colors.info};
      }

      #battery {
        color: ${t.colors.success};
      }

      #battery.charging {
        color: ${t.colors.success};
      }

      #battery.warning:not(.charging) {
        color: ${t.colors.warning};
      }

      #battery.critical:not(.charging) {
        color: ${t.colors.danger};
      }

      #backlight {
        color: ${t.colors.warning};
      }

      #pulseaudio {
        color: ${t.colors.accent};
      }

      #custom-notifications {
        margin: 0;
        min-width: 1.8em;
        font-family: ${t.typography.iconFamily};
      }

      #custom-notifications.none,
      #custom-notifications.inhibited-none {
        color: ${t.colors.foreground};
      }

      #custom-notifications.notification,
      #custom-notifications.inhibited-notification {
        color: ${t.colors.warning};
      }

      #custom-notifications.dnd-none,
      #custom-notifications.dnd-inhibited-none {
        color: ${t.colors.muted};
      }

      #custom-notifications.dnd-notification,
      #custom-notifications.dnd-inhibited-notification {
        color: ${t.colors.warning};
      }

      #custom-power {
        color: ${t.colors.danger};
      }

      #privacy {
        margin: 0 ${toString t.spacing.sm}px;
        padding: 0;
      }

      #privacy-item {
        padding: 0 1px;
        color: ${t.colors.foreground};
      }

      tooltip {
        background: ${t.colors.background};
        border: 1px solid ${t.colors.border};
        border-radius: ${toString t.radii.sm}px;
      }

      tooltip * {
        padding: 0;
        margin: 0;
        color: ${t.colors.foreground};
        font-family: ${t.typography.monoFamily};
      }
    '';
    settings = [
      {
        layer = "top";
        position = "bottom";
        height = t.sizes.barHeight;
        "margin-top" = t.spacing.md;
        "margin-left" = t.spacing.md;
        "margin-right" = t.spacing.md;
        "margin-bottom" = t.spacing.md;

        "modules-left" = [
          "image#logo"
          "niri/workspaces"
          "niri/window"
        ];
        "modules-center" = [ "clock" ];
        "modules-right" = [
          "group/playback"
          "group/status"
          "group/notifications"
          "tray"
          "group/power"
        ];

        "group/playback" = {
          orientation = "inherit";
          modules = [ "custom/music" ];
        };

        "group/status" = {
          orientation = "inherit";
          modules = [
            "pulseaudio"
            "backlight"
            "battery"
            "power-profiles-daemon"
          ];
        };

        "group/power" = {
          orientation = "inherit";
          modules = [
            "custom/lock"
            "custom/power"
          ];
        };

        "group/notifications" = {
          orientation = "inherit";
          modules = [ "custom/notifications" ];
        };

        "image#logo" = {
          path = logoIcon;
          size = t.sizes.barLogo;
          tooltip = false;
          interval = 0;
        };

        "niri/workspaces" = {
          format = "{icon}";
          "format-icons" = {
            active = "";
            focused = "";
            empty = "";
            default = "";
          };
        };

        "niri/window" = {
          format = "{}";
          icon = true;
          "icon-size" = 16;
          rewrite = {
            "(.*) - Vivaldi" = "$1";
            "(.*) - Visual Studio Code" = "$1";
            "(\\S+\\.js\\s.*)" = " $1";
            "(\\S+\\.ts\\s.*)" = " $1";
            "(\\S+\\.go\\s.*)" = " $1";
            "(\\S+\\.lua\\s.*)" = " $1";
            "(\\S+\\.java\\s.*)" = " $1";
            "(\\S+\\.rb\\s.*)" = " $1";
            "(\\S+\\.php\\s.*)" = " $1";
            "(\\S+\\.jsonc?\\s.*)" = " $1";
            "(\\S+\\.md\\s.*)" = " $1";
            "(\\S+\\.txt\\s.*)" = " $1";
            "(\\S+\\.cs\\s.*)" = " $1";
            "(\\S+\\.c\\s.*)" = " $1";
            "(\\S+\\.cpp\\s.*)" = " $1";
            "(\\S+\\.hs\\s.*)" = " $1";
            ".*Discord | (.*) | .*" = "$1 - ArmCord";
          };
          "separate-outputs" = true;
        };

        tray = {
          "icon-size" = t.sizes.trayIcon;
          spacing = t.spacing.sm;
        };

        "custom/notifications" = {
          "return-type" = "json";
          exec = "swaync-client -swb";
          format = "{icon}";
          "format-icons" = {
            notification = " ";
            none = "";
            "dnd-notification" = " ";
            "dnd-none" = "";
            "inhibited-notification" = " ";
            "inhibited-none" = "";
            "dnd-inhibited-notification" = " ";
            "dnd-inhibited-none" = "";
          };
          tooltip = true;
          escape = true;
          "on-click" = "swaync-client -t -sw";
          "on-click-right" = "swaync-client -d -sw";
        };

        "custom/music" = {
          format = "♫ {}";
          escape = true;
          interval = 5;
          tooltip = false;
          exec = "playerctl metadata --format='{{ title }}'";
          "on-click" = "playerctl play-pause";
          "max-length" = 50;
        };

        clock = {
          timezone = "Asia/Tokyo";
          format = "{:%H:%M}";
          "format-alt" = "{:%a %b %d %R}";
          "tooltip-format" = "<tt><small>{calendar}</small></tt>";
          calendar = {
            mode = "year";
            "mode-mon-col" = 3;
            "weeks-pos" = "right";
            "on-scroll" = 1;
            "on-click-right" = "mode";
            format = {
              months = "<span color='${t.colors.foreground}'><b>{}</b></span>";
              days = "<span color='${t.colors.accent}'><b>{}</b></span>";
              weeks = "<span color='${t.colors.info}'><b>W{}</b></span>";
              weekdays = "<span color='${t.colors.warning}'><b>{}</b></span>";
              today = "<span color='${t.colors.danger}'><b><u>{}</u></b></span>";
            };
            actions = {
              "on-click-right" = "mode";
              "on-click-forward" = "tz_up";
              "on-click-backward" = "tz_down";
              "on-scroll-up" = "shift_up";
              "on-scroll-down" = "shift_down";
            };
          };
        };

        backlight = {
          device = "intel_backlight";
          format = "{icon} {percent}%";
          "format-icons" = [
            ""
            ""
          ];
          "scroll-step" = 1;
        };

        battery = {
          interval = 30;
          states = {
            warning = 20;
            critical = 10;
          };
          "full-at" = 98;
          format = "{icon} {capacity}%";
          "format-icons" = [
            ""
            ""
            ""
            ""
            ""
          ];
          "format-critical" = " {capacity}%";
          "tooltip-format" = "{timeTo} ({power}W)";
          "format-charging" = " {capacity}%";
        };

        pulseaudio = {
          format = "{icon} {volume}%";
          "format-bluetooth" = "{icon} {volume}%";
          "format-muted" = " {volume}%";
          "format-icons" = {
            headphone = "";
            "hands-free" = "";
            headset = "";
            phone = "";
            portable = "";
            car = "";
            default = [
              ""
              ""
              ""
            ];
          };
          "scroll-step" = 1;
          "on-click" = "pavucontrol";
          "ignored-sinks" = [ "Easy Effects Sink" ];
        };

        privacy = {
          "icon-spacing" = 0;
          "icon-size" = t.sizes.privacyIcon;
          "transition-duration" = 250;
          modules = [
            { type = "screenshare"; }
            { type = "audio-in"; }
          ];
        };

        "power-profiles-daemon" = {
          format = "{icon}";
          tooltip = true;
          "tooltip-format" = "Power profile: {profile}\nDriver: {driver}";
          "format-icons" = {
            default = "";
            performance = " perf";
            balanced = " balance";
            "power-saver" = " save";
          };
        };

        "custom/lock" = {
          tooltip = false;
          "on-click" = "desktop-lock";
          format = "";
        };

        "custom/power" = {
          tooltip = true;
          "tooltip-format" = "Power menu";
          "on-click" = "desktop-power-menu";
          format = "⏻";
        };
      }
    ];
  };

  catppuccin.waybar.enable = false;
}
