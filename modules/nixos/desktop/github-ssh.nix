{ config, lib, ... }:
import ../../shared/github-ssh.nix {
  inherit lib;
  username = "see2et";
  homeDirectory = config.home-manager.users.see2et.home.homeDirectory;
}
