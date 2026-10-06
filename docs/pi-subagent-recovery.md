# Pi SubAgent continuation and recovery proposal

Status: decision proposal only. No fix, package change, settings change, or activation was implemented. The investigation read public/package source, declarative configuration and built activation/unit files, not personal auth, settings, sessions or history. No Pi inference, billing lookup, `/reload`, process restart, `test`, `switch`, `dry-activate` or activation was performed.

## Decision in brief

**Adopt durable terminal results plus bounded, session-scoped parent continuation first; add guarded native same-owner recovery second.** Do not treat increasing the ten-minute timeout or automatically launching a replacement worker as recovery.

A profile symlink replacement alone does not remove a running process's child sessions. Pi SubAgents 0.19.0 creates SDK child sessions inside the parent Pi process; these are not normally independent Pi OS processes. If the parent is terminated, all those live session objects disappear. A full NixOS switch can indirectly terminate the parent through service/session changes, but it is not synonymous with killing Pi, `/reload`, or expiring a completed record. This investigation proves the narrower profile-replacement behavior and the current eviction failure safely, not survival through a real switch.

Choose these defaults for implementation review:

- Preserve the existing ten-minute live-session cleanup and 100-tombstone cap. Capture results before releasing memory; managed result retention is independent of those bounds.
- Automatically continue only the originating active parent session/branch for a new terminal managed result, once per completion generation. Never auto-resume child work, auto-retry inference, or accept work automatically.
- Recovery after expiry/reload/restart is an explicit root operation, only for the original worker/designer conversation. Reviewers/adjudicators stay fresh.
- Native Pi authentication and the authorized GPT provider/model/thinking pins remain unchanged. Recovery must disclose unavailable pins rather than silently change route. Nothing here supplies an OS sandbox.

## What exists and why work gets stranded

Installed sources examined:

| Label | Immutable source |
|---|---|
| SubAgents | `/nix/store/0binq2ycxi4ljy9s7q40ijlajjwld2ni-pi-subagents-0.19.0/src/` |
| Astraeus | `/nix/store/6g3vbsdkk82ghr1vfqbs5dl9n2j73n0v-source/extensions/` |
| Pi 1.0.4 docs/examples | `/nix/store/rpga5vi5495pglblk0b57bcvrrp68dxz-pi-coding-agent-1.0.4/libexec/pi/` |
| Current switch source | `/nix/store/l8nvd2l5ahmc1x2k8af3nqygi0d4fxlz-switch-to-configuration-ng/src/main.rs` |

SubAgents `agent-manager.ts:428` sweeps every 60 seconds. `cleanup()` at 1470 excludes running/queued records, but removes any other record older than ten minutes **regardless of `resultConsumed`**. The exact cutoff survives; removal occurs at a later sweep. `removeRecord()` at 1429 detaches the session immediately, removes the map/startup entries, then shuts down the child. `tombstone()` at 1450 preserves a handle, native ID, type, description, session-file path and completion timestamp, not result bytes or an execution receipt. It requires both a handle and persisted session file and keeps at most 100 entries.

`clearCompleted(true)` spares unread completed records temporarily, but clears all tombstones; timer expiry still removes unread results. `index.ts:1097–1122` handles parent `session_shutdown` by aborting work, cancelling nudges, clearing workflow tasks and awaiting manager disposal. The child shutdown helper at `agent-manager.ts:344–360` emits `session_shutdown` with reason `quit` and then disposes, with a three-second ceiling. That reason is also used for eviction: it does **not** prove the root user quit.

SubAgents already nudges the parent: `index.ts:447–524` holds notifications for 200 ms, suppresses consumed results, and calls `pi.sendMessage(..., {deliverAs:"followUp", triggerTurn:true})`. Stale synchronous send errors are ignored. This is best-effort delivery, not a durable collection acknowledgement. Group notifications have the same limitation. A blanket extra wake-up hook would duplicate this mechanism.

Astraeus `core.mjs:284–328` currently collects from a live manager record. Missing records become `unavailable`, collected but invalid, and the task enters `needs-evidence`. `resume()` at 329 requires `record.session`; its error suggests native `@handle` recovery but does not bind the recovered record back into the managed job. SubAgents' tombstone mention path (`index.ts:951–1009`) opens the saved conversation using an ordinary spawn, therefore a **new native record ID**, not restoration of the old manager entry. It rejects missing sessions and role fallback, but is not a managed ownership/receipt recovery API.

