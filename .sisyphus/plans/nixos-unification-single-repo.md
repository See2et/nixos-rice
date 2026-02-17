# Unify NixOS Desktop + NixOS on WSL (+ Darwin HM) in One Repository

## TL;DR

> **Quick Summary**: Consolidate `/home/see2et/repos/nixos-wsl` into `/etc/nixos` with host-isolated modules (`desktop`, `wsl`) and platform-aware Home Manager split (`common`, `linux`, `wsl`, `darwin`) while keeping desktop safety as the top constraint.
>
> **Deliverables**:
> - Unified flake with `nixosConfigurations.desktop`, `nixosConfigurations.wsl`, and `homeConfigurations.darwin`
> - Explicit host/module boundaries preventing WSL leakage into desktop
> - Mandatory rollout gates: desktop `dry-activate` + `test` before `switch`
>
> **Estimated Effort**: Large
> **Parallel Execution**: YES - 3 implementation waves + final verification wave
> **Critical Path**: T2 -> T7 -> T14 -> T15 -> T16

---

## Context

### Original Request
`~/repos/nixos-wsl` の内容を `/etc/nixos` に統合し、複数環境を単一のレポジトリで管理したい。条件は以下:
1. Desktop が破綻しないこと
2. 1に反しない範囲で WSL 側を正とすること
3. プラットフォーム分離/共通化を明確にして保守性を上げること
4. 本番反映前に build 成功を検証すること

### Interview Summary
**Key decisions confirmed**:
- Desktop rollout gate is mandatory: both `dry-activate` and `test` must pass before `switch`.
- Darwin remains in scope as **Home Manager only** target (no nix-darwin system migration in this plan).
- Release alignment is immediate: unify on `nixos-25.11` / `home-manager release-25.11` during this migration.

**Repository evidence**:
- Desktop monolith currently in `/etc/nixos/configuration.nix:14`, `/etc/nixos/home.nix:9`.
- Desktop safety-critical hardware/boot in `/etc/nixos/hardware-configuration.nix:1` and `/etc/nixos/configuration.nix:19`.
- WSL already modular in `/home/see2et/repos/nixos-wsl/home.nix:3` and `/home/see2et/repos/nixos-wsl/home/programs/zsh/default.nix:4`.
- WSL module usage in `/home/see2et/repos/nixos-wsl/flake.nix:88` and `/home/see2et/repos/nixos-wsl/flake.nix:91`.
- Darwin HM output exists in `/home/see2et/repos/nixos-wsl/flake.nix:124`.

### Gap Review (Metis-equivalent)
**Identified gaps and resolutions**:
- Gap: ambiguous source-of-truth boundary -> resolved by strict domain policy (desktop safety domains stay desktop-owned; shared CLI/Home patterns prefer WSL).
- Gap: Darwin could go stale after split -> resolved by explicit `home/darwin` split and acceptance criteria requiring Darwin HM build.
- Gap: scope creep risk during refactor -> resolved by behavior-preserving guardrail and explicit "Must NOT do" in each task.
- Gap: unverified assumptions -> resolved by command-level acceptance criteria for eval/build/activation gates.

---

## Work Objectives

### Core Objective
Produce a single `/etc/nixos` flake repository that manages desktop + WSL safely, keeps Darwin Home Manager viable, and introduces clear module boundaries that prevent platform cross-contamination.

### Concrete Deliverables
- `flake.nix` exposes:
  - `nixosConfigurations.desktop`
  - `nixosConfigurations.wsl`
  - `homeConfigurations.darwin`
- New module layout:
  - `hosts/desktop`, `hosts/wsl`
  - `modules/nixos/common`, `modules/nixos/desktop`, `modules/nixos/wsl`
  - `home/common`, `home/linux`, `home/wsl`, `home/darwin`
- Verified rollout evidence in `.sisyphus/evidence/`

### Definition of Done
- [ ] `nix flake check --show-trace` passes
- [ ] `nix build .#nixosConfigurations.desktop.config.system.build.toplevel` passes
- [ ] `nix build .#nixosConfigurations.wsl.config.system.build.toplevel` passes
- [ ] `nix build .#homeConfigurations.darwin.activationPackage` passes
- [ ] Desktop `dry-activate` and `test` pass before any desktop `switch`

### Must Have
- Desktop boot/hardware/GPU/display stack preserved unless explicitly changed and validated
- WSL module/options applied only to WSL host
- Darwin HM output preserved and buildable

### Must NOT Have (Guardrails)
- Do not import `nixos-wsl.nixosModules.default` into desktop host
- Do not share `hardware-configuration.nix` in common modules
- Do not leak `/mnt/c/...` PATH or WSL notifier into desktop/darwin common modules
- Do not skip desktop `dry-activate` + `test` gate
- Do not migrate to nix-darwin in this scope

