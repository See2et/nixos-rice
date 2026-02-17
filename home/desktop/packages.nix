{ pkgs, ... }:
let
  rofiLauncher = pkgs.writeShellScriptBin "rofi-launcher" ''
    exec ${pkgs.rofi}/bin/rofi -show drun
  '';

  cliphistRofi = pkgs.writeShellScriptBin "cliphist-rofi" ''
    selection="$(${pkgs.cliphist}/bin/cliphist list | ${pkgs.rofi}/bin/rofi -dmenu -i -p "Clipboard")"
    [ -n "$selection" ] || exit 0
    printf '%s\n' "$selection" | ${pkgs.cliphist}/bin/cliphist decode | ${pkgs.wl-clipboard}/bin/wl-copy
  '';
in
{
  home.sessionVariables = {
    NIXOS_OZONE_WL = "1";
  };

  home.packages = with pkgs; [
    alacritty
    kitty
    wezterm
    rofi
    cliphist
    xwayland-satellite
    wl-clipboard
    waybar
    playerctl
    pavucontrol
    pulseaudio
    brightnessctl
    gcolor3
    discord
    alvr
    vrcx
    sidequest
    wlx-overlay-s
    rofiLauncher
    cliphistRofi
  ];
}