`accept()` at `core.mjs:207` rejects an invalid latest implementation owner. This is an intentional fail-closed contract to preserve. Astraeus `index.ts` currently uses `agent_before_settle` only for UI status; it neither collects terminal evidence nor requests continuation.

Pi's documented boundaries matter: `agent_end` can precede queued/recovery work; `agent_before_settle` can request one continuation; `agent_settled` is notification-only. `extensions.md` says reload replaces the extension runtime and shutdown cleanup must handle reload, replacement and exit. `sdk.md` says session disposal aborts work and invalidates extension contexts. The compiled Pi package does not expose its core TypeScript source here; exact host queue/reload timing is documented behavior, **not a live Pi runtime test** in this report.

## NixOS: five different events, not one

The observed current system is `/nix/store/7gvljlf4a4ir91kh75ii5kixi5dppdsz-nixos-system-nixos-26.05.20260903.a5cc6f2`. Its configuration is evidence of the installed generation, not proof that concurrent working-tree edits were applied.

| Event | Live child session consequence | Confidence / limitation |
|---|---|---|
| Build/eval only | No runtime replacement | Does not activate anything |
| Replace system/HM profile symlink only | Running parent retains its already-loaded code/session objects; later launches use the new target | Synthetic parent/child test passed; not a Nix activation test |
| Pi `/reload` | Extension runtime replaced; current SubAgents shutdown path aborts/clears its manager. Durable parent history is not a live child registry | Source + Pi lifecycle docs; not executed |
| Quit/crash/restart Pi | In-process child objects do not survive; persisted conversation may be reopened, ephemeral conversation cannot | SDK/source contract; no real Pi restart |
| Completed-record expiry | Parent stays alive; completed child object/result record removed; active/queued children excluded | Actual manager-method extraction passed with fake clock |
| Full NixOS switch / HM activation | Profile replacement **and** activation/unit handling; can terminate Pi indirectly if its containing terminal/session/unit is stopped | Current source/unit inspection only; no live survival claim |

`packages/pi/default.nix` builds a wrapper with immutable `-e /nix/store/...` package paths. `home/common/programs/pi.nix` installs it as a home package, not a Pi systemd service. The installed `/etc/profiles/per-user/see2et/bin/pi` resolves to `/nix/store/bryjhzzsahrp75b7165i1r4jmb9f0j7v-pi-configured-1.0.4/bin/pi`, and its wrapper pins the examined SubAgents/Astraeus paths. There is no Pi-named system unit in the inspected generation. The system-wide `/run/current-system/sw/bin/pi` does not exist; Pi is in the per-user profile.

`nixos-rebuild-ng` installed source (`/nix/store/c1lg2lqk42pd0bfv21axvccadd1d599h-nixos-rebuild-ng-26.05/lib/python3.13/site-packages/nixos_rebuild/`) separates these steps: `services.py:228–243` calls `set_profile()` then `switch_to_configuration()` for a non-rollback switch; `nix.py:669` sets the profile with `nix-env`, and 712 invokes the activation entry point. Neither was run.

The installed switch entry point wraps a compiled Rust binary. Its derivation identifies the switch source above; `main.rs:720–757` selects reload/skip/restart/stop-start according to changed unit metadata, 2233–2247 runs the activation script, and 2522+ actually submits restarts. The current system's `activate` script updates `/run/current-system`; a symlink update is only one part of activation.

The current `home-manager-see2et.service` is a oneshot with `RemainAfterExit=yes` and `X-StopIfChanged=false`: this means restart rather than stop/start when selected, **not** "HM never runs again". The current display-manager unit has `X-RestartIfChanged=false`; that reduces ordinary changed-unit restart risk but does not guarantee survival of a desktop session through every switch. Dependency stops, removed units, explicit activation hooks and other session services remain relevant. The current HM activation has `piNotifications`/`piCodeMode` configuration merges, role/home-file relinking, generation trimming and `sd-switch` user-unit handling. It has no explicit Pi restart hook. Those scripts were read, not executed; referenced personal files were not read.

A loaded old wrapper does not re-execute itself when the profile changes. `/reload` may reload old absolute CLI extension paths, not adopt the new wrapper's `-e` list. Do not promise that `/reload` upgrades the running executable. Generation pruning/GC and future lazy file loads are separate risks, not covered by the symlink test.

## Alternatives

