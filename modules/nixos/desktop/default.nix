{ ... }:

{
  imports = [
    ./system.nix
    ./steam.nix
    ./unity-runtime.nix
    ./bluetooth.nix
    ./boot.nix
    ./filesystems.nix
    ./gdm.nix
    ./niri.nix
    ./nvidia.nix
    ./audio.nix
    ./adb.nix
    ./vr.nix
    ./firewall.nix
    ./docker.nix
    ./remote-dev.nix
  ];
}
