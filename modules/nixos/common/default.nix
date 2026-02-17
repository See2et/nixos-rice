# Shared NixOS Module Baseline
#
# Platform-neutral settings shared by all NixOS hosts (desktop, wsl).
# GUARDRAIL: This file must NOT contain boot.loader, hardware.nvidia,
# services.displayManager, wsl.*, or any platform-specific options.

{ pkgs, ... }:

{
  # --- Nix daemon settings ---
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # --- Nixpkgs ---
  nixpkgs.config.allowUnfree = true;

  # --- Shell ---
  programs.zsh.enable = true;

  # --- GPG agent (platform-neutral) ---
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };
}