| Alternative | Value | Weakness | Decision |
|---|---|---|---|
| Collect promptly; keep Pi open and avoid `/reload` during work | Immediate operational mitigation; no code | Human timing still loses unread results; no crash recovery | Interim guidance only |
| Increase/disable cleanup TTL, or protect every unread live session | Small patch; more time | Memory/timer retention, still loses everything on reload/crash, no trustworthy receipt after detachment | Reject as primary solution |
| Persist completion envelope + idempotent parent continuation | Addresses stranded results without retaining all live objects | Needs atomic persistence/ack and host-queue tests | **Phase 1 recommendation** |
| Guarded native reattach of original conversation, integrated into Astraeus | Preserves original implementation ownership after object loss | Cannot restore ephemeral sessions or in-flight execution; needs identity/version checks | **Phase 2 recommendation** |
| Spawn new implementation owner automatically | Easy to appear unblocked | Bypasses ownership/failure contract; replayed writes/inference and unknown provenance | Reject |
| Separate long-lived worker daemon | Could survive parent shutdown | New scheduler/security/auth/state surface, substantial complexity | Out of scope unless independently requested |

## Ownership and proposed API

These are proposed changes in their source checkouts, **not edits to Nix Store packages**. Root owns integration and final acceptance; the original worker owns any adopted fix. This document does not authorize implementation.

| Owner | Proposed files / responsibility |
|---|---|
| SubAgents native runtime | `src/agent-manager.ts`, `agent-runner.ts`, `types.ts`: stable owner identity, completion snapshot before eviction, guarded reopen using native `SessionManager.open`; record shutdown cause separately from generic `quit` |
| SubAgents transport | `src/cross-extension-rpc.ts`, `index.ts`: versioned capability advertisement and terminal-result/get/ack/recover operations, explicit recoverable/unrecoverable errors; keep native Agent/mention behavior compatible |
| Astraeus managed workflow | `extensions/core.mjs`, `index.ts`, receipt/result schemas and tests: durable managed envelopes, active-branch reconstruction, idempotent root delivery/collection, original-owner rebind; maintain freeze/review/adjudication/acceptance checks |
| Nix repo integration | Later pin approved source revisions via flake inputs/package wiring and validate without activation; do not introduce an activation-time Pi restart |
| Pi host | Existing session storage/queue/lifecycle APIs and native model/auth services. A host change is needed only if queue acknowledgement cannot be observed; do not invent an acknowledgement from `sendMessage()` returning |

Negotiate a new RPC capability version; existing ping version 2 is insufficient proof of support. Sketch:

```ts
// Proposed, not existing exported APIs.
getTerminal({parentSessionId, branchId, ownerId, attemptId}): TerminalEnvelope | NotReady;
ackTerminal({parentSessionId, branchId, ownerId, attemptId, resultHash}): Ack;
recoverOwner({parentSessionId, branchId, ownerId, expectedSessionId,
              expectedRoleDigest, expectedModel, expectedThinking,
              recoveryRequestId}): Reattached | Unrecoverable | Incompatible;
// Reattached returns new nativeAgentId + unchanged ownerId/childSessionId.
// Reattach alone performs no model call. Astraeus then validates and resumes.
```

Native recovery resolves only extension-owned mappings/capabilities, not caller-supplied arbitrary session-file paths. Verify parent/session lineage, canonical cwd, role contract, original child session ID/branch checkpoint and dispatch pins before attaching. Missing role, wrong identity, unavailable pin or ambiguous lineage fails closed. Old `@handle` recovery is not itself evidence that a managed owner was recovered.

Astraeus `resume` may then update the runtime binding `nativeAgentId` while preserving stable `ownerId`, role, owned paths and conversation lineage. Keep previous attempts immutable. The new implementation attempt explicitly supersedes the owner's failed/unavailable attempt; do not merely delete it or set the old job valid. Acceptance examines the latest attempt for that **stable owner**, not a map keyed by new native IDs that can accidentally omit failures. Existing adjudication-before-adopted-fix and no-active-writers/frozen-target rules still apply. A recovered reviewer/adjudicator session is not resumed for a new review.

## Durable state and receipt contract

Use the managed artifact namespace already owned by Astraeus (`<agentDir>/astraeus/<parentSessionId>/<taskId>/`), outside Git review targets, with explicit managed-session persistence. Keep directory mode 0700 and files 0600; atomic temp-write/fsync/rename and immutable content hashes precede releasing the live result. This investigation created nothing in that personal namespace.

