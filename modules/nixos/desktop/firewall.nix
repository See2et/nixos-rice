{ ... }:

{
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      9943
      9944
    ];
    allowedUDPPorts = [
      9943
      9944
    ];
  };
}
