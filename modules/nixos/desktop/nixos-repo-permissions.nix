{ pkgs, ... }:

{
  users.groups.nixos-editors = { };

  users.users.see2et.extraGroups = [
    "nixos-editors"
  ];

  systemd.tmpfiles.rules = [
    "d /etc/nixos 2775 root nixos-editors - -"
  ];

  system.activationScripts.nixosRepoPermissions.text = ''
    if [ -d /etc/nixos ]; then
      chown -R root:nixos-editors /etc/nixos
      chmod -R g+rwX /etc/nixos
      ${pkgs.findutils}/bin/find /etc/nixos -type d -exec chmod g+s {} +
    fi
  '';
}
