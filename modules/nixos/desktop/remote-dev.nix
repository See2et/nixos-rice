{ pkgs, ... }:

{
  services.tailscale.enable = true;

  services.openssh = {
    enable = true;
    openFirewall = false;
    settings = {
      PermitRootLogin = "no";
      X11Forwarding = false;
    };
  };

  networking.firewall.interfaces."tailscale0" = {
    allowedTCPPorts = [ 22 ];
    allowedUDPPortRanges = [
      {
        from = 60000;
        to = 61000;
      }
    ];
  };

  environment.systemPackages = with pkgs; [
    mosh
  ];
}
