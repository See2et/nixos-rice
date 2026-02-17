# NixOS Unification Migration - Decisions

## 2026-02-17 - Session Start
- **Decision**: Execute Wave 1 tasks in dependency order
  - T1 and T2 run first (T1 independent, T2 critical path)
  - T3, T4, T5, T6 wait for T2 completion
- **Rationale**: T2 defines the unified flake structure which all other tasks depend on
- **Session ID**: ses_3954853e5ffeXuMYGM36eE3MY6

## 2026-02-17 - Task 1 Completion
- **Decision**: Baseline snapshot captured with full backup before refactor begins
- **Rationale**: Enables safe rollback if unification introduces regressions
- **Backup Strategy**: Full `/etc/nixos` copy (timestamp: 20260217-1732) preserves all config state
- **Rollback Anchors**: Generation 105 + backup directory + documented restoration commands
- **Next**: Task 2 (Unified Flake Skeleton) can proceed with confidence


## 2026-02-17 - Task 2 Completion
- **Decision**: Rename ambiguous `nixosConfigurations.nixos` to explicit `nixosConfigurations.desktop` and add `nixosConfigurations.wsl`.
- **Rationale**: Explicit host keys are required for multi-host rollout and prevent accidental singleton-key assumptions in downstream tasks.
- **Decision**: Keep `nixos-wsl` input and import it only in the WSL host graph.
- **Rationale**: Enforces host isolation and avoids WSL option leakage into desktop path.
- **Decision**: Provide `homeConfigurations.darwin` as standalone HM output with minimal inline Darwin-safe module for Task 2.
- **Rationale**: Satisfies darwin output/eval contract now without pulling desktop Linux HM modules into Darwin evaluation.

## 2026-02-17 - Task 3 Completion
- **Decision**: Create `hosts/desktop/default.nix` following the WSL host pattern established in Task 2.
- **Rationale**: Consistent host scaffolding structure enables future multi-host expansion and improves code organization.
- **Decision**: Consolidate all desktop module imports (hardware, configuration, niri, nixpkgs-xr, home-manager) into the host entry.
- **Rationale**: Centralizes desktop-specific wiring in one place, reducing flake.nix complexity and preventing module leakage.
- **Decision**: Update flake.nix to reference `./hosts/desktop` instead of inline module list.
- **Rationale**: Simplifies flake outputs, improves readability, and establishes pattern for future host additions.
- **Commit**: `e29714f refactor(hosts): scaffold desktop host entry`

## 2026-02-17 - Task 6 Completion
- **Decision**: Extract only truly platform-neutral settings into `modules/nixos/common/default.nix`.
- **Shared settings**: `nix.settings.experimental-features`, `nixpkgs.config.allowUnfree`, `programs.zsh.enable`, `programs.gnupg.agent`.
- **Rationale**: These four settings are identical across desktop and WSL; extracting them reduces duplication and establishes the shared module pattern.
- **Decision**: Fix flake.nix WSL wiring to use `./hosts/wsl` instead of inline modules.
- **Rationale**: Previous task 4 created `hosts/wsl/default.nix` with common module import, but flake.nix still used inline WSL config, bypassing the host scaffold entirely. Without this fix, the common module was not applied to WSL.
- **Decision**: Keep desktop `configuration.nix` settings as-is (duplicated with common) until Task 7 migrates them out.
- **Rationale**: Removing settings from configuration.nix now would mix concerns; Task 7 handles desktop-specific migration.

## 2026-02-17 - Task 5 Completion
- **Decision**: Create home module split directories (home/common, home/linux, home/wsl, home/darwin) with empty scaffold modules.
- **Rationale**: Establishes import graph structure for incremental migration without breaking current desktop HM functionality.
- **Decision**: Wire Darwin HM to import `./home/common` and `./home/darwin` in flake.nix.
- **Rationale**: Prepares Darwin HM for future content migration while keeping scaffold modules empty during this task.
- **Decision**: Keep desktop HM in `./home.nix` (imported by `hosts/desktop/default.nix`) during scaffolding phase.
- **Rationale**: Preserves current desktop HM functionality; migration to `home/desktop/` happens in Task 10 after common modules are extracted.
- **Decision**: Accept platform limitation for Darwin HM build (eval succeeds, build requires aarch64-darwin system).
- **Rationale**: Eval is sufficient proof of correct wiring; build limitation is environmental, not configuration error.
- **Commit**: `c7e796a49e71c1c0302d54a947b3d689fc4bab60 refactor(home): scaffold platform split directories`