The native manager must own a durable terminal snapshot/spool for explicitly managed children; an Astraeus listener alone would lose evidence if its runtime disappears before the callback. Negotiate a managed-result sink scoped to parent/branch/owner during dispatch, resolving only extension-owned artifact roots, never arbitrary caller paths. Capture/commit before publishing completion; Astraeus imports and validates the snapshot into its envelope, then acknowledges the native spool. If a commit fails, expose that failure and keep the attempt invalid; timer cleanup must never publish success from an uncaptured managed result. This adds result persistence, not a replacement conversation/auth engine.

```ts
type TerminalEnvelope = {
  version: 2;
  taskId: string; ownerId: string; attemptId: string; completionGeneration: number;
  parentSessionId: string; branchId: string; cwd: string;
  nativeAgentId: string; childSessionId: string | null;
  role: string; roleDigest: string; ownedPaths: string[];
  status: "completed" | "error" | "stopped" | "interrupted";
  resultPath: string; resultHash: string; structuredResultHash: string | null;
  requested: {model: string; thinking: string};
  observed: {model: string | null; thinking: string | null; sandbox: null};
  provenance: {model: "live-session" | "invocation-metadata" | "unknown";
               thinking: "live-session" | "invocation-metadata" | "unknown"};
  packageIdentity: {pi: string; subagents: string; astraeus: string};
  timestamps: {startedAt: number; terminalAt: number; capturedAt: number};
  recovery: {kind: "persisted-native" | "ephemeral" | "unknown";
             checkpointId: string | null};
};
```

Capture model/thinking from the live host session at dispatch and each managed resumed attempt's completion, before disposal. Invocation metadata is useful configuration evidence but may echo the request: it must not be presented as runtime observation. Store requested values separately; null/unknown is not repaired by copying requested pins. The current `assertReceipt()` fallback uses invocation metadata; migration must label that weaker provenance explicitly. Receipts/hashes are local host reports and integrity checks, not cryptographic attestation of provider execution or isolation. Known mismatch blocks managed success; unknown stays disclosed under reported assurance; strict read-only assurance remains blocked without real host evidence.

Child native session files retain conversations, not live execution. Result artifacts retain output/receipt, not permission to run tools. Do not duplicate auth or unrestricted transcript history into envelopes. A persisted checkpoint can resume a conversation; it cannot roll back/replay interrupted external effects safely.

Separate dimensions, rather than one overloaded job status:

```text
execution: queued -> running -> completed | error | stopped | interrupted
result:    absent -> captured -> validated -> acknowledged
binding:   live -> evicted | runtime-lost -> reattached | unrecoverable
delivery:  pending -> queued -> observed/collected | failed
```

Collection validates exact saved bytes/receipt/role/target from a live snapshot or durable envelope, then persists the result acknowledgement; only afterward sends native consume/ack. Retry after a crash is idempotent by attempt/result hash. Persistence failure is visible `needs-evidence`, not success and not permission to retain unlimited memory. On recovery, `running` with no live binding becomes `interrupted/unknown`, never inferred completed from a conversation file.

## Parent continuation without loops

Implement an outbox shared with existing SubAgents completion notifications, not an independent second broadcaster. Key each delivery by `(parentSessionId, branchId, ownerId, attemptId, completionGeneration)`.

1. Capture terminal evidence atomically, then record a pending delivery key. A notification is a pointer to evidence, not proof of collection.
2. If parent is busy, queue one follow-up through Pi's existing API. Do not steer a review/fix decision into an unfinished tool batch. If idle, one `triggerTurn:true` delivery may start the collection turn.
3. At `agent_before_settle`, reconcile terminal **unacknowledged new keys**. Return one continuation only if no equivalent follow-up/continuation is already pending. Mark the delivery reservation before returning. Reserve a bounded batch, not one endless turn per pending task.
4. At `agent_settled`, observe/update delivery state only; it cannot request continuation. A later child completion uses the outbox follow-up path.
5. A collection turn collects and follows existing workflow decisions. `needs-evidence`, missing owner, mismatch or failed delivery yields one actionable diagnostic, then stops. A task remaining incomplete is not grounds for repeated continuation.
6. Session shutdown cancels old timers/listeners and prevents stale-context sends. Restore only the active parent's branch entries. Never wake another parent/session or silently replay abandoned branches. After reload/restart, show pending evidence and require explicit root recovery/continuation rather than repeating an uncertain previous inference delivery.

