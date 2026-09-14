{ hostId, ... }:
{
  programs.zellij.enable = hostId == "wsl";
}
