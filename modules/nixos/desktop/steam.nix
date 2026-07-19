{
  lib,
  pkgs,
  inputs,
  ...
}:

let
  isX86_64 = pkgs.stdenv.hostPlatform.isx86_64;
  steamPkgs = import inputs.nixpkgs-steam {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
in

{
  programs.steam = lib.mkIf isX86_64 {
    enable = true;
    package = steamPkgs.steam;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
  };
}
