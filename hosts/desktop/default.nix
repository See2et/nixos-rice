# Desktop Host Configuration
# This module is desktop-specific and should only be imported in the desktop host configuration.
# It imports the desktop configuration, niri, nixpkgs-xr, and home-manager module chain.
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
    # Desktop-only system domains (boot/display/gpu/audio/vr/firewall)
    ../../modules/nixos/desktop
    # Include the results of the hardware scan.
    ../../hardware-configuration.nix
    # Desktop-specific modules
    inputs.niri.nixosModules.niri
    inputs.nixpkgs-xr.nixosModules.nixpkgs-xr
    # Home Manager integration
    inputs.home-manager.nixosModules.home-manager
  ];

  # Home Manager configuration
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.backupFileExtension = "hm-backup";
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
    hostId = "desktop";
    rustToolchain = pkgs.rustc;
  };
}
