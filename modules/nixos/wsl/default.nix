# WSL-Only NixOS Module
#
# Settings that apply exclusively to the WSL host.
# GUARDRAIL: This file must NOT be imported by desktop or common modules.
# Includes: nix-ld, allowUnsupportedSystem, usbip.

{ pkgs, ... }:

{
  # --- nix-ld (dynamic linking for unpatched binaries) ---
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc
    zlib
    openssl
    icu
    krb5
    wget
  ];

  # --- Allow unsupported system packages ---
  nixpkgs.config.allowUnsupportedSystem = true;

  # --- WSL USB/IP passthrough ---
  wsl.usbip.enable = true;
}
