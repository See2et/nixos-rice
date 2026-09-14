{ ... }:

let
  sunshinePort = 47989;
in
{
  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = false;
    openFirewall = false;

    settings = {
      port = sunshinePort;
      capture = "wlr";
      encoder = "nvenc";
      upnp = "disabled";
      origin_web_ui_allowed = "pc";
    };

    applications.apps = [
      {
        name = "Desktop";
        image-path = "desktop.png";
      }
    ];
  };

  networking.firewall.interfaces."tailscale0" = {
    allowedTCPPorts = [
      (sunshinePort - 5)
      sunshinePort
      (sunshinePort + 21)
    ];
    allowedUDPPorts = [
      (sunshinePort + 9)
      (sunshinePort + 10)
      (sunshinePort + 11)
      (sunshinePort + 13)
      (sunshinePort + 21)
    ];
  };

  systemd.sleep.settings.Sleep = {
    AllowSuspend = false;
    AllowHibernation = false;
    AllowHybridSleep = false;
    AllowSuspendThenHibernate = false;
  };
}
