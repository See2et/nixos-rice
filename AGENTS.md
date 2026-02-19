# AGENTS.md — /etc/nixos Knowledge Base

## Overview

This is a unified NixOS flake repo managing three targets from a single source of truth:
- **Desktop** (`nixosConfigurations.desktop`) — NixOS x86_64-linux workstation
- **WSL** (`nixosConfigurations.wsl`) — NixOS-WSL under Windows
- **Darwin** (`homeConfigurations.darwin`) — Home Manager only on aarch64-darwin (no nix-darwin)

## Architecture

```
flake.nix                         # Single entry point — all outputs defined here
├── hosts/
│   ├── desktop/default.nix       # Desktop host wiring (imports hw, desktop modules, niri, nvidia, HM)
│   └── wsl/default.nix           # WSL host wiring (imports nixos-wsl, HM)
├── modules/nixos/
│   ├── common/default.nix        # Shared NixOS baseline (nix settings, zsh, gpg)
│   ├── desktop/                  # Desktop-only system: system, boot, gdm, nvidia, audio, vr, firewall, niri, filesystems
│   └── wsl/default.nix           # WSL-only system: nix-ld, usbip, allowUnsupportedSystem
├── home/
│   ├── common/                   # Shared HM: git, gh, gpg, zsh, packages, session, catppuccin
│   ├── linux/default.nix         # Linux-only HM packages (wl-clipboard, xclip, libnotify)
│   ├── desktop/                  # Desktop HM: niri, waybar, xdg, desktop packages
│   ├── wsl/                      # WSL HM: /mnt/c PATH, notifier files
│   └── darwin/default.nix        # Darwin HM: placeholder + isDarwin assertion
├── hardware-configuration.nix    # Desktop hardware — imported ONLY by hosts/desktop
└── home/                         # Modular Home Manager tree (common/linux/desktop/wsl/darwin)
```

## Critical Safety Rules for /etc/nixos

### 1. NEVER run `nixos-rebuild switch` without the user's explicit manual action

This repo lives at `/etc/nixos` — the live NixOS system configuration. `switch` and `test` can affect the running system immediately. `dry-activate` is a lower-risk preflight check, but it still executes activation logic in dry mode. During this migration, a subagent ran `nixos-rebuild switch` without authorization, triggering a reboot and login lockout.

**Mandatory protocol:**
- Build and eval are always safe: `nix build`, `nix eval`, `nix flake check`
- Agent automation may run `dry-activate` only (never delegate this to subagents)
- Activation commands `test` and `switch` are **user-only**
- Always follow the gate sequence: `dry-activate` → `test` → `switch`

### 2. Generation-based rollback is your safety net

```bash
# Rollback to previous generation (immediate)
sudo nixos-rebuild switch --profile /nix/var/nix/profiles/system --rollback

# Full restore from pre-unification backup
sudo cp -a /etc/nixos.pre-unify.20260217-1732 /etc/nixos
sudo nixos-rebuild switch --flake /etc/nixos#desktop
```

Current baseline: **Generation 105**. Pre-unification backup exists at `/etc/nixos.pre-unify.20260217-1732`.

### 3. `git add` before `nix eval`/`nix build`

Flakes use the git-tracked working tree. Newly created `.nix` files are invisible to the evaluator until staged:
```bash
git add path/to/new/module.nix
nix eval .#nixosConfigurations.desktop.config.some.option  # now sees the file
```

This is the most common failure mode when creating new modules. If you see `path '/nix/store/…/module' does not exist`, it means the file isn't staged.

### 4. User `see2et` has no declarative password

`users.users.see2et` in `modules/nixos/desktop/system.nix` uses `isNormalUser = true` without `hashedPassword` or `initialPassword`. If GDM restarts (e.g., during `switch`), the user must already have a password set via `passwd`. Consider adding `hashedPasswordFile` to prevent future lockouts.

## Host Isolation Boundaries

The most important architectural invariant: **hosts must not leak into each other**.

| Rule | Enforced by |
|------|-------------|
| Desktop must NOT import `nixos-wsl`, `modules/nixos/wsl`, or `home/wsl` | `hosts/desktop/default.nix` GUARDRAIL comments + structural import graph |
| WSL must NOT import `modules/nixos/desktop`, `home/desktop`, or `hardware-configuration.nix` | `hosts/wsl/default.nix` import list |
| `/mnt/c` paths must NOT appear in `home/common/` or `modules/nixos/common/` | WSL PATH is in `home/wsl/session.nix` only |
| `hardware-configuration.nix` must NOT be in `modules/nixos/common/` | Imported only by `hosts/desktop/default.nix` |
| Darwin remains HM-only — no `darwinConfigurations` or `nix-darwin` | `flake.nix` exposes only `homeConfigurations.darwin` |

**Verification command:**
```bash
# Check WSL leakage into desktop
grep -rn 'modules/nixos/wsl\|home/wsl\|nixos-wsl\|/mnt/c' hosts/desktop/ home/common/ modules/nixos/common/
# Should return only comments, never actual imports
```