---

## Verification Strategy (MANDATORY)

> **ZERO HUMAN INTERVENTION** — All acceptance checks are command/tool executable.

### Test Decision
- **Infrastructure exists**: NO dedicated unit/integration test framework for this infra repo
- **Automated tests**: None (command-level infra verification only)
- **Framework**: N/A
- **Agent-Executed QA**: Mandatory for every task via `bash` checks and evidence capture

### QA Policy
- Every task includes at least one happy-path and one failure/guardrail scenario.
- Evidence files saved under `.sisyphus/evidence/task-{N}-*.{txt,log,json}`.

| Deliverable Type | Verification Tool | Method |
|------------------|-------------------|--------|
| Flake/Module eval | Bash | `nix eval`, `nix flake check` |
| Build closures | Bash | `nix build ...config.system.build.toplevel` |
| Activation safety | Bash | `nixos-rebuild dry-activate/test` |
| Rollback path | Bash | generation listing + rollback command simulation/runbook |

---

## Execution Strategy

### Parallel Execution Waves

```text
Wave 1 (Start Immediately — structure + scaffolding):
├── Task 1: Baseline snapshot + rollback anchors [quick]
├── Task 2: Unified flake skeleton + 25.11 alignment [deep]
├── Task 3: Desktop host scaffolding [quick]
├── Task 4: WSL host scaffolding [quick]
├── Task 5: Home tree scaffolding (common/linux/wsl/darwin) [quick]
└── Task 6: Shared module extraction baseline [unspecified-high]

Wave 2 (After Wave 1 — bulk migration, max parallel):
├── Task 7: Desktop system module migration [deep]
├── Task 8: WSL system module migration [unspecified-high]
├── Task 9: Home common migration from WSL modules [unspecified-high]
├── Task 10: Desktop Home Manager migration [visual-engineering]
├── Task 11: WSL Home Manager migration/isolation [quick]
├── Task 12: Darwin Home Manager preservation [quick]
└── Task 13: Flake wiring for HM users + specialArgs [deep]

Wave 3 (After Wave 2 — guardrails + validation):
├── Task 14: Add anti-leak guardrails + cleanup stale imports [unspecified-high]
├── Task 15: Non-activating verification suite (eval/build/check) [deep]
└── Task 16: Activation-gated rollout + rollback proof [deep]

Wave FINAL (After all implementation tasks — independent review, 4 parallel):
├── Task F1: Plan compliance audit (oracle-equivalent)
├── Task F2: Config quality review (unspecified-high)
├── Task F3: Real execution QA replay (unspecified-high)
└── Task F4: Scope fidelity check (deep)

Critical Path: T2 -> T7 -> T14 -> T15 -> T16
Parallel Speedup: ~60% vs sequential
Max Concurrent: 7 (Wave 2)
```

### Dependency Matrix (FULL)

| Task | Depends On | Blocks | Wave |
|------|------------|--------|------|
| 1 | - | 16 | 1 |
| 2 | - | 7, 8, 13, 15 | 1 |
| 3 | 2 | 7, 10 | 1 |
| 4 | 2 | 8, 11 | 1 |
| 5 | 2 | 9, 10, 11, 12 | 1 |
| 6 | 2 | 7, 8, 9 | 1 |
| 7 | 3, 6 | 14, 15, 16 | 2 |
| 8 | 4, 6 | 14, 15 | 2 |
| 9 | 5, 6 | 13, 14, 15 | 2 |
| 10 | 3, 5 | 13, 14, 15 | 2 |
| 11 | 4, 5 | 13, 14, 15 | 2 |
| 12 | 5 | 13, 15 | 2 |
| 13 | 2, 9, 10, 11, 12 | 14, 15 | 2 |
| 14 | 7, 8, 9, 10, 11, 13 | 15, 16 | 3 |
| 15 | 2, 7, 8, 9, 10, 11, 12, 13, 14 | 16, F1-F4 | 3 |
| 16 | 1, 7, 14, 15 | F1-F4 | 3 |

### Agent Dispatch Summary

| Wave | # Parallel | Tasks -> Agent Category |
|------|------------|--------------------------|
| 1 | 6 | T1/T3/T4/T5 -> `quick`, T2 -> `deep`, T6 -> `unspecified-high` |
| 2 | 7 | T7/T13 -> `deep`, T8/T9 -> `unspecified-high`, T10 -> `visual-engineering`, T11/T12 -> `quick` |
| 3 | 3 | T14 -> `unspecified-high`, T15/T16 -> `deep` |
| FINAL | 4 | F1 -> `oracle-equivalent`, F2/F3 -> `unspecified-high`, F4 -> `deep` |

