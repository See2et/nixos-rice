# Shared Darwin module entrypoint

{ ... }:

{
  imports = [
    ./codex.nix
    ./system.nix
    ./homebrew.nix
  ];
}
