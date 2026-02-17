# NixOS Unification Migration - Learnings

## Project Conventions

### Repository Structure
- `/etc/nixos/` - Main NixOS configuration (desktop target)
- `/home/see2et/repos/nixos-wsl/` - WSL configuration (source for migration)

### Critical Files (Desktop Safety)
- `/etc/nixos/hardware-configuration.nix` - BOOT-CRITICAL, never modify without rollback plan
- `/etc/nixos/configuration.nix` - Main desktop config
- `/etc/nixos/home.nix` - Desktop Home Manager config

### Module Boundaries
- `hosts/desktop/` - Desktop-only host configuration
- `hosts/wsl/` - WSL-only host configuration
- `modules/nixos/common/` - Shared NixOS modules
- `modules/nixos/desktop/` - Desktop-only NixOS modules
- `modules/nixos/wsl/` - WSL-only NixOS modules
- `home/common/` - Shared Home Manager modules
- `home/linux/` - Linux-specific HM modules
- `home/wsl/` - WSL-specific HM modules
- `home/darwin/` - Darwin-specific HM modules

### Safety Rules
1. Desktop safety is the #1 constraint
2. Never skip `dry-activate` + `test` gates before `switch`
3. WSL options must NOT leak into desktop modules
4. Hardware configuration is desktop-only
5. `/mnt/c/` paths must NOT appear in common modules

### Git Strategy
- Each task has a commit message specified
- Pre-commit verification is mandatory
- Evidence files go to `.sisyphus/evidence/task-{N}-*`

## NixOS-WSL Reference
- Already modular structure in `/home/see2et/repos/nixos-wsl/`
- WSL module usage: `nixos-wsl.nixosModules.default`
- Darwin HM output exists at `homeConfigurations.darwin`

## Release Alignment
- nixpkgs: `nixos-25.11`
- home-manager: `release-25.11`

## Task 1 - Baseline Snapshot and Rollback Anchors (2026-02-17)

### Execution Summary
- **Current Generation**: 105 (baseline for unification)
- **Current System**: `/nix/store/zlvsxilxxngf2h1z46br2m2w1gfi2g8q-nixos-system-nixos-25.11.20260110.d030887`
- **Backup Location**: `/etc/nixos.pre-unify.20260217-1732`
- **Evidence Files**: 
  - `.sisyphus/evidence/task-1-generations.txt` (full generation list)
  - `.sisyphus/evidence/task-1-current-system.txt` (current-system symlink target)
  - `.sisyphus/evidence/task-1-no-switch.txt` (rollback documentation)

### Key Learnings
1. **Generation History**: 105 generations exist; current is 105 (2026-02-17 17:01:29)
2. **NixOS Version**: 25.11.20260110.d030887 (matches target release alignment)
3. **Backup Strategy**: Full `/etc/nixos` copy with timestamp ensures complete recovery
4. **Rollback Path**: Two options documented:
   - Restore from backup: `sudo cp -a /etc/nixos.pre-unify.20260217-1732 /etc/nixos`
   - Use generation rollback: `sudo nixos-rebuild switch --profile /nix/var/nix/profiles/system --rollback`

### Safety Verification
- ✓ No activation commands executed (read-only baseline capture)
- ✓ Hardware configuration preserved in backup
- ✓ Boot generation unchanged (105 remains current)
- ✓ All evidence files created and verified non-empty


## 2026-02-17 - Task 2 (Unified Flake Skeleton)
- `flake.nix` can expose explicit host keys by nesting under `nixosConfigurations = { desktop = ...; wsl = ...; };` while preserving desktop module wiring unchanged.
- `nixos-wsl` should stay isolated to the WSL module list; desktop evaluation remains free of `wsl.*` options.
- A standalone Darwin Home Manager output can be evaluated without host activation by defining a minimal inline HM module in flake outputs.
- Adding a new flake input (`nixos-wsl`) updates `flake.lock` automatically on first eval.

