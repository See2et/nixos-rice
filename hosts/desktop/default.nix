# Desktop Host Configuration
# This module is desktop-specific and should only be imported in the desktop host configuration.
# It imports the desktop configuration, niri, nixpkgs-xr, and home-manager module chain.

{ inputs, pkgs, ... }:

{
  imports = [
    # Shared baseline (nix.settings, shell, gpg)
    ../../modules/nixos/common
    # Desktop-only system domains (boot/display/gpu/audio/vr/firewall)
    ../../modules/nixos/desktop
    # Include the results of the hardware scan.
    ../../hardware-configuration.nix
    # Desktop configuration
    ../../configuration.nix
    # Desktop-specific modules
    inputs.niri.nixosModules.niri
    inputs.nixpkgs-xr.nixosModules.nixpkgs-xr
    # Home Manager integration
    inputs.home-manager.nixosModules.home-manager
  ];

  # Home Manager configuration
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.see2et = {
    imports = [
      ../../home/common
      ../../home/linux
      ../../home/desktop
      ../../home.nix
    ];
  };
  home-manager.extraSpecialArgs = {
    inherit inputs;
    isDarwin = false;
    rustToolchain = pkgs.rustc;
  };
}
