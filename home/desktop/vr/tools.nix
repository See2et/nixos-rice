{ pkgs, ... }:
let
  runtimeInputs = [
    pkgs.bash
    pkgs.binutils
    pkgs.coreutils
    pkgs.findutils
    pkgs.jq
  ];

  steamvrRuntimeEnv = pkgs.writeShellApplication {
    name = "steamvr-runtime-env";
    inherit runtimeInputs;
    text = builtins.readFile ./tools/steamvr-runtime-env;
  };

  steamvrSelectOpenxr = pkgs.writeShellApplication {
    name = "steamvr-select-openxr";
    inherit runtimeInputs;
    text = builtins.readFile ./tools/steamvr-select-openxr;
  };

  steamvrDiagnose = pkgs.writeShellApplication {
    name = "steamvr-diagnose";
    inherit runtimeInputs;
    text = builtins.readFile ./tools/steamvr-diagnose;
  };
in
{
  home.packages = [
    steamvrRuntimeEnv
    steamvrSelectOpenxr
    steamvrDiagnose
  ];
}
