# Laptop Host Configuration
# This module is laptop-specific and should only be imported in the laptop host configuration.
# It mirrors the desktop host and only swaps the hardware scan module.
#
# GUARDRAILS:
# - MUST NOT import modules/nixos/wsl, home/wsl, or nixos-wsl
# - MUST NOT set wsl.* options
# - MUST NOT reintroduce a root-level home.nix monolith

{ inputs, pkgs, lib, ... }:

{
  imports = [
    # Shared baseline (nix.settings, shell, gpg)
    ../../modules/nixos/common
    # Desktop-class system domains (imported explicitly so laptop can skip nvidia)
    ../../modules/nixos/desktop/system.nix
    ../../modules/nixos/desktop/unity-runtime.nix
    ../../modules/nixos/desktop/bluetooth.nix
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

  services.openssh = {
    enable = true;
    openFirewall = true;
  };

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

  # Fallback safety when hardware-configuration-laptop.nix is not yet regenerated on Asahi.
  # Prevent x86_64 desktop remnants (AMD/NVIDIA) from being pulled into aarch64 evaluation.
  hardware.cpu.amd.updateMicrocode = lib.mkForce false;
  hardware.nvidia.modesetting.enable = lib.mkForce false;

  # Asahi laptop boot flow is not desktop GRUB-on-/boot/efi.
  # Keep desktop defaults for desktop host, but override on laptop.
  boot.loader.grub.enable = lib.mkForce false;
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.generic-extlinux-compatible.enable = lib.mkForce true;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;
  boot.loader.efi.efiSysMountPoint = lib.mkForce "/boot";
}
