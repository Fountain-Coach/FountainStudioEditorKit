# FCIS_COMPLIANCE_PLAN.md

## Goal & Scope
Keep this repository compliant with FCIS RFC 0001 by enforcing separation of intent (PLANS), invariants/routing (AGENTS), and procedures (skills), with deterministic CI checks.

## Minimal-Change Strategy
- Keep AGENTS declarative; no commands or runbooks.
- Keep multi-step intent in PLANS with explicit validation.
- Keep procedures in `.codex/skills/*/SKILL.md`.
- Keep MCP optional and non-required.

## Validation Checklist
- AGENTS has no procedures.
- PLANS entries include explicit validation commands.
- Skills contain step-by-step runbooks.
- `Scripts/fcis-check` passes in CI.

## Governance Checklist
- Branch protection on `main` requires CI checks.
- CODEOWNERS covers API and CI/security changes.
- SECURITY.md and issue/PR templates are present.
