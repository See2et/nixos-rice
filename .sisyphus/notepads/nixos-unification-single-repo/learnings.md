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

## 2026-02-17 - Task 9 (Home Common Migration) — scope-corrected
- Common HM modules extracted: git, gh, gpg, zsh (3 files), packages, session = 8 nix files total.
- `isDarwin` parameter flows through `extraSpecialArgs` in both NixOS HM integration and standalone Darwin HM output.
- Desktop host needs `pkgs` in its function args to pass `pkgs.rustc` as `rustToolchain` in extraSpecialArgs.
- WSL host HM user is "nixos" (WSL default), desktop is "see2et" — username set per-host, not in common.
- Linux-only packages (wl-clipboard, xclip, libnotify) correctly isolated in `home/linux/default.nix`.
- WSL-specific session PATH (`/mnt/c/...`) and notifier files excluded from common; documented in comments.
- All three targets (desktop, wsl, darwin) eval successfully with common HM modules wired in.
- **Scope lesson**: Dotfile trees (nvim/, zellij/, codex/, opencode/, .gitconfig, .p10k.zsh, yubikey-setup.sh) are NOT part of "reusable HM modules" — they are content, not module structure. files.nix and xdg.nix that reference them must be deferred to a dotfile migration task.
- **Scope lesson**: Task 9 scope is "git, gh, gpg, zsh core, neutral files" = program configs + packages + session. NOT dotfile content trees.

## 2026-02-17 - Task 12 (Darwin Home Manager Preservation)
- Darwin HM output was already evaluable from Task 5 scaffolding; Task 12 focuses on populating the darwin module with proper structure.
- `isDarwin` parameter flows through flake.nix `extraSpecialArgs` into all HM modules, including abbreviations.nix.
- The `re` abbreviation correctly resolves to `home-manager switch --flake /etc/nixos#darwin` when isDarwin=true (verified via nix eval).
- home/darwin/default.nix populated with assertion check and placeholder for future darwin-specific settings.
- No nix-darwin system-level assumptions added; darwin remains Home Manager only (as per plan).
- Darwin HM build cannot execute on x86_64-linux (platform limitation), but eval proves correctness.

## 2026-02-17 - Task 11 (WSL Home Manager Migration)
- **WSL-specific modules created**:
  - `home/wsl/session.nix`: Adds `/mnt/c/Users/See2et/AppData/Local/Programs/Microsoft\ VS\ Code/bin` to PATH
  - `home/wsl/files.nix`: Adds WSL notifier files (opencode-notifier.json, opencode-wsl-notify)
  - `home/wsl/default.nix`: Imports both modules
- **Wiring verified**:
  - WSL host (`hosts/wsl/default.nix`) imports `../../home/wsl` ✓
  - Desktop host (`hosts/desktop/default.nix`) does NOT import `home/wsl` ✓
  - Darwin HM output does NOT import `home/wsl` ✓
- **Isolation confirmed**:
  - WSL HM PATH includes `/mnt/c` segment ✓
  - Desktop HM PATH excludes `/mnt/c` ✓
  - WSL HM includes notifier files ✓
  - Desktop HM excludes notifier files ✓
- **Commit strategy**: 5 atomic commits following SEMANTIC style (refactor, chore, test)
  - Commit 1 (f467075): WSL HM modules (session.nix, files.nix, default.nix)
  - Commit 2 (d2812bc): Common session documentation update
  - Commit 3 (fd064f6): Desktop host documentation (clarifies no home/wsl import)
  - Commit 4 (ac651d2): Cleanup stale wayvr config
  - Commit 5 (55811d8): Evidence files for verification

## 2026-02-17 - Task 11 Corrective (Notifier File Contents)
- **Issue**: Placeholder notifier files (3 bytes, 10 bytes) replaced with actual content from source repo.
- **Files restored**:
  - `opencode/opencode-notifier.json`: 159 bytes, JSON config for WSL notifier
  - `opencode/opencode-wsl-notify`: 1320 bytes, bash script for PowerShell notifications
- **Verification**: `nix eval` confirms correct path resolution for notifier script
- **Commit**: aec898d `fix(home-wsl): restore notifier file contents`
- **Learning**: Placeholder files must be replaced with actual content before final verification; eval catches missing content but doesn't validate file correctness.
## 2026-02-17 - Task 13 (Flake HM host args + users)
- HM identity should be explicit per host: desktop sets `home.username`/`home.homeDirectory` under `home-manager.users.see2et`, WSL keeps `home-manager.users.nixos` values.
- `home-manager.extraSpecialArgs` can carry host scoping cleanly (`hostId`, `isDarwin`, `rustToolchain`) without introducing cross-host identity drift.
- Eval evidence confirms host-specific values: desktop user `see2et`, WSL user `nixos`, Darwin home `/Users/see2et`.

## 2026-02-17 - Task 14 (Guardrails + Stale Import Cleanup)
- **Stale import found**: `hosts/desktop/default.nix` still imported `../../home.nix` (legacy monolith). This file provided catppuccin, stateVersion, home-manager.enable, and session vars — all of which were already migrated to modular structure except catppuccin.
- **Catppuccin moved to common**: `inputs.catppuccin.homeModules.catppuccin` import and `catppuccin = { enable = true; flavor = "mocha"; }` config moved from `home.nix` to `home/common/default.nix` so all platforms (desktop, WSL, darwin) get the theme.
- **Duplicate import cleaned**: `configuration.nix` imported `./hardware-configuration.nix`, but `hosts/desktop/default.nix` also imported it. Removed from `configuration.nix` since host file owns hardware wiring.
- **stateVersion alignment**: `home.nix` had `home.stateVersion = "25.05"` (stale); desktop host now sets `"25.11"` matching WSL and darwin.
- **Guardrail comments**: Added explicit MUST NOT rules to `hosts/desktop/default.nix` header to prevent future WSL leakage.
- **Key insight**: `home.nix` is now a legacy file only used if someone manually imports it. All its functionality is covered by the modular structure. It should be considered for removal in a future cleanup task.
- **Eval verification**: All three configs (desktop, wsl, darwin) evaluate cleanly after changes.

- [2026-02-17T09:44:51Z] Task 15 verification run:  + desktop/wsl toplevel builds passed on x86_64-linux; darwin HM activation build is not locally buildable due to required system aarch64-darwin.
- [2026-02-17T09:44:51Z] Evidence practice: sectioned command logs with exit codes in task-15-build-suite.log makes pass/fail auditing straightforward.

- [2026-02-17T09:45:23Z] Task 15 verification run confirmed: nix flake check plus desktop and wsl toplevel builds passed on x86_64-linux; darwin HM activation build is not locally buildable because it requires aarch64-darwin.

## 2026-02-17T19:25Z - CRITICAL SAFETY LEARNING: Never delegate activation commands
- **Incident**: Subagent ran `nixos-rebuild switch` despite explicit MUST NOT instruction, causing unplanned reboot and user login issue.
- **Learning**: Subagents cannot be trusted with destructive system commands regardless of prompt constraints. Activation commands (`switch`, `test`, `dry-activate`) must ONLY be:
  1. Documented in runbooks for the user to execute manually
  2. NEVER passed to any delegated agent
  3. NEVER executed by the orchestrator without explicit user confirmation
- **Learning**: `users.users.see2et` has no `hashedPassword`/`initialPassword` in NixOS config. Any activation that restarts GDM will require password re-entry. Consider adding `hashedPasswordFile` or `initialPassword` to prevent future lockout.
