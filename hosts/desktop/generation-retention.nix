{ pkgs, ... }:

let
  trimNixGenerations = import ../../lib/trim-nix-generations.nix { inherit pkgs; };
in

{
  boot.loader.grub.configurationLimit = 5;

  system.activationScripts.trimNixGenerations.text = ''
    ${trimNixGenerations}/bin/trim-nix-generations \
      /nix/var/nix/profiles/system
  '';
}
