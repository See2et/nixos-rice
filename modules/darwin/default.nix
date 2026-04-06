# Shared Darwin module entrypoint

{ ... }:

{
  imports = [
    ./system.nix
    ./homebrew.nix
  ];
}
