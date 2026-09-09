---
name: review-work
description: Review completed implementation or prepare a PR handoff using existing QA evidence and one integrated Oracle gate. Keep findings tied to accepted requirements and re-review only blockers and the changed delta. Do not use for mechanical edits, ordinary implementation steps, or a narrow diagnostic consultation.
---

# Review completed work

Local adaptation of OmO review-work (v5.0.0-beta.51). Keep the upstream single-reviewer structure, with a bounded acceptance contract and no automatic context-mining panel.

## Establish the review target

Read the original goal, accepted constraints, changed files, and relevant instructions. Record the comparison base and the current revision/diff being reviewed; include uncommitted changes when they are part of the deliverable. Do not assume HEAD~1 is the correct base.

Carry forward explicit non-goals, accepted tradeoffs, and the agreed threat model. Acceptance criteria may include behavior required for the stated goal to work; optional hardening or a different design does not become a new requirement. Preserve repository safety, major-change classification, required approvals, and required independent reviews.

Use relevant paths and a concise diff/context summary. The local Oracle can read files: do not paste every changed file and the entire conversation. Inspect adjacent code, history, or trackers only to resolve a named question that affects the verdict. Do not search unrelated services just because their tools are available.

## Verify the work before review

The implementation owner performs routine checks and the applicable real-surface QA as part of the same assignment. The primary inspects the evidence and integration. Reuse evidence that still covers the reviewed revision; after a fix, rerun affected checks rather than every earlier check.

Cover the requested behavior and the material failure/regression paths affected by the change. Select checks by risk and acceptance criteria, not a minimum count of scenarios. For data/configuration work, inspect the resolved artifact and exercise its loader when applicable. For UI work, consume the local visual-qa receipt and captures; do not start another visual panel.

Keep a compact record:

| Acceptance condition | Check/action | Expected and observed result | Evidence | Status |
|---|---|---|---|---|

Fix known in-scope failures before requesting the final gate. If a required check cannot run, report the specific missing evidence as INCONCLUSIVE; never invent a passing result. Unrelated pre-existing issues remain notes unless they block the goal.

## One integrated independent reviewer

Use one read-only `oracle` task after the evidence is ready. Include the original goal and constraints, target/base, changed paths, necessary context, QA record, visual receipt if applicable, and the review contract below. Run it in the background only when the primary has independent work to continue; otherwise use a foreground task. Collect the final verdict before ending the task. Do not duplicate or recursively delegate the review.

The reviewer examines goal completeness, correctness, relevant security boundaries, compatibility, and evidence together. Additional expertise is a consultation on a specific unresolved risk, not another full gate lane. A required fresh post-implementation Oracle for a major change can serve as this gate when its scope and evidence cover it; do not request two identical reviews.

## Review contract

Return APPROVE, BLOCKED, or INCONCLUSIVE. Each blocker must contain:

- A stable ID and the violated acceptance condition or concrete material regression.
- An affected location and realistic trigger, failing check, or direct evidence.
- The smallest correction that resolves the failure.

Style preferences, alternative architectures, speculative hardening, and extra tests without a required behavior gap are NOTES. Notes alone permit APPROVE. Missing required evidence is INCONCLUSIVE, not a fabricated bug. Do not expand the accepted threat model during review; identify genuinely new concrete risk explicitly.

## Fixes and stopping

The normal budget is one initial review plus one focused re-review. Record blocker IDs, decisions, and the round count in the current task's notes; do not create a permanent per-feature specification.

Send fixes to the existing implementation owner. Start a fresh reviewer session for re-review with the original acceptance contract, blocker ledger, delta since the reviewed revision, and affected check results. Verify accepted blockers and regressions from the fixes. New blockers require concrete evidence within the accepted scope; do not rediscover the entire design or reopen a closed item based on preference.

If another edit invalidates a reviewed assumption, check that delta before claiming approval. Unrelated file changes do not automatically invalidate every receipt.

At the round limit, report remaining blockers or missing evidence and the smallest next action. Do not claim approval or silently start another review cycle. Further review rounds require an explicit decision to continue; mandatory repository gates remain required. A running review or a timeout is never a PASS.

Finish once the acceptance evidence and required reviews pass. Report the verdict, evidence, remaining notes, and any actual limitation. Do not add a new polishing pass after approval.
