{ pkgs, ... }:
let
  dockerPackage = pkgs.docker_29;
in
{
  virtualisation.docker = {
    enable = true;
    package = dockerPackage;
    rootless = {
      enable = true;
      setSocketVariable = true;
      package = dockerPackage;
    };
  };
}
