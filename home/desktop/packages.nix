{ pkgs, ... }:
let
  rofiLauncher = pkgs.writeShellScriptBin "rofi-launcher" ''
    exec ${pkgs.rofi}/bin/rofi -show drun
  '';

  cliphistPicker = pkgs.writeShellScriptBin "cliphist-picker" ''
    selection="$(${pkgs.cliphist}/bin/cliphist list | ${pkgs.rofi}/bin/rofi -dmenu -i -p "Clipboard")"
    [ -n "$selection" ] || exit 0
    ${pkgs.cliphist}/bin/cliphist decode <<<"$selection" | ${pkgs.wl-clipboard}/bin/wl-copy
    sleep 0.1
    ${pkgs.wtype}/bin/wtype -M ctrl v -m ctrl
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
    wtype
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
    cliphistPicker
  ];
}
