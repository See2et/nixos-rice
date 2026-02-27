{ lib, ... }:
{
  imports = [
    ./niri.nix
    ./session-startup.nix
    ./wallpaper.nix
    ./idle.nix
    ./waybar.nix
    ./rofi.nix
    ./ui-tokens.nix
    ./surfaces.nix
    ./packages.nix
    ./lazydocker.nix
    ./obs.nix
    ./alvr.nix
    ./zen-browser.nix
    ./xdg.nix
    ./theme.nix
  ];

  options.programs.niri.enable = lib.mkEnableOption "niri";

  config = {
    programs.niri.enable = true;

    programs.alacritty = {
      enable = true;
      settings = {
        font = {
          normal.family = "FiraCode Nerd Font";
          bold.family = "FiraCode Nerd Font";
          italic.family = "FiraCode Nerd Font";
          bold_italic.family = "FiraCode Nerd Font";
        };
        window.opacity = 0.9;
        colors.transparent_background_colors = true;
        colors.draw_bold_text_with_bright_colors = false;
        colors.primary.foreground = "#bac2de";
        colors.primary.bright_foreground = "#bac2de";
        colors.normal.white = "#aeb7d6";
        colors.bright.white = "#9aa4c6";
      };
    };

  };
}
