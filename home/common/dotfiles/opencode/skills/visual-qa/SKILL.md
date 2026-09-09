---
name: visual-qa
description: Verify a rendered web, desktop, or terminal UI after changes. The same Astra implementation owner runs applicable surface QA and captures evidence; consequential visual changes receive one visual-director gate with a bounded delta re-review. Use for responsive, layout, typography, interaction, or explicit reference-fidelity verification, not source-only code review.
---

# Verify the rendered interface

Local adaptation of OmO visual-qa (v5.0.0-beta.51). Replace the normal dual-Oracle panel with hands-on QA by the Astra implementation owner and one independent visual-director when the change warrants it.

## Ownership and scope

Design decisions and design-related implementation stay with Astra. Keep direction, component structure, implementation, browser iteration, and fixes in the same owner's session. A primary already using Astra may own this directly; otherwise use one Astra visual-engineering worker. Lighter agents may locate assets or references but do not reinterpret the design.

Extract the requested outcome, established design language, target surfaces, and important states. Do not turn ordinary UI work into pixel-perfect reference reproduction. For an explicit fidelity request, record the reference and acceptance tolerance; ask only if an unresolved tolerance materially changes the task.

## Exercise the real surface

Run the actual application through the relevant surface. Use the available browser skill/tool for a web UI, native automation for a desktop app, and a real terminal for a TUI. Do not claim to have rendered or clicked something based only on source.

Verify the affected interaction and meaningful states, including an error/boundary path where the change affects it. Inspect layout, hierarchy, readability, reflow, focus/keyboard behavior, and visible feedback as relevant to the requested work. Reuse existing checks and captures when they still represent the current artifact.

For a responsive web UI, provide a desktop viewport, a representative mobile viewport, and the main changed interaction state. For a native app or TUI without a mobile surface, provide applicable window/terminal sizes and explicitly record why mobile is inapplicable. Do not fabricate an unsupported surface.

Capture evidence after the relevant changes. Inspect captures for missing regions or capture defects before review. After a fix, update affected captures and actions; shared layout/token changes require all affected surfaces to be checked. Keep a short evidence record with revision/diff basis, viewport, state, action, observed result, and capture path. Screenshots alone do not prove an interaction worked.

## Decide whether independent visual review is needed

Consequential changes to layout systems, navigation, hierarchy, tokens, typography, responsive behavior, motion, or styling across components receive one final read-only `visual-director` review. Provide the accepted intent, changed surfaces, captures, interaction evidence, reference if any, and the contract below. Use a foreground task when the verdict is the only remaining dependency; background execution is useful only while independent work remains. Collect the verdict before ending the task.

Copy-only changes, isolated one-property fixes, and mechanical component changes normally end after the owner's applicable QA. An explicit review request or repository-specific gate still applies.

Do not launch the bundled dual-Oracle visual passes, a second visual panel, or a separate reference-fidelity pair. The visual-director incorporates applicable reference-fidelity checks into its single review. General code review consumes this visual receipt and reviews distinct behavioral/code risks, without re-dispatching the visual gate.

## Visual review contract

The verdict is PASS, FAIL, or INCONCLUSIVE. A blocker demonstrates an unmet accepted design requirement or a material usability/accessibility regression, with a screenshot/state, affected region, practical consequence, and smallest correction. Examples include unusable controls, missing or clipped information, unreadable contrast, or broken responsive layout.

When design quality itself is the task, assess the accepted design intent rigorously. Alternative aesthetics, a new design direction, or minor preferences without an acceptance failure are OPTIONAL and do not prevent PASS. Missing required rendered or interaction evidence yields INCONCLUSIVE and the exact missing item.

## Corrections and closure

Use one initial independent review and at most one focused re-review for normal work. Preserve blocker IDs and decisions. The same Astra implementation owner applies corrections and regenerates affected evidence. The fresh re-review examines the original goal, blocker ledger, changed surfaces, and regressions introduced by the fixes. Reopen closed items only with new concrete evidence.

For explicit fidelity work, use the same bounded process unless a different review budget was explicitly agreed. At the limit, report unresolved blockers or missing evidence and the minimum next action; never auto-pass or silently keep spawning reviewers. Mandatory repository safety and review gates remain required.

Return a receipt with the reviewed revision/diff basis, affected surfaces, actions/captures, applicable verdict, and unresolved items. For a small change without an independent gate, label it owner QA rather than claiming an independent review. Finish when the requested outcome and required checks pass; do not add a polishing loop.