---

## TODOs

- [ ] 1. Baseline Snapshot and Rollback Anchors

  **What to do**:
  - Capture current desktop generations and current-system symlink target.
  - Create timestamped backup of `/etc/nixos` before refactor.
  - Record restoration commands in evidence.

  **Must NOT do**:
  - Do not modify active boot generation.
  - Do not run `switch`.

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: bounded command/task orchestration.
  - **Skills**: `git-master`
    - `git-master`: ensures safe checkpoint workflow before invasive refactor.
  - **Skills Evaluated but Omitted**:
    - `playwright`: no browser workflow involved.

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1
  - **Blocks**: 16
  - **Blocked By**: None

  **References**:
  - `/etc/nixos/flake.nix:1` - current root flake baseline for rollback scope.
  - `/etc/nixos/hardware-configuration.nix:1` - desktop recovery-critical file.
  - `https://wiki.nixos.org/wiki/Nixos-rebuild` - generation and rollback behavior.

  **Acceptance Criteria**:
  - [ ] Evidence includes generation list and backup path.
  - [ ] Rollback commands documented in evidence file.

  **QA Scenarios**:
  ```text
  Scenario: Baseline captured successfully
    Tool: Bash
    Preconditions: Repository is readable at /etc/nixos
    Steps:
      1. Run: sudo nixos-rebuild list-generations | tee .sisyphus/evidence/task-1-generations.txt
      2. Run: readlink -f /run/current-system | tee .sisyphus/evidence/task-1-current-system.txt
      3. Run: sudo cp -a /etc/nixos /etc/nixos.pre-unify.$(date +%Y%m%d-%H%M)
    Expected Result: evidence files exist; backup directory exists
    Failure Indicators: missing evidence file, cp error, empty generation output
    Evidence: .sisyphus/evidence/task-1-generations.txt

  Scenario: Guard against accidental activation
    Tool: Bash
    Preconditions: none
    Steps:
      1. Search command history/script for `nixos-rebuild switch` in task logs
      2. Confirm no switch command executed during Task 1
    Expected Result: zero switch execution entries
    Evidence: .sisyphus/evidence/task-1-no-switch.txt
  ```

  **Commit**: YES
  - Message: `chore(migration): capture pre-unification rollback anchors`
  - Files: `.sisyphus/evidence/task-1-*`
  - Pre-commit: `git status`

- [ ] 2. Unified Flake Skeleton and 25.11 Alignment

  **What to do**:
  - Define unified flake outputs: `nixosConfigurations.desktop`, `nixosConfigurations.wsl`, `homeConfigurations.darwin`.
  - Align `nixpkgs` and `home-manager` to 25.11 branch.
  - Keep `nixos-wsl` input and scope it to WSL host graph only.

  **Must NOT do**:
  - Do not remove desktop-specific inputs needed by existing config.
  - Do not leave host output name collision (`nixos`).

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: topology-level change affecting all downstream tasks.
  - **Skills**: `git-master`
    - `git-master`: safe incremental commits for root flake changes.
  - **Skills Evaluated but Omitted**:
    - `frontend-ui-ux`: irrelevant for infra config.

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1
  - **Blocks**: 3, 4, 5, 6, 7, 8, 13, 15
  - **Blocked By**: None

  **References**:
  - `/etc/nixos/flake.nix:23` - current desktop flake output shape.
  - `/home/see2et/repos/nixos-wsl/flake.nix:56` - existing WSL output/module wiring pattern.
  - `/home/see2et/repos/nixos-wsl/flake.nix:124` - existing Darwin HM output to preserve.
  - `https://nix-community.github.io/NixOS-WSL/how-to/nix-flakes.html` - official WSL flake integration pattern.

  **Acceptance Criteria**:
  - [ ] `nix eval .#nixosConfigurations.desktop.config.system.stateVersion` succeeds.
  - [ ] `nix eval .#nixosConfigurations.wsl.config.wsl.enable` succeeds.
  - [ ] `nix eval .#homeConfigurations.darwin.activationPackage.drvPath` succeeds.

  **QA Scenarios**:
  ```text
  Scenario: Outputs evaluate for all targets
    Tool: Bash
    Preconditions: flake.nix updated
    Steps:
      1. Run: nix eval .#nixosConfigurations.desktop.config.system.stateVersion
      2. Run: nix eval .#nixosConfigurations.wsl.config.wsl.enable
      3. Run: nix eval .#homeConfigurations.darwin.activationPackage.drvPath
    Expected Result: all commands return value, exit code 0
    Failure Indicators: missing attr errors, evaluation failure
    Evidence: .sisyphus/evidence/task-2-eval.txt

  Scenario: No ambiguous host key left
    Tool: Bash
    Preconditions: flake updated
    Steps:
      1. Run: nix flake show | tee .sisyphus/evidence/task-2-flake-show.txt
      2. Assert outputs include `desktop` and `wsl` keys
    Expected Result: explicit host keys present
    Evidence: .sisyphus/evidence/task-2-flake-show.txt
  ```

  **Commit**: YES
  - Message: `refactor(flake): add desktop/wsl hosts and darwin hm output`
  - Files: `flake.nix`, `flake.lock`
  - Pre-commit: `nix flake check --show-trace`

