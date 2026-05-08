_final: prev: {
  direnv = prev.direnv.overrideAttrs (_old: {
    # Work around the current Darwin-only test-fish failure in nixpkgs.
    checkPhase = ''
      runHook preCheck

      make test-go test-bash test-zsh

      runHook postCheck
    '';
  });
}
