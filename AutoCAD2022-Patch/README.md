# DINFORMATION — AutoCAD 2022 hover/recognition source candidate

Baseline: **V17** original archive in `V17/Dinformation-V17.zip`.
Scope: **AutoCAD 2022 only**. GstarCAD 2018 (reference), AutoCAD 2025 and GstarCAD 2027 are unmodified.

This is a **source-only patch, not a V18 release**. It contains the three complete replacement source files inside `AutoCAD2022-Patch/`. The Windows CI workflow applies them to a temporary checkout of the original V17 ZIP, builds only the AutoCAD 2022 project with its own three Autodesk 2022 SDK references, and uploads a test DLL and build log as a workflow artifact. No original versioned ZIP is overwritten.

Changes:
1. Native `PointMonitor.Context.GetPickedEntities()` is consulted first with outermost block-reference identity matching the GstarCAD 2018 behavior.
2. LISP tooltip data is cached for unchanged entity IDs; fallback `nentselp` is rate-limited.
3. Unsupported native picks fall back to original LISP picking, and unsupported ActiveX properties emit real DXF type, layer and handle rather than a blank/unknown-only response.
4. LISP callback by handle uses `handent` to avoid a second hit test for native picked entities.

QA status: Windows Release build is tested by the linked workflow. AutoCAD 2022 NETLOAD and interactive mouse-hover comparison against GstarCAD 2018 remain **NotVerified** until tested on an actual CAD host. Do not label or distribute this as a fully released V18 version.
