{ pkgs }:
pkgs.writeShellApplication {
  name = "update-pi-extensions";
  runtimeInputs = with pkgs; [
    nix
    git
    nodejs_24
    python3
    prefetch-npm-deps
  ];
  text = ''
    exec python3 ${./update.py} "$@"
  '';
  meta.description = "Update all or named Pi extensions safely from the checkout inventory";
}
