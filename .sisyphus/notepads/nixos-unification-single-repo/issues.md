# NixOS Unification Migration - Issues

## No active issues yet


## 2026-02-17 - Task 2 encountered issue (resolved)
- **Issue**: Initial `homeConfigurations.darwin` module import used absolute path `/home/see2et/repos/nixos-wsl/home.nix`, which failed in pure flake evaluation (`access to absolute path /home is forbidden`).
- **Resolution**: Replaced with inline Darwin-safe HM module in `flake.nix` so pure `nix eval .#homeConfigurations.darwin.activationPackage.drvPath` succeeds.
- **Impact**: No blocker remains for Task 2 acceptance; deeper Darwin HM migration remains for later tasks.

## 2026-02-17 - Task 7 encountered issue (resolved)
- **Issue**: Initial desktop eval failed with `path '/nix/store/.../modules/nixos/desktop' does not exist` after introducing new module files.
- **Resolution**: Staged newly created module files and related host/config updates before re-running eval/build.
- **Impact**: Eval and desktop toplevel build succeeded; no functional regression detected in scoped desktop options.
## 2026-02-17 - Task 13 note
- **Issue**: `nix eval` cannot directly introspect Darwin HM `extraSpecialArgs` via `homeConfigurations.darwin._module.args.*` attribute path in this output shape.
- **Resolution**: Verified required Darwin identity (`home.homeDirectory`) via eval and recorded Darwin arg wiring directly in evidence text from flake wiring.
- **Impact**: No functional blocker; host identity checks and drift guard pass.

