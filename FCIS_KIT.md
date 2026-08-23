# FCIS-KIT Declaration — FountainStudioEditorKit

Declared under FCIS-KIT v1.0, requirement FCIS-KIT-01.

```yaml
FCIS-KIT:
  owns:
    - FountainStudioEditorCore: domain-neutral editor contracts for marker virtualization, navigation, anchors, and diagnostics
    - FountainStudioEditorAppKit: AppKit host implementation of the editor seam
    - FountainStudioEditorSwiftUI: SwiftUI projection of the host-neutral editor seam
    - FountainStudioEditorTesting: deterministic fixtures and test helpers for editor consumers
  consumes: []
  third-party-exceptions: []
```

The kit does not own Reframe product policy, manuscript models, Store schemas, credentials, or publication decisions.
Consumers bind those concerns through adapters.

## Release state

Current candidate source is the focused-parity line at `4aaeae895453f052bec4a20a9ff674d42f3c3647`. A semver release
and GitHub release are not claimed until the owning release decision, clean-tree test run, annotated tag, and release
notes exist under FCIS-KIT-07.
