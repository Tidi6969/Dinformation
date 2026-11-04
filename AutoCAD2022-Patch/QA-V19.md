# DINFORMATION V19 — AutoCAD 2022 source/build candidate QA
Baseline: V18 on GitHub (original V17 and V18 archives preserved).
Reason for V19: V18 candidate had obsolete root V17 audit documents; V19 removes them, aligns V19 version metadata and rebuilds only C22. Recognition algorithm unchanged from V18.

Scope: AutoCAD 2022 / net48 x64 / Autodesk 24.1 only. GstarCAD 2018, AutoCAD 2025, GstarCAD 2027 remain unchanged in historical archives.

Expected: hovering LINE, CIRCLE, ARC, LWPOLYLINE, SPLINE, HATCH, TEXT, MTEXT, DIMENSION, INSERT/nested INSERT and proxy entities displays type/layer/handle plus supported properties. Same selected ObjectId reuses cached tooltip; when native picker misses, LISP nentselp is used without artificial 50ms gap. ESC closes command and cleans highlight.
Actual: Windows compiler and package checks recorded by the V19 workflow; no live CAD host is available for visual/interaction testing.

BuildStatus=PASS if workflow produces new C22 DLL with AssemblyVersion=19.0.0.0; otherwise FAIL.
NETLOAD/RuntimeStatus=NotVerified.
BuildConsoleColorVisual=NotVerified.
Language/CAD-Hover/ESC/UCS=NotVerified.
StandardsStatus=NotVerified.
ReleaseApproved=NO (source/build candidate only).
