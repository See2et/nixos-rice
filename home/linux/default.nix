# Linux-specific Home Manager modules
# Settings common to all Linux targets (desktop + WSL) but not Darwin
# Packages that are Linux-only go here

{ pkgs, ... }:
{
  imports = [
    ./rebuild.nix
    ./session.nix
  ];

  home.packages = with pkgs; [
    wl-clipboard
    xclip
    libnotify
  ];
}