`pi.appendEntry()` supplies durable non-model state and branch reconstruction; append proposed boundary entries through the documented settle event when appropriate. `sendMessage()` has no proven durable delivery acknowledgement in this investigation. Crash between delivery and ack creates uncertainty: promise at-most-once automatic **scheduling per live runtime**, plus idempotent collection, not exactly-once model execution. Mark an ambiguous reservation for manual reconcile instead of repeatedly triggering turns. Completion generation changes when an owner finishes a new attempt; an old generation never causes a new wake-up.

## Migration, retention and limits

- Introduce version-2 workflow state with a reader for existing `pi-astraeus:state-v1`. Migrate only the active branch during authorized operation. Keep original job history/role/request and unknown receipt provenance. Do not scan personal session directories looking for lost children.
- Old live children can acquire owner IDs/envelopes when still observable. Old already-evicted children with no captured output/lineage remain unavailable; no retroactive invented result. Same-owner recovery is enabled only after identity is proved, not by name similarity.
- Recommended result retention: unacknowledged/unfinished-task envelopes retained until explicit root discard; acknowledged envelopes retained through task acceptance and a 30-day grace period. Set a 256 MiB managed-store soft cap per parent session; surface pressure and stop new managed dispatch rather than silently deleting required evidence. These are proposed defaults, not measured sizing.
- Live child memory still expires after ten minutes. No automatic deletion of native session transcripts/auth/settings. Removing managed envelopes cannot imply native conversation deletion. Missing externally deleted transcripts gives a clear unrecoverable state.
- Preserve envelopes needed by outstanding review/adjudication references even across the grace cutoff. Garbage collection must check these references and never erase failures to make acceptance possible. All cleanup and discard operations require managed-scope confirmation.
- Role/source revisions may change across profile upgrades: keep version metadata, fail on incompatible schema/role changes, and require explicit compatibility approval; don't revive old grants under a new role definition.
- If the original conversation was ephemeral, lost, corrupted or unverifiable, report blocked. A user may authorize a new ownership transfer as a separate task decision, but it is not continuation and must not bypass a known failed owner.

Non-goals: process immortality across NixOS changes; replay/exactly-once external tool effects; a new scheduler/daemon/session engine; alternate authentication or inference CLI; personal settings/history migration; auto-acceptance; sandbox/security guarantees; unrelated browser/MCP fixes.

## Safe verification performed

Commands below were actually executed, without invoking the activation binaries:

```sh
readlink -f /run/current-system
readlink -f /run/current-system/bin/switch-to-configuration
readlink -f /etc/profiles/per-user/see2et/bin/pi
nix-store -q --references /nix/store/7gvljlf4a4ir91kh75ii5kixi5dppdsz-nixos-system-nixos-26.05.20260903.a5cc6f2
nix-store -q --deriver /nix/store/qix9bpv1pprfjz7r5a9cpdkhqk2s03ii-switch-to-configuration-0.1.0
nix derivation show /nix/store/6mklg926zgyxik0vhsbw5pzcs4b8sin1-switch-to-configuration-0.1.0.drv
python3 /etc/nixos/.astraeus/pi-usability-integrations/subagent/profile-probe.py
node /etc/nixos/.astraeus/pi-usability-integrations/subagent/eviction-probe.mjs
node --check /etc/nixos/.astraeus/pi-usability-integrations/subagent/eviction-probe.mjs
```

The local probe scripts are retained under ignored `.astraeus/pi-usability-integrations/subagent/` for independent rerun; they are evidence fixtures, not implementation. Their SHA-256 values are `844168ab6655f65cbcf667a97226feccb593fad5e82a3450b3573f2c6033b45c` (`profile-probe.py`) and `a3c678ae72f0153f9ce3dbe9bf99aff410459d50f1b16cf3083720ab64fecf75` (`eviction-probe.mjs`). They never instantiate a Pi SDK session or provider. The profile probe creates both fake generations/profile under its own temporary evidence directory, starts synthetic Python parent/child processes, replaces only that temporary symlink with `os.replace`, checks old/new launches, then closes and waits for all synthetic processes and deletes temporary files. No live profile is accessed by this test.

Observed output:

```json
{
  "before": {"version":"v1","pid":1441459,"child_pid":1441460,"child_alive":true},
  "after_replacement": {"version":"v1","pid":1441459,"child_pid":1441460,"child_alive":true},
  "new_launch": {"version":"v2","pid":1441461,"child_pid":1441462,"child_alive":true},
  "assertions":"PASS: old parent and child unchanged; new launch selects v2"
}
```

