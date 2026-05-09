# Darwin host wiring
# GUARDRAILS:
# - Host file should only wire modules and identity
# - Darwin-specific logic belongs in modules/darwin/

{ inputs, pkgs, darwinUser, ... }:

{
  imports = [
    ../../modules/darwin
    inputs.home-manager.darwinModules.home-manager
    inputs.nix-homebrew.darwinModules.nix-homebrew
  ];

  users.users.${darwinUser.name}.home = darwinUser.home;
  system.primaryUser = darwinUser.name;

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.backupFileExtension = "hm-backup";
  home-manager.overwriteBackup = true;
  home-manager.users.${darwinUser.name} = import ../../home/darwin/profile.nix;
  home-manager.extraSpecialArgs = {
    inherit inputs;
    inherit darwinUser;
    isDarwin = true;
    hostId = "darwin";
    rustToolchain = pkgs.rustc;
    opencodePackage = inputs.opencode.packages.${pkgs.stdenv.hostPlatform.system}.opencode;
  };

  system.stateVersion = 6;
}
