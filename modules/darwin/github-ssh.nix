{ lib, darwinUser, ... }:
import ../shared/github-ssh.nix {
  inherit lib;
  username = darwinUser.name;
  homeDirectory = darwinUser.home;
}
