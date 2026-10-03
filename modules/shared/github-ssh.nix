# Shared system SSH policy; private key contents are never evaluated by Nix.
{
  lib,
  username,
  homeDirectory,
}:
{
  # Source: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints
  programs.ssh.knownHosts."github.com".publicKey =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";

  programs.ssh.extraConfig = lib.mkBefore ''
    Host github.com
      HostKeyAlgorithms ssh-ed25519
      StrictHostKeyChecking yes
      GlobalKnownHostsFile /etc/ssh/ssh_known_hosts
      UserKnownHostsFile /dev/null
    Match host github.com localuser root
      IdentityFile ${homeDirectory}/.ssh/id_ed25519_personal
      IdentitiesOnly yes
    Host *
  '';

  # Passphrase-protected keys must first be loaded by the normal user.
  security.sudo.extraConfig = ''
    Defaults:${username} env_keep += "SSH_AUTH_SOCK"
  '';
}
