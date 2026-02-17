# Linux-specific Home Manager modules
# Settings common to all Linux targets (desktop + WSL) but not Darwin
# Packages that are Linux-only go here

{ config, pkgs, inputs, ... }:
{
  home.packages = with pkgs; [
    wl-clipboard
    xclip
    libnotify
  ];
}
