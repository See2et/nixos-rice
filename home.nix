{
  config,
  pkgs,
  inputs,
  ...
}:
{
  # imports = [ ~/.config/home-manager/flake.nix ];
  imports = [ inputs.catppuccin.homeModules.catppuccin ];
  home.stateVersion = "25.05";

  programs.niri.settings = {
    binds = {
      "Mod+Return".action.spawn = "alacritty";
      "Ctrl+Space".action.spawn = "fuzzel";
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

  home.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    SUDO_EDITOR = "nvim";
    VISUAL = "nvim";
    EDITOR = "nvim";
  };

  programs.waybar = {
    enable = true;
    systemd.enable = true;
    style = ''
      @import "catppuccin.css";

      * {
        font-family: FiraCode Nerd Font;
        font-size: 17px;
        min-height: 0;
      }

      #waybar {
        background: transparent;
        color: @text;
        margin: 5px 5px;
      }

      #workspaces {
        border-radius: 1rem;
        margin: 5px;
        background-color: @surface0;
        margin-left: 1rem;
      }

      #workspaces button {
        color: @lavender;
        border-radius: 1rem;
        padding: 0.4rem;
      }

      #workspaces button.active {
        color: @sky;
        border-radius: 1rem;
      }

      #workspaces button:hover {
        color: @sapphire;
        border-radius: 1rem;
      }

      #custom-music,
      #tray,
      #backlight,
      #clock,
      #battery,
      #pulseaudio,
      #custom-lock,
      #custom-power {
        background-color: @surface0;
        padding: 0.5rem 1rem;
        margin: 5px 0;
      }

      #clock {
        color: @blue;
        border-radius: 0px 1rem 1rem 0px;
        margin-right: 1rem;
      }

      #battery {
        color: @green;
      }

      #battery.charging {
        color: @green;
      }

      #battery.warning:not(.charging) {
        color: @red;
      }

      #backlight {
        color: @yellow;
      }

      #backlight, #battery {
          border-radius: 0;
      }

      #pulseaudio {
        color: @maroon;
        border-radius: 1rem 0px 0px 1rem;
        margin-left: 1rem;
      }

      #custom-music {
        color: @mauve;
        border-radius: 1rem;
      }

      #custom-lock {
          border-radius: 1rem 0px 0px 1rem;
          color: @lavender;
      }

      #custom-power {
          margin-right: 1rem;
          border-radius: 0px 1rem 1rem 0px;
          color: @red;
      }

      #tray {
        margin-right: 1rem;
        border-radius: 1rem;
      }
    '';
    settings = [
    {
      layer = "top";
      position = "top";

      "modules-left" = [ "niri/workspaces" ];
      "modules-center" = [ "custom/music" ];
      "modules-right" = [
        "pulseaudio"
        "backlight"
        "battery"
        "clock"
        "tray"
        "custom/lock"
        "custom/power"
      ];

      "niri/workspaces" = {
    "format" = "{icon}";                
    "format-icons" = {
      "active" = "";
      "focused" = "";
      "empty" = "";
      "default" = "";
    }; 
      };

      tray = {
        "icon-size" = 21;
        spacing = 10;
      };

      "custom/music" = {
        format = "  {}";
        escape = true;
        interval = 5;
        tooltip = false;
        exec = "playerctl metadata --format='{{ title }}'";
        "on-click" = "playerctl play-pause";
        "max-length" = 50;
      };

      clock = {
        timezone = "Asia/Tokyo";
        "tooltip-format" = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
        "format-alt" = " {:%d/%m/%Y}";
        format = " {:%H:%M}";
      };

      backlight = {
        device = "intel_backlight";
        format = "{icon}";
        "format-icons" = [ "" "" "" "" "" "" "" "" "" ];
      };

      battery = {
        states = {
          warning = 30;
          critical = 15;
        };
        format = "{icon}";
        "format-charging" = "";
        "format-plugged" = "";
        "format-alt" = "{icon}";
        "format-icons" = [ "" "" "" "" "" "" "" "" "" "" "" "" ];
      };

      pulseaudio = {
        format = "{icon} {volume}%";
        "format-muted" = "";
        "format-icons" = {
          default = [ "" "" " " ];
        };
        "on-click" = "pavucontrol";
      };

      "custom/lock" = {
        tooltip = false;
        "on-click" = "sh -c '(sleep 0.5s; swaylock --grace 0)' & disown";
        format = "";
      };

      "custom/power" = {
        tooltip = false;
        "on-click" = "wlogout &";
        format = "襤";
      };
    }
  ];
  };

  catppuccin = {
    enable = true;
    flavor = "mocha";
  };

  catppuccin.waybar = {
    enable = true;
    mode = "createLink";
  };

  programs.home-manager.enable = true;

  xdg.configFile = {
    "wlxoverlay/openxr_actions.json5".source = ./wayvr/openxr_actions.json5;
  };
  
  home.packages = with pkgs; [
    alacritty
    kitty
    wezterm
    fuzzel
    xwayland-satellite
    wl-clipboard
    home-manager

    waybar
    playerctl

    power-profiles-daemon
    jq
    vulnix
    pavucontrol
    pulseaudio
    brightnessctl
    btop
    gcolor3

    # for YubiKey
    linuxPackages.usbip
    libfido2
    pcsc-tools
    kmod
    usbutils
    yubikey-manager

    fcitx5-skk

    discord

    alvr
    vrcx
    sidequest
    wlx-overlay-s
  ];
}
