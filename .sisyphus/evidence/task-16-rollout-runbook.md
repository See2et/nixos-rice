# Activation-Gated Rollout Runbook

## Pre-Requisites
- All non-activating verification passed (Task 15 evidence)
- `nix flake check --show-trace` passes
- Desktop and WSL toplevel builds succeed
- Current generation: 105 (baseline)

## Gate Sequence (MANDATORY ORDER)

### Step 1: Desktop Dry-Activate
```bash
sudo nixos-rebuild dry-activate --flake /etc/nixos#desktop 2>&1 | tee /tmp/gate-1-dry-activate.log
echo "Exit code: $?"
```
**STOP if exit code != 0. Do NOT proceed to Step 2.**

Review output for:
- Service restarts that may cause downtime
- Unexpected configuration changes
- Any warnings or errors

### Step 2: Desktop Test
```bash
sudo nixos-rebuild test --flake /etc/nixos#desktop 2>&1 | tee /tmp/gate-2-test.log
echo "Exit code: $?"
```
**STOP if exit code != 0. Do NOT proceed to Step 3.**

This activates the new configuration without making it the boot default.
Verify after activation:
- Display manager (GDM) is running: `systemctl status display-manager`
- User can log in
- Network is functional: `ping -c1 8.8.8.8`

### Step 3: Desktop Switch (Final)
```bash
sudo nixos-rebuild switch --flake /etc/nixos#desktop 2>&1 | tee /tmp/gate-3-switch.log
echo "Exit code: $?"
```

This makes the new configuration the boot default AND activates it.

### Step 4: Verify New Generation
```bash
sudo nixos-rebuild list-generations | head -5
readlink -f /run/current-system
```

## Rollback Procedures

### Immediate Rollback (if Step 2/3 causes issues)
```bash
# Rollback to previous generation
sudo nixos-rebuild switch --profile /nix/var/nix/profiles/system --rollback
```

### Full Restore (nuclear option)
```bash
sudo rm -rf /etc/nixos
sudo cp -a /etc/nixos.pre-unify.20260217-1732 /etc/nixos
sudo nixos-rebuild switch --flake /etc/nixos#desktop
```

### Boot-Time Recovery
If system fails to boot:
1. Select previous generation from GRUB boot menu
2. After booting, run rollback command above

## Known Considerations
- User `see2et` has no declarative password in NixOS config (`users.users.see2et` lacks `hashedPassword`). If GDM restarts, you may need to re-enter password.
- Consider adding `hashedPasswordFile` to prevent future lockout scenarios.
- Darwin HM build cannot be verified on x86_64-linux (platform limitation); eval passes.
