# PLANS.md

This file defines the intent protocol for multi-step or high-risk work in this repository.

## When a Plan Is Required
Create or update a plan before changes when work is:
- Multi-step (more than a small, single-file fix).
- Cross-cutting (touches public APIs and multiple modules).
- High-risk (render behavior changes, persistence/serialization changes, CI/release policy changes).
- Safety sensitive (data loss/truncation/compliance/security risk).

## Plan Format (Template)
Use this structure and keep it concise:

Title:
Goal:
Scope:
Non-goals:
Constraints:
Risks:
Plan:
- Step 1 (status: pending | in_progress | done) - intent
- Step 2 (status: pending | in_progress | done) - intent
Validation:
- How you will confirm success (tests, checks, manual steps)

## Acceptance Criteria
- The plan states intent and scope clearly.
- Steps are minimal, ordered, and testable.
- Validation is explicit and feasible.
- Deviations are recorded and justified.

---

Title: FountainStudioEditorKit — FCIS-compliant bootstrap and Modernization Studio focused-editor migration
Goal: Stand up a standalone FCIS-compliant editor framework repo and provide the initial migration surface for the focused Storify A4 editor via adapter-based integration.
Scope: Repo governance/docs/CI, core protocol surface, basic AppKit+SwiftUI module scaffolding, and consumer integration path definition.
Non-goals: Full big-bang replacement of all editor callsites in one release.
Constraints: Keep domain coupling adapter-based; preserve drag-payload and virtual marker behavior parity in consumers; deterministic tests only.
Risks: API churn during early extraction; mitigated by feature flags and narrow first migration scope.
Plan:
- Step 1 (status: in_progress) - Bootstrap FCIS repo structure (AGENTS/PLANS/skills/audit/compliance docs/CI/security/governance templates).
- Step 2 (status: pending) - Define stable protocol contracts for marker virtualization/navigation/overlay integration.
- Step 3 (status: pending) - Provide minimal SwiftUI/AppKit editor skeleton with deterministic text-sync and line mapping helpers.
- Step 4 (status: pending) - Validate via `swift test` and FCIS structure checks.
Validation:
- `swift test`
- `bash Scripts/fcis-check`

---

Title: FountainStudioEditorKit — focused Storify parity (overlay virtualization, hover/drag anchors, deterministic VRT)
Goal: Deliver focused-mode editor parity needed by Modernization Studio before default-on rollout: visible-only line ruler, marker virtualization with icon gutter overlays, hover card + drag anchor payload compatibility, and deterministic focused visual regression checks.
Scope: `FountainStudioEditorCore` feature flags/contracts, `FountainStudioEditorAppKit` focused rendering/overlay behaviors, `FountainStudioEditorSwiftUI` API surface, focused framework tests, and CI VRT repeat-pass gate.
Non-goals: Broad non-focused UI redesign, app-specific parser coupling, or replacing all legacy editor flows in one step.
Constraints: Keep API additive and backward compatible; preserve default inline-visible behavior unless focused flags enable overlay mode; maintain FCIS-required checks.
Risks: AppKit overlay/ruler work can introduce render jitter and selection bugs; mitigated with deterministic snapshot harness, repeat-pass stability gate, and focused regression tests.
Plan:
- Step 1 (status: done) - Add additive focused feature configuration and anchor payload contracts used by framework runtime.
- Step 2 (status: done) - Implement AppKit focused behaviors (visible-only ruler + icon gutter overlays + hover card + drag payload + marker virtualization).
- Step 3 (status: done) - Wire SwiftUI editor API to expose focused feature flags and keep backward-compatible defaults.
- Step 4 (status: done) - Add focused tests (virtualization, payload compatibility, and focused snapshots with light/dark variants and repeat-pass determinism).
- Step 5 (status: in_progress) - Add CI job for focused VRT repeat-pass and validate required checks (`swift-test`, `fcis-audit-check`, `security-scan`, `vrt-focused-repeat-pass`).
Validation:
- `swift test`
- `UI_SNAPSHOT=1 swift test --filter Focused`
- `bash Scripts/fcis-check`
