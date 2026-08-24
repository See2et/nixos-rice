{ pkgs, ... }:

let
  jdk = pkgs.jdk17_headless;
in
{
  nixpkgs.config.android_sdk.accept_license = true;

  environment.systemPackages = [
    pkgs.android-studio
    jdk
    pkgs.rustup
  ];

  environment.sessionVariables = {
    JAVA_HOME = "${jdk}/lib/openjdk";
  };
}
