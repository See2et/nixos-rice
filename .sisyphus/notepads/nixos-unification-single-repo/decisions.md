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
- **Decision**: Accept platform limitation for Darwin HM build (eval succeeds, build requires aarch64-darwin).
- **Rationale**: Eval is sufficient proof of correct wiring; build limitation is environmental, not configuration error.