The source-stub probe extracts the installed `cleanup`, `removeRecord`, `tombstone`, `clearCompleted` bodies and the child shutdown helper, removes only method-signature TypeScript/generic syntax, and supplies fake clock/maps and synthetic sessions. It imports the real Astraeus `Workflow`, but only calls missing-record collection/resume/accept paths with in-memory host state. Results: **PASS**, exit 0; `node --check` exit 0.

| Verified case | Actual result |
|---|---|
| Completed unread result at exactly ten minutes | Survived |
| Same result at ten minutes + 1 ms and a sweep | Removed, even `resultConsumed=false` |
| Running and queued records at that age | Survived |
| Persisted evicted record | Tombstone kept session path but no result bytes |
| Stub child lifecycle during eviction | Shutdown event then disposal; parent probe process remained alive |
| Ephemeral evicted record | No tombstone |
| `clearCompleted(true)` | Unread result retained; consumed result removed; tombstones cleared |
| 101 tombstones | Oldest removed, 100 remain |
| Astraeus collect with missing manager record | `unavailable`, collected=true, valid=false, `needs-evidence` |
| Resume/accept that missing worker | Both rejected; no replacement launched |

The stub helper uses `reason:"quit"` on eviction, confirming that this label cannot distinguish expiry from parent quit. The test does not create native transcript files at its `/synthetic/...` placeholder paths. These are extracted source-method tests, not full extension integration or proof of production signal handling.

Source fingerprints (SHA-256):

```text
SubAgents agent-manager.ts 20c753c13636dc5a2e31f51a4da8144aed04a97e0ad48cc99c7ad988e4451a2a
SubAgents index.ts         622d44b11e615ec0509f13e858dcad4a40789e4613c03583930327f15d9ec6a9
Astraeus core.mjs          7af09ba9d6a68d1201da075659f02288581d708a2e41b4d79d29a5d20ce9d121
Astraeus index.ts          896464b2851c9ff2340b32788fdf470fa278125add05086c255fe400a798dc91
Switch main.rs            54c288f7969e9dfda8e55c2da871105c9166c92a5c2d47de55de77e4b4c6aa10
```

### Implementation acceptance matrix (not yet executed)

Tests should use a controlled event bus/fake session manager/provider stub, fake clock and disposable artifact root; never personal credentials or histories. Ordinary event-bus tests do not establish a sandbox. A future integration test must explicitly isolate discovery/settings and use synthetic sessions; don't copy the SDK's default example, which discovers personal resources.

| Scenario | Required observation before accepting a fix |
|---|---|
| Parent idle; child completes | One terminal envelope, one wake-up, collect+ack, no second wake-up |
| Parent busy; child completes during tools | One follow-up after current work; no racing edit/settle or duplicated nudge |
| Completion at `agent_before_settle` / just after `agent_settled` | Exactly one scheduling reservation via the appropriate actionable/notification boundary; no loop |
| Multiple children / repeated terminal events | Bounded batch, keyed dedup; each attempt collected once |
| TTL eviction before collection | Durable exact output and host snapshot still collectable without live record |
| Stale send, persistence failure, RPC timeout | Visible pending/needs-evidence; no inferred ack or silent replacement |
| Synthetic extension teardown/reconstruction | Timers cancelled; envelopes reconstruct on same branch, no stale callback; active work marked interrupted |
| Synthetic process loss, then explicit original-owner reopen | New native ID bound to same stable owner/session; no inference before validation; failed history preserved |
| Missing/ephemeral transcript, changed role/pin, unknown receipt | Fail closed or disclosed unknown; cannot accept fabricated recovered evidence |
| Abandoned parent branch / different parent | No delivery, ownership adoption or cross-session continuation |
| Crash between scheduling and ack | Ambiguous state surfaced; no automatic repeated inference; idempotent collect |
| Fake profile replacement while idle/busy | Existing parent/session references intact, new launch selects new paths; no automatic runtime upgrade |
| Real switch/service changes | **Not part of this evidence.** Requires a separately authorized user-controlled rollout and synthetic workload; this proposal does not authorize it |

## Suggested approval

Approve Phase 1 design/implementation in the Astraeus and SubAgents source checkouts with the matrix above, then an independent review before Nix integration. Approve Phase 2 only after the native recovery capability/identity contract is agreed. Keep any future live NixOS rollout separate and user-controlled. Until then, collect results promptly, keep the parent process open and do not use `/reload` as a recovery mechanism for active managed work.