## 2026-02-17 - Task 3 (Desktop Host Scaffolding)
- Host scaffolding pattern: `hosts/{host}/default.nix` imports all host-specific modules and configuration files.
- Desktop host entry consolidates: hardware-configuration.nix, configuration.nix, niri, nixpkgs-xr, and home-manager module chain.
- Flake wiring simplification: `modules = [ ./hosts/desktop ]` replaces inline module list, improving readability and maintainability.
- Hardware UUID and filesystem settings preserved exactly through hardware-configuration.nix import chain.
- Desktop module behavior unchanged; scaffolding is purely structural reorganization.
- Eval verification confirms: `system.stateVersion = "25.11"` and `fileSystems."/".fsType = "ext4"` resolve correctly through host entry.

## 2026-02-17 - Task 6 (Shared Module Extraction Baseline)
- Safe shared settings identified: `nix.settings.experimental-features`, `nixpkgs.config.allowUnfree`, `programs.zsh.enable`, `programs.gnupg.agent` (with SSH support).
- NixOS merges list options (like `experimental-features`) from multiple modules — duplicates are harmless but visible in eval output.
- **Critical finding**: flake.nix WSL config was still inline (not using `./hosts/wsl`), so the common module import in `hosts/wsl/default.nix` was never reached. Fixed by updating flake.nix to use `./hosts/wsl`.
- Guardrail comment in common module documents forbidden patterns; grep evidence must filter comment lines to avoid false positives.
- `nix.settings.experimental-features` is a freeform setting that only appears in eval output when explicitly set — absence doesn't mean it's not configured at daemon level.

## 2026-02-17 - Task 5 (Home Tree Scaffolding)
- Home module split pattern: `home/{platform}/default.nix` for each target (common, linux, wsl, darwin).
- Flake wiring for Darwin HM: `modules = [ ./home/common ./home/darwin { ... } ]` enables incremental migration without breaking current desktop HM.
- Desktop HM remains in `./home.nix` (imported by `hosts/desktop/default.nix`) during scaffolding phase; migration to `home/desktop/` happens in Task 10.
- Darwin HM eval succeeds with scaffold modules (proof of correct import graph wiring).
- Darwin HM build cannot execute on x86_64-linux (platform limitation); eval is sufficient proof of correctness.
- Scaffold modules are empty placeholders with documentation; content migration happens in Tasks 9-12.
- Git tracking required: flake.nix changes must be staged before eval/build to avoid "path does not exist" errors in pure flake evaluation.

## 2026-02-17 - Task 7 (Desktop System Migration)
- Desktop-only option split works cleanly with a thin aggregator module (`modules/nixos/desktop/default.nix`) that imports per-domain modules.
- Moving boot/display/gpu/audio/vr/firewall options out of `configuration.nix` preserves behavior when `hosts/desktop/default.nix` imports the desktop module tree.
- `filesystems` ownership remains in `hardware-configuration.nix`; desktop module wiring should preserve this instead of duplicating filesystem declarations.
- Pure flake evaluation requires newly created module files to be tracked by Git (`git add`) before `nix eval`/`nix build` sees them.

## 2026-02-17 - Task 8 (WSL System Migration)
- WSL-only settings from source repo: `programs.nix-ld.enable` + libraries, `nixpkgs.config.allowUnsupportedSystem`, `wsl.usbip.enable`.
- `wsl.usbip.enable` is only available when `nixos-wsl.nixosModules.default` is imported (provides the `wsl.*` option namespace).
- Module import order in `hosts/wsl/default.nix`: common -> wsl -> nixos-wsl.nixosModules.default. The WSL module sets `wsl.usbip.enable` which requires the nixos-wsl module to define the option.
- Desktop isolation confirmed: `hosts/desktop/default.nix` does not import `modules/nixos/wsl` — structural guarantee, not just eval-time.
- New files must be `git add`-ed before `nix eval` can see them (flake uses git-tracked tree).
