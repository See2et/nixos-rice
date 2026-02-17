# Desktop Host Configuration
# This module is desktop-specific and should only be imported in the desktop host configuration.
# It imports the desktop configuration, niri, nixpkgs-xr, and home-manager module chain.

{ inputs, ... }:

{
  imports = [
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
  home-manager.users.see2et = import ../../home.nix;
  home-manager.extraSpecialArgs = { inherit inputs; };
}
