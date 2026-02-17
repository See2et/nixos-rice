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
