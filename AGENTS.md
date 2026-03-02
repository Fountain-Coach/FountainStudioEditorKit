# FountainStudioEditorKit — Agent Guide

Scope: standalone Swift editor framework for Fountain-Coach products, with deterministic editor behavior and FCIS-compliant repo governance.

Invariants
- Domain-agnostic framework: no direct dependency on app-specific product models.
- Editor rendering must not mutate or truncate source text.
- Deterministic behavior for line mapping, marker virtualization, and highlight application.
- FCIS layering enforced: intent in `PLANS.md`, procedures in skills, AGENTS declarative only.
- MCP is optional capability only; repo correctness must not depend on MCP.

Routing
- For multi-step or high-risk changes, create or update `PLANS.md` before edits.
- Keep execution runbooks in `.codex/skills/*/SKILL.md`.