- [ ] 3. Desktop Host Scaffolding
  **What to do**: create `hosts/desktop/default.nix` and move desktop entry imports there.
  **Must NOT do**: do not change hardware UUID/filesystem settings.
  **Recommended Agent Profile**: `quick` + `git-master`.
  **Parallelization**: YES, Wave 1; Blocks 7,10; Blocked by 2.
  **References**: `/etc/nixos/configuration.nix:14`, `/etc/nixos/hardware-configuration.nix:16`.
  **Acceptance Criteria**: `nix eval .#nixosConfigurations.desktop.config.networking.networkmanager.enable` succeeds.
  **QA Scenarios**:
  ```text
  Scenario: Desktop host module imports resolve
    Tool: Bash
    Steps: run `nix eval .#nixosConfigurations.desktop.config.system.stateVersion`
    Expected Result: evaluation succeeds
    Evidence: .sisyphus/evidence/task-3-desktop-eval.txt
  Scenario: Hardware config still wired
    Tool: Bash
    Steps: run `nix eval .#nixosConfigurations.desktop.config.fileSystems."/".fsType`
    Expected Result: returns ext4 (or existing value)
    Evidence: .sisyphus/evidence/task-3-hw.txt
  ```
  **Commit**: YES (`refactor(hosts): scaffold desktop host entry`).

- [ ] 4. WSL Host Scaffolding
  **What to do**: create `hosts/wsl/default.nix`; import `nixos-wsl` module only here.
  **Must NOT do**: do not expose `wsl.*` options in common/desktop modules.
  **Recommended Agent Profile**: `quick` + `git-master`.
  **Parallelization**: YES, Wave 1; Blocks 8,11; Blocked by 2.
  **References**: `/home/see2et/repos/nixos-wsl/flake.nix:88`, `/home/see2et/repos/nixos-wsl/flake.nix:91`.
  **Acceptance Criteria**: `nix eval .#nixosConfigurations.wsl.config.wsl.enable` returns true.
  **QA Scenarios**:
  ```text
  Scenario: WSL module active for wsl host
    Tool: Bash
    Steps: run `nix eval .#nixosConfigurations.wsl.config.wsl.enable`
    Expected Result: true
    Evidence: .sisyphus/evidence/task-4-wsl-enable.txt
  Scenario: WSL module absent on desktop
    Tool: Bash
    Steps: run `nix eval .#nixosConfigurations.desktop.config.wsl.enable` and expect failure
    Expected Result: attribute missing/error (no leakage)
    Evidence: .sisyphus/evidence/task-4-no-leak.txt
  ```
  **Commit**: YES (`refactor(hosts): scaffold wsl host entry`).

- [ ] 5. Home Tree Scaffolding
  **What to do**: create `home/common`, `home/linux`, `home/wsl`, `home/darwin` and import graph.
  **Must NOT do**: do not delete current working HM modules before replacement is wired.
  **Recommended Agent Profile**: `quick` + `git-master`.
  **Parallelization**: YES, Wave 1; Blocks 9,10,11,12; Blocked by 2.
  **References**: `/home/see2et/repos/nixos-wsl/home.nix:3`.
  **Acceptance Criteria**: `nix eval .#homeConfigurations.darwin.activationPackage.drvPath` still resolves.
  **QA Scenarios**:
  ```text
  Scenario: Home split tree import resolves
    Tool: Bash
    Steps: run `nix build .#homeConfigurations.darwin.activationPackage`
    Expected Result: build succeeds
    Evidence: .sisyphus/evidence/task-5-darwin-build.txt
  Scenario: Missing submodule is caught
    Tool: Bash
    Steps: temporarily remove one import in working tree check and run eval
    Expected Result: explicit import error captured
    Evidence: .sisyphus/evidence/task-5-negative-import.log
  ```
  **Commit**: YES (`refactor(home): scaffold platform split directories`).

- [ ] 6. Shared Module Extraction Baseline
  **What to do**: extract safe shared settings (`nix.settings`, shell/gpg common), leaving platform-sensitive opts out.
  **Must NOT do**: no bootloader/GPU/display/WSL interop in shared module.
  **Recommended Agent Profile**: `unspecified-high` + `git-master`.
  **Parallelization**: YES, Wave 1; Blocks 7,8,9; Blocked by 2.
  **References**: `/etc/nixos/configuration.nix:93`, `/home/see2et/repos/nixos-wsl/configuration.nix:23`.
  **Acceptance Criteria**: both desktop/wsl eval succeed after shared extraction.
  **QA Scenarios**:
  ```text
  Scenario: Shared module applies to both hosts
    Tool: Bash
    Steps:
      1. `nix eval .#nixosConfigurations.desktop.config.nix.settings.experimental-features`
      2. `nix eval .#nixosConfigurations.wsl.config.nix.settings.experimental-features`
    Expected Result: both return list including nix-command and flakes
    Evidence: .sisyphus/evidence/task-6-shared-eval.txt
  Scenario: Platform-sensitive options absent from shared
    Tool: Bash
    Steps: grep shared module files for `boot.loader`, `hardware.nvidia`, `wsl.`
    Expected Result: no matches
    Evidence: .sisyphus/evidence/task-6-no-sensitive.txt
  ```
  **Commit**: YES (`refactor(modules): extract safe shared nixos baseline`).

- [ ] 7. Desktop System Migration
  **What to do**: migrate desktop-only settings (boot/filesystems/gdm/niri/nvidia/audio/vr/firewall) into `modules/nixos/desktop/*`.
  **Must NOT do**: do not weaken or remove existing desktop safety-critical settings.
  **Recommended Agent Profile**: `deep` + `git-master`.
  **Parallelization**: YES, Wave 2; Blocks 14,15,16; Blocked by 3,6.
  **References**: `/etc/nixos/configuration.nix:19`, `/etc/nixos/configuration.nix:87`, `/etc/nixos/configuration.nix:171`, `/etc/nixos/configuration.nix:214`.
  **Acceptance Criteria**: desktop toplevel builds and key options evaluate.
  **QA Scenarios**:
  ```text
  Scenario: Desktop stack preserved in eval
    Tool: Bash
    Steps:
      1. `nix eval .#nixosConfigurations.desktop.config.services.displayManager.gdm.enable`
      2. `nix eval .#nixosConfigurations.desktop.config.hardware.nvidia.open`
      3. `nix eval .#nixosConfigurations.desktop.config.services.pipewire.enable`
    Expected Result: expected truthy values
    Evidence: .sisyphus/evidence/task-7-desktop-options.txt
  Scenario: Desktop build regression detected
    Tool: Bash
    Steps: `nix build .#nixosConfigurations.desktop.config.system.build.toplevel`
    Expected Result: success; failure log saved otherwise
    Evidence: .sisyphus/evidence/task-7-desktop-build.log
  ```
  **Commit**: YES (`refactor(desktop): isolate desktop-only system modules`).

- [ ] 8. WSL System Migration
  **What to do**: migrate WSL-only settings (`nix-ld`, `allowUnsupportedSystem`, `usbip`, WSL options) into `modules/nixos/wsl/*`.
  **Must NOT do**: do not place WSL options in common module tree.
  **Recommended Agent Profile**: `unspecified-high` + `git-master`.
  **Parallelization**: YES, Wave 2; Blocks 14,15; Blocked by 4,6.
  **References**: `/home/see2et/repos/nixos-wsl/configuration.nix:28`, `/home/see2et/repos/nixos-wsl/configuration.nix:38`, `/home/see2et/repos/nixos-wsl/flake.nix:93`.
  **Acceptance Criteria**: WSL host builds and WSL attrs evaluate.
  **QA Scenarios**:
  ```text
  Scenario: WSL-specific options active on wsl host
    Tool: Bash
    Steps:
      1. `nix eval .#nixosConfigurations.wsl.config.programs.nix-ld.enable`
      2. `nix eval .#nixosConfigurations.wsl.config.wsl.usbip.enable`
    Expected Result: true values
    Evidence: .sisyphus/evidence/task-8-wsl-options.txt
  Scenario: WSL options absent on desktop host
    Tool: Bash
    Steps: `nix eval .#nixosConfigurations.desktop.config.programs.nix-ld.enable`
    Expected Result: false or missing attr; no positive leakage
    Evidence: .sisyphus/evidence/task-8-no-desktop-leak.txt
  ```
  **Commit**: YES (`refactor(wsl): isolate wsl-only system modules`).

- [ ] 9. Home Common Migration
  **What to do**: migrate reusable HM modules (`programs/git`, `gh`, `gpg`, `zsh` core, neutral files) into `home/common`.
  **Must NOT do**: do not include `/mnt/c` or WSL notifier in common.
  **Recommended Agent Profile**: `unspecified-high` + `git-master`.
  **Parallelization**: YES, Wave 2; Blocks 13,14,15; Blocked by 5,6.
  **References**: `/home/see2et/repos/nixos-wsl/home/programs/git.nix:4`, `/home/see2et/repos/nixos-wsl/home/programs/zsh/default.nix:9`.
  **Acceptance Criteria**: common HM modules evaluate for desktop/wsl/darwin targets.
  **QA Scenarios**:
  ```text
  Scenario: Common HM modules reusable across targets
    Tool: Bash
    Steps:
      1. Build darwin activation package
      2. Evaluate desktop HM user config attr path
      3. Evaluate wsl HM user config attr path
    Expected Result: all evaluations/build succeed
    Evidence: .sisyphus/evidence/task-9-common-hm.txt
  Scenario: WSL path leakage prevented
    Tool: Bash
    Steps: grep home/common for `/mnt/c` and `opencode-wsl-notify`
    Expected Result: no matches
    Evidence: .sisyphus/evidence/task-9-no-wsl-in-common.txt
  ```
  **Commit**: YES (`refactor(home): extract common HM modules`).

- [ ] 10. Desktop Home Manager Migration
  **What to do**: move desktop HM UI/wayland stack from `/etc/nixos/home.nix` into `home/desktop/*`.
  **Must NOT do**: do not make desktop UI modules mandatory for wsl/darwin.
  **Recommended Agent Profile**: `visual-engineering` + `git-master`.
  **Parallelization**: YES, Wave 2; Blocks 13,14,15; Blocked by 3,5.
  **References**: `/etc/nixos/home.nix:12`, `/etc/nixos/home.nix:68`, `/etc/nixos/home.nix:278`.
  **Acceptance Criteria**: desktop HM config builds; no desktop UI options in wsl/darwin HM outputs.
  **QA Scenarios**:
  ```text
  Scenario: Desktop HM build includes niri/waybar settings
    Tool: Bash
    Steps: evaluate desktop HM attrs for `programs.waybar.enable` and `programs.niri.settings`
    Expected Result: attrs exist and enabled
    Evidence: .sisyphus/evidence/task-10-desktop-hm.txt
  Scenario: Desktop UI not required on WSL
    Tool: Bash
    Steps: evaluate wsl HM attrs for same keys
    Expected Result: absent or disabled
    Evidence: .sisyphus/evidence/task-10-no-wsl-ui.txt
  ```
  **Commit**: YES (`refactor(home-desktop): isolate desktop HM UI modules`).

- [ ] 11. WSL Home Manager Migration
  **What to do**: move WSL-specific HM pieces to `home/wsl` (`/mnt/c` PATH, notifier, optional WSL-only package set).
  **Must NOT do**: do not include these in desktop/darwin import chain.
  **Recommended Agent Profile**: `quick` + `git-master`.
  **Parallelization**: YES, Wave 2; Blocks 13,14,15; Blocked by 4,5.
  **References**: `/home/see2et/repos/nixos-wsl/home/session.nix:9`, `/home/see2et/repos/nixos-wsl/home/files.nix:25`.
  **Acceptance Criteria**: WSL HM output includes WSL path/notifier; desktop/darwin do not.
  **QA Scenarios**:
  ```text
  Scenario: WSL HM includes Windows path
    Tool: Bash
    Steps: evaluate wsl HM session variables PATH
    Expected Result: includes `/mnt/c/Users/See2et/.../VS Code/bin`
    Evidence: .sisyphus/evidence/task-11-wsl-path.txt
  Scenario: Desktop HM excludes Windows path
    Tool: Bash
    Steps: evaluate desktop HM session variables PATH
    Expected Result: no `/mnt/c` segment
    Evidence: .sisyphus/evidence/task-11-no-desktop-mntc.txt
  ```
  **Commit**: YES (`refactor(home-wsl): isolate wsl-only HM modules`).

- [ ] 12. Darwin Home Manager Preservation
  **What to do**: keep darwin HM output buildable, isolate darwin overrides in `home/darwin`, preserve `isDarwin` behavior.
  **Must NOT do**: do not add nix-darwin/system-level assumptions.
  **Recommended Agent Profile**: `quick` + `git-master`.
  **Parallelization**: YES, Wave 2; Blocks 13,15; Blocked by 5.
  **References**: `/home/see2et/repos/nixos-wsl/flake.nix:124`, `/home/see2et/repos/nixos-wsl/home/core.nix:4`, `/home/see2et/repos/nixos-wsl/home/programs/zsh/abbreviations.nix:18`.
  **Acceptance Criteria**: darwin activation package builds; darwin-specific command alias resolves to darwin target.
  **QA Scenarios**:
  ```text
  Scenario: Darwin HM activation remains buildable
    Tool: Bash
    Steps: `nix build .#homeConfigurations.darwin.activationPackage`
    Expected Result: build success
    Evidence: .sisyphus/evidence/task-12-darwin-build.log
  Scenario: No accidental nixos-rebuild target in darwin alias
    Tool: Bash
    Steps: inspect generated/declared `re` abbreviation for darwin branch
    Expected Result: darwin branch uses home-manager command
    Evidence: .sisyphus/evidence/task-12-alias.txt
  ```
  **Commit**: YES (`refactor(darwin-hm): preserve darwin home output`).

- [ ] 13. Flake Wiring for HM Users and Args
  **What to do**: wire per-host HM users and `extraSpecialArgs` (`isDarwin`, host id, toolchain args).
  **Must NOT do**: do not force username/homeDirectory from one platform onto another.
  **Recommended Agent Profile**: `deep` + `git-master`.
  **Parallelization**: YES, Wave 2; Blocks 14,15; Blocked by 2,9,10,11,12.
  **References**: `/etc/nixos/flake.nix:37`, `/home/see2et/repos/nixos-wsl/flake.nix:104`, `/home/see2et/repos/nixos-wsl/home/core.nix:4`.
  **Acceptance Criteria**: desktop/wsl/darwin HM outputs evaluate with correct user/home directories.
  **QA Scenarios**:
  ```text
  Scenario: Host-specific user/home resolution
    Tool: Bash
    Steps:
      1. Evaluate desktop HM `home.username`
      2. Evaluate wsl HM `home.username`
      3. Evaluate darwin HM `home.homeDirectory`
    Expected Result: desktop/wsl/darwin each match intended values
    Evidence: .sisyphus/evidence/task-13-user-resolution.txt
  Scenario: Cross-host identity drift blocked
    Tool: Bash
    Steps: assert desktop username is not `nixos` unless explicitly configured
    Expected Result: mismatch check fails if unintended drift occurred
    Evidence: .sisyphus/evidence/task-13-negative-drift.txt
  ```
  **Commit**: YES (`refactor(flake-hm): wire host-specific hm args and users`).

- [ ] 14. Guardrails + Stale Import Cleanup
  **What to do**: add explicit anti-leak guardrails and clean obsolete import paths.
  **Must NOT do**: do not remove recovery-critical files before replacements verified.
  **Recommended Agent Profile**: `unspecified-high` + `git-master`.
  **Parallelization**: NO; Wave 3; Blocks 15,16; Blocked by 7,8,9,10,11,13.
  **References**: `/etc/nixos/hardware-configuration.nix:1`, `/home/see2et/repos/nixos-wsl/home/session.nix:9`.
  **Acceptance Criteria**: no stale imports; guardrail checks pass.
  **QA Scenarios**:
  ```text
  Scenario: No stale import paths remain
    Tool: Bash
    Steps: grep for removed paths/import targets across flake and modules
    Expected Result: zero matches for removed paths
    Evidence: .sisyphus/evidence/task-14-no-stale-imports.txt
  Scenario: WSL options blocked on desktop
    Tool: Bash
    Steps: evaluate desktop `config.wsl` attr
    Expected Result: absent/error or explicit disabled state
    Evidence: .sisyphus/evidence/task-14-desktop-no-wsl.txt
  ```
  **Commit**: YES (`chore(guardrails): enforce host boundaries and remove stale imports`).

- [ ] 15. Non-Activating Verification Suite
  **What to do**: run full eval/build checks for all outputs without activation.
  **Must NOT do**: do not run `switch` in this task.
  **Recommended Agent Profile**: `deep` + `git-master`.
  **Parallelization**: NO; Wave 3; Blocks 16, F1-F4; Blocked by 2,7,8,9,10,11,12,13,14.
  **References**: `https://wiki.nixos.org/wiki/Nixos-rebuild`, `https://nix-community.github.io/NixOS-WSL/how-to/nix-flakes.html`.
  **Acceptance Criteria**:
  - [ ] `nix flake check --show-trace`
  - [ ] `nix build .#nixosConfigurations.desktop.config.system.build.toplevel`
  - [ ] `nix build .#nixosConfigurations.wsl.config.system.build.toplevel`
  - [ ] `nix build .#homeConfigurations.darwin.activationPackage`

  **QA Scenarios**:
  ```text
  Scenario: All non-activating builds pass
    Tool: Bash
    Steps:
      1. Run flake check
      2. Build desktop toplevel
      3. Build wsl toplevel
      4. Build darwin activation package
    Expected Result: all commands exit 0
    Evidence: .sisyphus/evidence/task-15-build-suite.log

  Scenario: Failure is captured with trace
    Tool: Bash
    Steps: rerun failed command with `--show-trace` if any step fails
    Expected Result: actionable error trace saved
    Evidence: .sisyphus/evidence/task-15-failure-trace.log
  ```

  **Commit**: YES (`test(infra): add passing evidence for unified flake outputs`).

- [ ] 16. Activation-Gated Rollout and Rollback Proof
  **What to do**:
  - Enforce mandatory desktop gate sequence:
    1. `sudo nixos-rebuild dry-activate --flake .#desktop`
    2. `sudo nixos-rebuild test --flake .#desktop`
    3. `sudo nixos-rebuild test --flake .#wsl`
  - Only if all pass: `sudo nixos-rebuild switch --flake .#desktop`
  - Record rollback execution path.

  **Must NOT do**:
  - Do not bypass gate order.
  - Do not switch desktop if `dry-activate` or `test` fails.

  **Recommended Agent Profile**:
  - **Category**: `deep`
  - **Skills**: `git-master`
  - **Skills Evaluated but Omitted**: `playwright` (no browser validation needed)

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 3 sequential finish
  - **Blocks**: F1-F4
  - **Blocked By**: 1,7,14,15

  **References**:
  - `https://wiki.nixos.org/wiki/Nixos-rebuild` - `dry-activate`, `test`, `switch`, rollback semantics.
  - `/etc/nixos/.sisyphus/drafts/nixos-unification.md:65` - agreed gate policy.

  **Acceptance Criteria**:
  - [ ] Gate logs show `dry-activate` then `test` succeeded before any `switch`.
  - [ ] If any gate fails, rollback path is executed/documented.

  **QA Scenarios**:
  ```text
  Scenario: Mandatory gate sequence enforced
    Tool: Bash
    Preconditions: Task 15 complete
    Steps:
      1. Run desktop dry-activate and log output
      2. Run desktop test and log output
      3. Verify no switch command appears before both pass
    Expected Result: strict sequence respected
    Evidence: .sisyphus/evidence/task-16-gate-sequence.log

  Scenario: Rollback path executable when gate fails
    Tool: Bash
    Preconditions: simulated failure or prior failed generation
    Steps:
      1. Run `sudo nixos-rebuild list-generations`
      2. Run rollback command (or dry-run documented equivalent)
      3. Capture resulting generation state
    Expected Result: rollback target/command validated
    Evidence: .sisyphus/evidence/task-16-rollback.log
  ```

  **Commit**: YES
  - Message: `chore(release): enforce activation gates and rollback playbook`
  - Files: `.sisyphus/evidence/task-16-*`, runbook markdown
  - Pre-commit: `nix flake check --show-trace`

---

## Final Verification Wave (MANDATORY)

- [ ] F1. **Plan Compliance Audit** — `oracle-equivalent`
  Verify each Must Have/Must NOT Have against code + command evidence, output APPROVE/REJECT with file references.

- [ ] F2. **Configuration Quality Review** — `unspecified-high`
  Re-run `nix flake check`, targeted builds, and inspect for stale imports, dead modules, unsafe leakage patterns.

- [ ] F3. **Real Execution QA Replay** — `unspecified-high`
  Replay all task QA scenarios from clean shell session and verify evidence files exist and are current.

- [ ] F4. **Scope Fidelity Check** — `deep`
  Validate migration changed only agreed scope; no accidental nix-darwin system migration and no desktop safety-domain regression.

---

## Commit Strategy

| After Task(s) | Message | Files | Verification |
|---------------|---------|-------|--------------|
| 1 | `chore(migration): capture pre-unification rollback anchors` | evidence/runbook | `git status` |
| 2-6 | `refactor(flake): scaffold unified multi-host layout` | flake + new dirs | `nix eval ...` |
| 7-13 | `refactor(modules): migrate desktop/wsl/darwin home+system modules` | hosts/modules/home | `nix build ...` |
| 14-16 | `chore(release): enforce guardrails and rollout gates` | guardrails + evidence | `nix flake check --show-trace` |

---

## Success Criteria

### Verification Commands
```bash
nix flake check --show-trace
nix build .#nixosConfigurations.desktop.config.system.build.toplevel
nix build .#nixosConfigurations.wsl.config.system.build.toplevel
nix build .#homeConfigurations.darwin.activationPackage
sudo nixos-rebuild dry-activate --flake .#desktop
sudo nixos-rebuild test --flake .#desktop
sudo nixos-rebuild test --flake .#wsl
```

### Final Checklist
- [ ] Desktop safety domains preserved (boot/filesystem/GPU/display/audio)
- [ ] WSL settings isolated to WSL host
- [ ] Darwin HM output remains buildable
- [ ] Mandatory desktop gate (`dry-activate` + `test`) enforced before `switch`
- [ ] Rollback path verified and documented
