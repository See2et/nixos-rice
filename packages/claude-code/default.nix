# Opus 5.5 requires Claude Code >= 2.1.280. Pin only Claude, keeping nixpkgs fixed.
{ claude-code, lib }:
claude-code.override {
  manifest = lib.importJSON ./manifest.json;
}
