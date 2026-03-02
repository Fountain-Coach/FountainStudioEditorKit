FCIS-VRT UI: FountainStudioEditorKit
===================================

Goal
- Catch editor visual regressions for line numbers, markers, and overlays.

Command (local)
- Capture and compare (opt-in):
  `UI_SNAPSHOT=1 swift test --filter FocusedEditorSnapshotTests`
- Refresh baselines when intended:
  `UPDATE_GOLDEN=1 UI_SNAPSHOT=1 swift test --filter FocusedEditorSnapshotTests`

Determinism
- Fixed snapshot sizes and appearance.
- Stable fixtures; no clock/random-dependent content.
- Repeat-pass requirement before baseline acceptance: each snapshot must match across 3 consecutive captures in the same run.
