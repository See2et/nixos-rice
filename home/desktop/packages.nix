{ pkgs, inputs, ... }:
let
  pkgsUnstable = import inputs.nixpkgs-unstable {
    inherit (pkgs.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };

  rofiLauncher = pkgs.writeShellScriptBin "rofi-launcher" ''
    exec ${pkgs.rofi}/bin/rofi -show drun
  '';

  cliphistPicker = pkgs.writeShellScriptBin "cliphist-picker" ''
    sleep 0.12
    selection="$(${pkgs.cliphist}/bin/cliphist list | ${pkgs.rofi}/bin/rofi -dmenu -no-custom -i -p "Clipboard")"
    rofiStatus=$?
    [ "$rofiStatus" -eq 0 ] || exit 0
    [ -n "$selection" ] || exit 0
    itemId="''${selection%%$'\t'*}"
    [[ "$itemId" =~ ^[0-9]+$ ]] || exit 0
    ${pkgs.cliphist}/bin/cliphist decode <<<"$selection" | ${pkgs.wl-clipboard}/bin/wl-copy || exit 0
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
    wlogout
    swaylock
    pavucontrol
    pulseaudio
    brightnessctl
    gcolor3
    pkgsUnstable.godot_4_6
    discord
    youtube-music
    alvr
    vrcx
    sidequest
    wlx-overlay-s
    rofiLauncher
    cliphistPicker
  ];
}
