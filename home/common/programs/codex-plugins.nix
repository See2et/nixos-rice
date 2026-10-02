{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  codex = inputs.codex-cli-nix.packages.${pkgs.stdenv.hostPlatform.system}.codex;
  marketplaces = lib.mapAttrsToList (
    name: spec:
    let
      sourceId = spec.source.rev or (builtins.hashString "sha256" spec.source.outPath);
      selection = pkgs.writeText "codex-plugins-${name}.json" (builtins.toJSON spec.plugins);
      root = pkgs.runCommand "codex-marketplace-${name}" { nativeBuildInputs = [ pkgs.python3 ]; } ''
        python3 ${./codex-plugins/materialize.py} \
          ${lib.escapeShellArg spec.source.outPath} "$out" \
          ${lib.escapeShellArg name} ${lib.escapeShellArg sourceId} ${selection}
      '';
    in
    {
      inherit name root;
    }
  ) inputs.codex-plugins.marketplaces;
  manifest = pkgs.writeText "codex-managed-marketplaces.json" (builtins.toJSON marketplaces);
  activation = pkgs.writeShellApplication {
    name = "codex-nix-plugins-activate";
    runtimeInputs = [
      codex
      pkgs.python3
    ];
    text = ''
      exec python3 ${./codex-plugins/activate.py} \
        --manifest ${manifest} --codex-home ${lib.escapeShellArg "${config.home.homeDirectory}/.codex"}
    '';
  };
in
{
  # Keep sources GC-rooted in the Home Manager generation; runtime caches stay writable.
  home.file = builtins.listToAttrs (
    map (market: {
      name = ".local/share/codex-nix-marketplaces/${market.name}";
      value.source = market.root;
    }) marketplaces
  );

  # `run` honors Home Manager dry-run; the NixOS HM service executes as the user.
  home.activation.codexPlugins = lib.hm.dag.entryAfter [ "writeBoundary" "installPackages" ] ''
    run ${activation}/bin/codex-nix-plugins-activate
  '';
}
