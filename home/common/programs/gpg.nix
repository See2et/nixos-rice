# Common GPG configuration
{ ... }:
{
  programs.gpg = {
    enable = true;
    scdaemonSettings = {
      disable-ccid = true;
    };
  };
}
