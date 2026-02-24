{ pkgs, ... }:

{
  systemd.tmpfiles.rules = [
    "d /etc/nixos 2775 root users - -"
  ];

  system.activationScripts.nixosRepoPermissions.text = ''
    if [ -d /etc/nixos ]; then
      chown -R root:users /etc/nixos
      chmod -R g+rwX /etc/nixos
      ${pkgs.findutils}/bin/find /etc/nixos -type d -exec chmod g+s {} +
    fi
  '';
}
