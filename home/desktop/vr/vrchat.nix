{
  lib,
  pkgs,
  ...
}:
let
  isX86_64 = pkgs.stdenv.hostPlatform.isx86_64;
in
{
  home.packages = lib.optionals isX86_64 (
    with pkgs;
    [
      vrcx
      sidequest
      unityhub
      alcom
      vrc-get
    ]
  );

  xdg.configFile = lib.mkIf isX86_64 {
    "vrc-get/repositories.txt".source = ./vpm-repositories.txt;
  };
}
