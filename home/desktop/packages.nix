{ pkgs, ... }:
{
  home.sessionVariables = {
    NIXOS_OZONE_WL = "1";
  };

  home.packages = with pkgs; [
    alacritty
    kitty
    wezterm
    fuzzel
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
  ];
}
