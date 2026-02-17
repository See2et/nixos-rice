{ ... }:

{
  imports = [
    ./system.nix
    ./boot.nix
    ./filesystems.nix
    ./nixos-repo-permissions.nix
    ./gdm.nix
    ./niri.nix
    ./nvidia.nix
    ./audio.nix
    ./vr.nix
    ./firewall.nix
  ];
}
