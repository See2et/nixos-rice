{
  lib,
  config,
  extraPaths ? [ ],
}:
lib.concatStringsSep ":" (
  [
    "${config.xdg.dataHome}/fonts"
    "${config.home.profileDirectory}/share/fonts"
  ]
  ++ extraPaths
)
