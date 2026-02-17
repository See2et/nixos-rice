{ lib, ... }:
let
  logoIcon = ./assets/waybar-logo.jpg;
in
{
  imports = [
    ./niri.nix
    ./waybar.nix
    ./packages.nix
    ./alvr.nix
    ./zen-browser.nix
    ./xdg.nix
  ];

  options.programs.niri.enable = lib.mkEnableOption "niri";

  config = {
    programs.niri.enable = true;
    services.swaync.enable = true;

    programs.alacritty = {
      enable = true;
      settings = {
        window.opacity = 0.9;
        colors.transparent_background_colors = true;
        colors.draw_bold_text_with_bright_colors = false;
        colors.primary.foreground = "#bac2de";
        colors.primary.bright_foreground = "#bac2de";
        colors.normal.white = "#aeb7d6";
        colors.bright.white = "#9aa4c6";
      };
    };

    programs.waybar.style = lib.mkForce ''
      @import "catppuccin.css";
      @define-color accent @rosewater;

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
        color: @text;
        background: alpha(@base, 0.9999999);
        border-radius: 1em;
        font-family: "FiraCode Nerd Font", "Noto Sans CJK JP", "Noto Sans CJK SC", "Noto Color Emoji", sans-serif;
        font-size: 13px;
        font-style: normal;
        min-height: 0;
      }

      #workspaces,
      .modules-right box {
        background-color: @surface0;
        margin: 0 0.25em;
        padding: 0.15em 0.25em;
        border-radius: 1em;
      }

      .modules-right label.module {
        margin: 0 0.5em;
      }

      .modules-left #image {
        margin: 0 0.5em;
      }

      .modules-right box {
        padding: 0.15em 0.4em;
      }

      .modules-left,
      .modules-right {
        margin: 0.4em 0.5em;
      }

      #workspaces {
        background-color: @surface0;
        padding: 0;
      }

      #workspaces button {
        background-color: transparent;
        color: @text;
        padding: 0 0.4em;
        transition: none;
      }

      #workspaces button:nth-child(1) {
        border-top-left-radius: 1em;
        border-bottom-left-radius: 1em;
      }

      #workspaces button:nth-last-child(1) {
        border-top-right-radius: 1em;
        border-bottom-right-radius: 1em;
      }

      #workspaces button.empty {
        color: @overlay0;
      }

      #workspaces button.visible {
        background: @surface1;
      }

      #workspaces button.focused {
        box-shadow: none;
      }

      #workspaces button.active {
        background: @accent;
        color: @surface0;
      }

      #workspaces button:hover {
        background: rgba(255, 255, 255, 0.1);
        color: @text;
        box-shadow: none;
      }

      #workspaces button.active:hover {
        background: @accent;
        color: @surface0;
      }

      #workspaces button.urgent {
        background: @red;
        color: @surface0;
      }

      #window {
        background: transparent;
      }

      window#waybar.floating #window {
        color: @pink;
      }

      #clock {
        color: @lavender;
      }

      #power-profiles-daemon {
        color: @teal;
      }

      #battery {
        color: @green;
      }

      #battery.charging {
        color: @green;
      }

      #battery.warning:not(.charging) {
        color: @peach;
      }

      #battery.critical:not(.charging) {
        color: @maroon;
      }

      #backlight {
        color: @yellow;
      }

      #pulseaudio {
        color: @pink;
      }

      #custom-notifications {
        margin: 0;
        min-width: 1.8em;
        font-family: "FiraCode Nerd Font", "Symbols Nerd Font Mono", "Noto Color Emoji", sans-serif;
      }

      #custom-notifications.none,
      #custom-notifications.inhibited-none {
        color: @text;
      }

      #custom-notifications.notification,
      #custom-notifications.inhibited-notification {
        color: @yellow;
      }

      #custom-notifications.dnd-none,
      #custom-notifications.dnd-inhibited-none {
        color: @overlay1;
      }

      #custom-notifications.dnd-notification,
      #custom-notifications.dnd-inhibited-notification {
        color: @peach;
      }

      #custom-power {
        color: @red;
      }

      #privacy {
        margin: 0 0.25em;
        padding: 0;
      }

      #privacy-item {
        padding: 0 1px;
        color: @text;
      }

      tooltip {
        background: @base;
        border: 1px solid @surface2;
      }

      tooltip * {
        padding: 0;
        margin: 0;
        color: @text;
        font-family: "FiraCode Nerd Font", "Noto Sans CJK JP", "Noto Sans CJK SC", monospace;
      }
    '';

    programs.waybar.settings = lib.mkForce [
      {
        layer = "top";
        position = "bottom";
        height = 28;
        "margin-top" = 6;
        "margin-left" = 6;
        "margin-right" = 6;
        "margin-bottom" = 6;

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
            "privacy"
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
          size = 20;
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
          "icon-size" = 16;
          spacing = 4;
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
              months = "<span color='#ffead3'><b>{}</b></span>";
              days = "<span color='#ecc6d9'><b>{}</b></span>";
              weeks = "<span color='#99ffdd'><b>W{}</b></span>";
              weekdays = "<span color='#ffcc66'><b>{}</b></span>";
              today = "<span color='#ff6699'><b><u>{}</u></b></span>";
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
          "icon-size" = 12;
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
          "on-click" = "sh -c '(sleep 0.5s; swaylock --grace 0)' & disown";
          format = "";
        };

        "custom/power" = {
          tooltip = true;
          "tooltip-format" = "Power menu";
          "on-click" = "wlogout &";
          format = "⏻";
        };
      }
    ];
  };
}
