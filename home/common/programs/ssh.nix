{ config, lib, ... }:
let
  personalKey = ".ssh/id_ed25519_personal";
in
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings."*".IdentityFile = "~/${personalKey}";
  };

  # Keep private keys outside Git and the Nix Store; only check at activation time.
  home.activation.warnMissingPersonalSshKey = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -f ${lib.escapeShellArg "${config.home.homeDirectory}/${personalKey}"} ]; then
      printf 'WARNING: SSH private key is missing: %s\n' ${lib.escapeShellArg "${config.home.homeDirectory}/${personalKey}"} >&2
      printf 'Place the key there manually, outside Git and the Nix Store. SSH authentication using this key will fail until it is present.\n' >&2
      printf 'Hint (run as the affected user): mkdir -p ~/.ssh && chmod 700 ~/.ssh && ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_personal\n' >&2
    fi
  '';
}
