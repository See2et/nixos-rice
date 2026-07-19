{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  isX86_64 = pkgs.stdenv.hostPlatform.isx86_64;
  wayvrPackage = inputs.nixpkgs.legacyPackages.${pkgs.stdenv.hostPlatform.system}.wayvr;

  wayvrOpenxr = pkgs.writeShellApplication {
    name = "wayvr-openxr";
    runtimeInputs = [ wayvrPackage ];
    text = ''
      exec ${wayvrPackage}/bin/wayvr --openxr "$@"
    '';
  };

  wayvrOpenvr = pkgs.writeShellApplication {
    name = "wayvr-openvr";
    runtimeInputs = [ wayvrPackage ];
    text = ''
      exec ${wayvrPackage}/bin/wayvr --openvr "$@"
    '';
  };
in
{
  home.packages = lib.optionals isX86_64 [
    wayvrPackage
    wayvrOpenxr
    wayvrOpenvr
  ];

  xdg.configFile = lib.mkIf isX86_64 {
    "wayvr/config.yaml".source = ./wayvr/config.yaml;
    "wayvr/openxr_actions.json5".source = ./wayvr/openxr_actions.json5;
  };

  xdg.desktopEntries.wayvr-openxr = lib.mkIf isX86_64 {
    name = "WayVR (OpenXR)";
    genericName = "VR desktop shell";
    comment = "Launch WayVR in explicit OpenXR mode";
    exec = "wayvr-openxr";
    terminal = false;
    type = "Application";
    categories = [
      "Game"
      "Utility"
    ];
    startupNotify = true;
  };

  xdg.desktopEntries.wayvr-openvr = lib.mkIf isX86_64 {
    name = "WayVR (OpenVR)";
    genericName = "VR desktop shell";
    comment = "Launch WayVR in explicit OpenVR mode";
    exec = "wayvr-openvr";
    terminal = false;
    type = "Application";
    categories = [
      "Game"
      "Utility"
    ];
    startupNotify = true;
  };
}
