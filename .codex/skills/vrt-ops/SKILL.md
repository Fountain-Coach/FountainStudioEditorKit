---
name: vrt-ops
description: Run deterministic FCIS-VRT snapshot checks for editor surfaces.
metadata:
  short-description: Run VRT checks
---

# Skill: vrt-ops

Purpose:
Execute optional/opt-in visual regression checks and baseline refresh flow.

When to use:
- Before accepting visual UI changes.
- After changes to ruler, marker overlays, highlight, or line mapping visuals.

Steps:
1) Run opt-in VRT checks:
   `UI_SNAPSHOT=1 swift test --filter Snapshot`
2) Refresh baselines only when intended:
   `UPDATE_GOLDEN=1 UI_SNAPSHOT=1 swift test --filter Snapshot`

Output contract:
- Report which snapshot variants changed and why.
