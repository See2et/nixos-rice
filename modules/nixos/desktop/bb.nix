{ pkgs, ... }:
{
  systemd.services.bb-tailnet = {
    description = "Private bb HTTPS route through Tailscale Serve";
    wantedBy = [ "multi-user.target" ];
    wants = [
      "tailscaled.service"
      "network-online.target"
    ];
    after = [
      "tailscaled.service"
      "network-online.target"
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.python3}/bin/python3 ${./scripts/bb-tailnet.py} ${pkgs.tailscale}/bin/tailscale";
      # Serve persists its mapping. Never reset Serve or remove other services' routes.
      TimeoutStartSec = 60;
    };
  };
}
