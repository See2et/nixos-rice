# NixOS Unification Migration - Issues

## No active issues yet


## 2026-02-17 - Task 2 encountered issue (resolved)
- **Issue**: Initial `homeConfigurations.darwin` module import used absolute path `/home/see2et/repos/nixos-wsl/home.nix`, which failed in pure flake evaluation (`access to absolute path /home is forbidden`).
- **Resolution**: Replaced with inline Darwin-safe HM module in `flake.nix` so pure `nix eval .#homeConfigurations.darwin.activationPackage.drvPath` succeeds.
- **Impact**: No blocker remains for Task 2 acceptance; deeper Darwin HM migration remains for later tasks.
