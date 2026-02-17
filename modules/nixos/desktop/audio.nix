{ ... }:

{
  services.pulseaudio.enable = false;
  services.pipewire = {
    enable = true;
    pulse.enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    jack.enable = true;

    extraConfig = {
      pipewire."99-disable-x11-bell.conf" = {
        "context.properties" = {
          "module.x11.bell" = false;
        };
      };
    };
  };

  security.rtkit.enable = true;
  security.pam.loginLimits = [
    {
      domain = "@realtime";
      type = "-";
      item = "rtprio";
      value = "98";
    }
    {
      domain = "@realtime";
      type = "-";
      item = "nice";
      value = "-20";
    }
    {
      domain = "@realtime";
      type = "-";
      item = "memlock";
      value = "unlimited";
    }
  ];

  systemd.user.extraConfig = ''
    [Manager]
    DefaultLimitRTPRIO=98
    DefaultLimitNICE=-20
    DefaultLimitMEMLOCK=infinity
  '';
}
