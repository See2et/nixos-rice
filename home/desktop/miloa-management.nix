{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  checkout = "${config.home.homeDirectory}/ghq/github.com/see2et/miloa-management";
  herdr = inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default;
  # The packaged Bun executable cannot load node:sqlite. Reuse the prepared
  # checkout's same-version native Pi CLI under Node, with the normal agent dir.
  nodePi = pkgs.writeShellScriptBin "pi" ''
    exec ${pkgs.nodejs_24}/bin/node ${checkout}/node_modules/@earendil-works/pi-coding-agent/dist/bundle/cli.js "$@"
  '';
in
{
  _module.args.piBasePackage = nodePi // {
    version = "1.0.4";
    meta = {
      mainProgram = "pi";
    };
  };

  systemd.user.services.miloa-management-background = {
    Unit = {
      Description = "Miloa Management authorized background queue (single host)";
      After = [ "network-online.target" ];
    };
    # No Install/WantedBy: applying Home Manager must not launch authorized work.
    Service = {
      Type = "simple";
      WorkingDirectory = checkout;
      Environment = [
        "PATH=${
          lib.makeBinPath [
            pkgs.nodejs_24
            herdr
            pkgs.git
            pkgs.gh
          ]
        }:${config.home.profileDirectory}/bin:/run/current-system/sw/bin"
      ];
      EnvironmentFile = "-%h/.config/miloa-management/service.env";
      ExecStart = "${pkgs.nodejs_24}/bin/node ${checkout}/dist/background.js serve --consent-launch";
      UMask = "0077";
      Restart = "on-failure";
      RestartSec = 10;
      TimeoutStopSec = 30;
      KillMode = "control-group";
    };
  };
}
