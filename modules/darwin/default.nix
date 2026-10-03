# Shared Darwin module entrypoint

{ ... }:

{
  imports = [
    ./codex.nix
    ./system.nix
    ./github-ssh.nix
    ./homebrew.nix
  ];
}
