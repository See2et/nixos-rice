{
  config,
  lib,
  pkgs,
  ...
}:

let
  trimNixGenerations = import ../../lib/trim-nix-generations.nix { inherit pkgs; };
in

{
  home.activation.trimNixGenerations = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    profiles_dir="${config.xdg.stateHome}/nix/profiles"

    run ${trimNixGenerations}/bin/trim-nix-generations \
      "$profiles_dir/profile" \
      "$profiles_dir/home-manager"
  '';
}
