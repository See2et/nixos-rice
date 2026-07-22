{ ... }:

{
  services.accounts-daemon.enable = true;
  services.geoclue2.enable = true;
  services.power-profiles-daemon.enable = true;
  security.polkit.enable = true;

  security.pam.services.dankshell.allowNullPassword = false;

  systemd.user.services.niri-flake-polkit.enable = false;
}
