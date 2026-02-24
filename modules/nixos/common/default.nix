# Shared NixOS Module Baseline
#
# Platform-neutral settings shared by all NixOS hosts (desktop, wsl).
# GUARDRAIL: This file must NOT contain boot.loader, hardware.nvidia,
# services.displayManager, wsl.*, or any platform-specific options.

{ lib, ... }:

{
  imports = [
    ./nixos-repo-permissions.nix
  ];

  # --- Nix daemon settings ---
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # --- Nixpkgs ---
  nixpkgs.config.allowUnfree = true;

  # --- Shell ---
  programs.zsh.enable = true;

  # --- Locale (Japanese primary, English fallback) ---
  i18n.defaultLocale = lib.mkForce "ja_JP.UTF-8";
  i18n.supportedLocales = [
    "ja_JP.UTF-8/UTF-8"
    "en_US.UTF-8/UTF-8"
  ];
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "ja_JP.UTF-8";
    LC_IDENTIFICATION = "ja_JP.UTF-8";
    LC_MEASUREMENT = "ja_JP.UTF-8";
    LC_MONETARY = "ja_JP.UTF-8";
    LC_NAME = "ja_JP.UTF-8";
    LC_NUMERIC = "ja_JP.UTF-8";
    LC_PAPER = "ja_JP.UTF-8";
    LC_TELEPHONE = "ja_JP.UTF-8";
    LC_TIME = "ja_JP.UTF-8";
  };

  environment.sessionVariables = {
    LANGUAGE = "ja_JP:en_US";
  };

  # --- GPG agent (platform-neutral) ---
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };
}
