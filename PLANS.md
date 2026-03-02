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
