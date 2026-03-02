# FCIS_AUDIT.md

## Executive Summary
Status: COMPLIANT (bootstrap target)
Top findings:
- AGENTS is declarative and routing-only.
- PLANS protocol exists and is referenced for multi-step/high-risk work.
- Procedural runbooks are in skills under `.codex/skills/**/SKILL.md`.
- MCP is optional and non-required for correctness.

## Repository Inventory
- Root AGENTS: `AGENTS.md`
- PLANS: `PLANS.md`
- Skills: `.codex/skills/**/SKILL.md`
- CI workflows: `.github/workflows/*.yml`

## Compliance Matrix
| Requirement ID | Requirement (short) | Status | Evidence | Fix recommendation |
| --- | --- | --- | --- | --- |
| FCIS-AGENTS-1 | AGENTS defines invariants/routing only | PASS | `AGENTS.md` has scope/invariants/routing only | Keep runbooks in skills |
| FCIS-PLANS-1 | PLANS.md protocol exists and is used | PASS | `PLANS.md` template and active plan entry present | Keep plan status current |
| FCIS-SKILLS-1 | Skills exist for procedures | PASS | `.codex/skills/repo-ops/SKILL.md`, `.codex/skills/vrt-ops/SKILL.md` | Add skills as runbooks grow |
| FCIS-LAYERS-1 | Orthogonality across AGENTS/PLANS/Skills | PASS | Separation maintained by file roles | Avoid procedural AGENTS edits |
| FCIS-MCP-1 | MCP optional only | PASS | AGENTS invariant states MCP optional | Do not add MCP runtime dependency |