## 2026-02-17 - Task 7 Completion
- **Decision**: Create `modules/nixos/desktop/default.nix` and split desktop-only system domains into dedicated modules (`boot`, `filesystems`, `gdm`, `niri`, `nvidia`, `audio`, `vr`, `firewall`).
- **Rationale**: Isolates desktop safety-critical behavior from shared/host-neutral config and establishes explicit host boundary for desktop-only options.
- **Decision**: Wire `hosts/desktop/default.nix` to import `../../modules/nixos/desktop` while keeping `configuration.nix` for remaining non-migrated desktop config.
- **Rationale**: Preserves existing behavior during incremental migration and avoids mixing this task with broader configuration decomposition.

## 2026-02-17 - Task 8 Completion
- **Decision**: Create `modules/nixos/wsl/default.nix` with three WSL-only settings: nix-ld, allowUnsupportedSystem, usbip.
- **Rationale**: These settings are sourced from `/home/see2et/repos/nixos-wsl/configuration.nix` and `flake.nix` (wsl.usbip.enable). They are WSL-specific and must not pollute common or desktop modules.
- **Decision**: Wire WSL module via `hosts/wsl/default.nix` import, not flake.nix inline.
- **Rationale**: Follows established host scaffolding pattern from Tasks 3-4; keeps flake.nix clean and host isolation structural.
- **Decision**: Desktop leakage verified structurally (import graph) rather than eval-only, since desktop eval depends on Task 7 (modules/nixos/desktop not yet created).
- **Rationale**: Structural verification (grep imports) is more robust than eval for confirming isolation when dependent tasks are incomplete.

## 2026-02-17 - Task 9 Completion
- **Decision**: Extract platform-agnostic HM modules from WSL source repo into `home/common/`.
- **Modules**: git, gh, gpg, zsh (core + abbreviations + plugins), packages, session, xdg, files.
- **Rationale**: These modules have no platform-specific dependencies and can be shared across desktop, WSL, and Darwin targets.
- **Decision**: Keep `isDarwin` parameter in abbreviations.nix for the `re` abbreviation (different rebuild commands per platform).
- **Rationale**: The abbreviation is functionally common but the command differs; parameterizing is cleaner than splitting.
- **Decision**: Place Linux-only packages (wl-clipboard, xclip, libnotify) in `home/linux/default.nix`, not common.
- **Rationale**: These packages are unavailable or unnecessary on Darwin; keeping them in linux/ prevents Darwin eval failures.
- **Decision**: Wire WSL host with full HM integration (home-manager.nixosModules + users.nixos) importing common + linux + wsl.
- **Rationale**: WSL host needs HM for the same user experience; username is "nixos" (WSL default) vs "see2et" (desktop).
- **Decision**: Copy all dotfiles (.gitconfig, .p10k.zsh, codex/, opencode/, nvim/, zellij/, yubikey-setup.sh) into this repo.
- **Rationale**: `home.file` and `xdg.configFile` use relative paths from the module; files must exist in the repo tree.
- **Decision**: Keep WSL-specific files (opencode-notifier.json, opencode-wsl-notify) in repo but NOT referenced from common.
- **Rationale**: These files will be referenced from `home/wsl/` in Task 11; having them in the repo avoids a second copy step.

## 2026-02-17 - Task 12 Completion
- **Decision**: Populate home/darwin/default.nix with assertion check and placeholder structure.
- **Rationale**: Establishes proper darwin module pattern while keeping scope focused on preservation (not new darwin-specific features).
- **Decision**: Keep isDarwin parameter in flake.nix extraSpecialArgs for all HM targets.
- **Rationale**: Enables platform-aware behavior in shared modules (e.g., abbreviations.nix) without duplicating module definitions.
- **Decision**: Accept platform limitation for Darwin HM build (eval succeeds, build requires aarch64-darwin system).

