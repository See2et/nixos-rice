{ ... }:

{
  services.wivrn = {
    enable = true;
    openFirewall = true;
    defaultRuntime = true;
    autoStart = true;
  };

  services.avahi.enable = true;
  services.avahi.nssmdns4 = true;
}
