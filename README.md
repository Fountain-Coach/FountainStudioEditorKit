# FountainStudioEditorKit

Standalone, FCIS-compliant Swift framework for Fountain editor surfaces used across Fountain-Coach products.

## Modules
- `FountainStudioEditorCore`: marker, virtualization, navigation and protocol contracts.
- `FountainStudioEditorAppKit`: AppKit text host and integration layer.
- `FountainStudioEditorSwiftUI`: SwiftUI wrapper over the AppKit host.
- `FountainStudioEditorTesting`: deterministic test fixtures.

## FCIS
This repository follows FCIS layering:
- policy/routing in `AGENTS.md`
- intent in `PLANS.md`
- procedures in `.codex/skills/*/SKILL.md`

## Validation
```bash
bash Scripts/fcis-check
swift test
```