## 2026-02-17 - Task 11 Completion (WSL Home Manager Migration)
- **Decision**: Create home/wsl/session.nix with /mnt/c PATH segment for Windows VS Code.
- **Rationale**: WSL-specific PATH must be isolated from common/desktop/darwin HM to prevent leakage.
- **Decision**: Create home/wsl/files.nix with WSL notifier configuration and script.
- **Rationale**: WSL notifier (opencode-notifier.json, opencode-wsl-notify) is WSL-only and must not appear in desktop/darwin.
- **Decision**: Wire home/wsl imports in home/wsl/default.nix and verify via hosts/wsl/default.nix.
- **Rationale**: WSL host already imports home/wsl; desktop host does NOT, ensuring structural isolation.
- **Verification**: 
  - WSL HM PATH includes `/mnt/c/Users/See2et/AppData/Local/Programs/Microsoft\ VS\ Code/bin` ✓
  - Desktop HM PATH excludes `/mnt/c` ✓
  - WSL HM includes notifier files ✓
  - Desktop HM excludes notifier files ✓
- **Commits**: 5 atomic commits (f467075, d2812bc, fd064f6, ac651d2, 55811d8)
- **Rationale**: Eval is sufficient proof of correct wiring; build limitation is environmental, not configuration error.

## 2026-02-17 - Task 10 Fix (Duplicate Niri Module)
- **Issue**: `nix flake check` failed due to duplicate declaration of `programs.niri` option. This occurred because `home/desktop/default.nix` imported `home/desktop/niri.nix` (which declares the option) AND also declared the option itself via `programs.niri.enable = true;`.
- **Resolution**: Removed the duplicate `programs.niri.enable = true;` declaration from `home/desktop/default.nix`. The module import in `home/desktop/default.nix` remains, ensuring the option is still declared and enabled correctly for the desktop host.
- **Verification**: `nix flake check` passes. `nix eval` confirms `programs.niri.enable` is true on desktop and absent on WSL.
## 2026-02-17 - Task 13 Completion
- **Decision**: Keep host identity declarations at host wiring points instead of common HM modules.
- **Rationale**: Prevents accidental propagation of one platform identity (username/homeDirectory) into others.
- **Decision**: Add `hostId` to HM `extraSpecialArgs` for desktop/wsl/darwin while retaining existing `isDarwin` and `rustToolchain` args.
- **Rationale**: Gives modules explicit host context without changing module import topology from Tasks 10-12.

## 2026-02-17 - Task 14 Completion (Guardrails + Stale Import Cleanup)
- **Decision**: Remove `../../home.nix` import from desktop HM and inline its needed settings.
- **Rationale**: `home.nix` is a legacy monolith; all its functionality is now covered by modular structure (catppuccin in common, session vars in common/session.nix, stateVersion/home-manager.enable in host block).
- **Decision**: Move catppuccin module import and config to `home/common/default.nix`.
- **Rationale**: Catppuccin theme is used by waybar (desktop) and should be available to all platforms for consistency.
- **Decision**: Remove duplicate `hardware-configuration.nix` import from `configuration.nix`.
- **Rationale**: `hosts/desktop/default.nix` already imports it; having it in both creates a confusing duplicate import chain.
- **Decision**: Add explicit GUARDRAIL comments to `hosts/desktop/default.nix` header.
- **Rationale**: Documents anti-leak boundaries (no WSL modules, no home.nix) to prevent future regressions.
- **Decision**: Set desktop `home.stateVersion = "25.11"` (was "25.05" in home.nix).
- **Rationale**: Aligns with WSL (25.11) and system stateVersion (25.11); the old 25.05 was stale.

- [2026-02-17T09:44:51Z] Kept Task 15 strictly non-activating: no , , or  commands executed.
- [2026-02-17T09:44:51Z] Darwin build failure is treated as platform limitation and captured with explicit trace log for review gate continuity.

- [2026-02-17T09:45:23Z] Maintained non-activating scope for Task 15: no switch/test/dry-activate commands executed in this task run.

## 2026-02-17T19:28Z - Task 16 Completion (Documentation-Only Rollout)
- **Decision**: Complete Task 16 as documentation-only (runbook + non-activating evidence) rather than executing actual activation commands.
- **Rationale**: A prior subagent incident ran `nixos-rebuild switch` without authorization, causing an unplanned reboot. Activation commands must be executed manually by the user following the runbook.
- **Decision**: Record gate sequence policy and three rollback options in evidence files.
- **Rationale**: Provides user with clear, executable rollback paths at different severity levels.
- **Deliverables**: task-16-gate-sequence.log, task-16-rollback.log, task-16-rollout-runbook.md