## Non-Destructive Development Patterns

### Safe verification commands (run freely)

```bash
nix flake check --show-trace                                          # Validate all outputs
nix build .#nixosConfigurations.desktop.config.system.build.toplevel  # Build desktop (no activation)
nix build .#nixosConfigurations.wsl.config.system.build.toplevel      # Build WSL
nix eval .#nixosConfigurations.desktop.config.services.pipewire.enable # Inspect any option
nix eval .#homeConfigurations.darwin.activationPackage.drvPath         # Darwin eval (build requires aarch64)
```

### Module development workflow

1. Create/edit `.nix` files
2. `git add` new files (required for flake visibility)
3. `nix flake check --show-trace` — catches type errors, missing imports, option conflicts
4. `nix eval` specific options to verify behavior
5. `nix build` toplevel to ensure full system builds
6. Only then: agent may run `dry-activate`; user manually runs `test` and `switch`

### Desktop rice QA checklist (T3-2)

Run this lightweight checklist after any desktop theme/token/wallpaper change:
- Typography: Waybar, launcher, notifications, and lock/power UI use consistent font family/scale (no accidental fallback fonts).
- Spacing: paddings, gaps, and corner radii remain visually consistent across bar, launcher, notifications, and lock/power surfaces.
- Contrast: text/icons stay readable for normal + urgent states against the current wallpaper/background.
- Interaction latency: launcher, power menu, lock, and OSD feedback appear quickly and without visible stutter.
- Toolkit consistency: check at least one GTK app and one Qt app for icon, cursor, and theme parity.
- Before/after: capture the same three scenes (idle desktop, launcher open, notification + OSD) and compare side-by-side before accepting changes.

### Adding a new shared module

```nix
# home/common/programs/new-tool.nix
{ pkgs, ... }:
{
  programs.new-tool.enable = true;
}
```

Then import it from `home/common/default.nix`:
```nix
imports = [
  # ... existing imports ...
  ./programs/new-tool.nix
];
```

All three targets (desktop, WSL, darwin) will inherit it automatically.

### Adding a platform-specific module

Place it under the platform directory and import from that platform's `default.nix`:
- Desktop-only → `home/desktop/` or `modules/nixos/desktop/`
- WSL-only → `home/wsl/` or `modules/nixos/wsl/`
- Darwin-only → `home/darwin/`
- Linux-only (desktop + WSL) → `home/linux/`

### Platform-conditional logic in shared modules

Use the `isDarwin` parameter (available via `extraSpecialArgs`):
```nix
{ isDarwin, pkgs, ... }:
{
  home.packages = if isDarwin then [ pkgs.darwin-tool ] else [ pkgs.linux-tool ];
}
```

## Key Parameters in `extraSpecialArgs`

All HM modules receive these via `extraSpecialArgs`:
- `inputs` — all flake inputs
- `isDarwin` — `true` for darwin, `false` for desktop/WSL
- `hostId` — `"desktop"`, `"wsl"`, or `"darwin"`
- `rustToolchain` — `pkgs.rustc` for the target platform

## Maintainability Insights

### What went well
- **Atomic commits per task** made rollback and debugging trivial
- **Evidence logs** (`.sisyphus/evidence/task-*`) provided auditable proof at every step
- **Guardrail comments** at module headers prevent accidental cross-host imports
- **`nix flake check` as the universal gate** catches option conflicts, missing imports, and type errors before anything touches the system
- **Scaffolding before migration** — creating empty module structure first, then populating, avoids import graph breakage

### What went wrong
- **Subagent ran destructive command** — even with explicit MUST NOT instructions. Lesson: never delegate system-affecting commands
- **Scope creep in Task 9** — dotfile trees were incorrectly included in "common HM modules" scope, requiring cleanup commit
- **Duplicate option declarations** (Task 10) — importing a module AND setting the same option causes flake check failure. Always let the module own its options
- **Stale imports** (Task 14) — `home.nix` was still imported after its contents were migrated, causing subtle duplication

### Patterns for future changes
1. **One concern per file** — `boot.nix`, `nvidia.nix`, `audio.nix` etc. are independently testable
2. **Host files are wiring, not logic** — `hosts/*/default.nix` only `imports` and sets identity (username, homeDirectory, stateVersion)
3. **Common modules must be platform-agnostic** — if it references `/mnt/c`, Wayland, or `hardware-configuration.nix`, it doesn't belong in `common/`
4. **Modular files are canonical** — all new work goes into `modules/nixos/*` and `home/*`; avoid reintroducing root-level monolith files

## Remaining Work

- [ ] Execute rollout gate interactively on host: `sudo nixos-rebuild dry-activate --flake /etc/nixos#desktop`, then user `test` → `switch` (blocked here: non-interactive sudo/systemd auth)
- [ ] Add `hashedPasswordFile` for `users.users.see2et` once a secure secret path/mechanism is provided
- [ ] Darwin HM build verification on an actual aarch64-darwin machine
