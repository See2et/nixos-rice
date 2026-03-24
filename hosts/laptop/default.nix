# Laptop Host Configuration
# This module is laptop-specific and should only be imported in the laptop host configuration.
# It mirrors the desktop host and only swaps the hardware scan module.
#
# GUARDRAILS:
# - MUST NOT import modules/nixos/wsl, home/wsl, or nixos-wsl
# - MUST NOT set wsl.* options
# - MUST NOT reintroduce a root-level home.nix monolith

{ inputs, pkgs, ... }:

{
  imports = [
    # Shared baseline (nix.settings, shell, gpg)
    ../../modules/nixos/common
    # Desktop-class system domains (imported explicitly so laptop can skip nvidia)
    ../../modules/nixos/desktop/system.nix
    ../../modules/nixos/desktop/unity-runtime.nix
    ../../modules/nixos/desktop/boot.nix
    ../../modules/nixos/desktop/filesystems.nix
    ../../modules/nixos/desktop/gdm.nix
    ../../modules/nixos/desktop/niri.nix
    ../../modules/nixos/desktop/audio.nix
    ../../modules/nixos/desktop/vr.nix
    ../../modules/nixos/desktop/firewall.nix
    ../../modules/nixos/desktop/docker.nix
    # Laptop-specific hardware scan module
    ../../hardware-configuration-laptop.nix
    # Desktop-class modules
    inputs.niri.nixosModules.niri
    inputs.nixpkgs-xr.nixosModules.nixpkgs-xr
    # Home Manager integration
    inputs.home-manager.nixosModules.home-manager
  ];

  # Home Manager configuration
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.backupFileExtension = "hm-backup";
  home-manager.overwriteBackup = true;
  home-manager.users.see2et = {
    imports = [
      ../../home/common
      ../../home/linux
      ../../home/desktop
    ];
    home.username = "see2et";
    home.homeDirectory = "/home/see2et";
    home.stateVersion = "25.11";
    programs.home-manager.enable = true;
  };
  home-manager.extraSpecialArgs = {
    inherit inputs;
    isDarwin = false;
    hostId = "laptop";
    rustToolchain = pkgs.rustc;
  };
}
