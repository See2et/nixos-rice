{ ... }:

{
  imports = [
    ./system.nix
    ./unity-runtime.nix
    ./boot.nix
    ./filesystems.nix
    ./gdm.nix
    ./niri.nix
    ./nvidia.nix
    ./audio.nix
    ./vr.nix
    ./firewall.nix
    ./docker.nix
  ];
}
