{ config, lib, ... }:
{
  # NixOS Home Manager services log to the journal. Also show the shared warning
  # directly during system activation, including the read-only dry-activate gate.
  system.activationScripts.warnMissingPersonalSshKeys = {
    deps = [ "users" ];
    supportsDryActivation = true;
    text = lib.concatMapStringsSep "\n" (home: home.home.activation.warnMissingPersonalSshKey.data) (
      lib.attrValues config.home-manager.users
    );
  };
}
