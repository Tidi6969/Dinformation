# DINFORMATION V18 — AutoCAD 2022 preflight / QA

Baseline: V17, `main/V17/Dinformation-V17.zip` (unchanged).
Target: AutoCAD 2022 only (net48, x64, Autodesk AcCoreMgd/AcDbMgd/AcMgd 24.1).
Version convention: max stored V17, planned V18 = V17+1.
Release type: **source/build candidate, NOT a completed V18 release**.
GitHub release ZIP: **not published** pending STD-17 gates.
Other CAD hosts: unchanged in original V17; not targets of the patch/build.

## Files changed and rationale (STD-18)
- `InformationSession.cs`: use native picked entity ID to avoid repeat LISP hit tests for an unchanged ObjectId; no rate-limited omissions on native pick miss, retain original LISP `nentselp` for custom and nested entities; safely unsubscribe and reset on command exit.
- `LispInfoEngine.cs`: invoke a handle-based LISP reader when the native picker succeeds, avoiding an extra hit test.
- `Dinformation-Tooltip.lsp.tpl`: preserve GC2018-style reader and tooltip labels; add handle lookup and a DXF type/layer/handle fallback when an object's ActiveX property cannot be read.

No changes to GstarCAD 2018, AutoCAD 2025, GstarCAD 2027, DWG geometry, XData/XRecord, settings, Support Paths, languages, or command name.

## Verification matrix (expected vs actual)
| ID | Test / expected | Observed evidence | Status |
| --- | --- | --- | --- |
| AI-01/02/04/05/06/10 | V17 baseline; only 2022 C#/LISP source changed | Diff and V17 archive retained | PASS (source review) |
| AI-07 | Same native ObjectId: no repeated `handent` call | Code branches by ObjectId; CAD behavior not measured | NotVerified (runtime) |
| AI-07/08 | Native pick misses: immediate LISP fallback, no 50ms gap | Static source check passes; CAD hover not exercised | NotVerified (runtime) |
| AI-07/08 | Proxy/unsupported ActiveX: visible type, layer, handle | Catch/fallback branch in LISP; no CAD fixture yet | NotVerified (runtime) |
| AI-07/08 | Nested block: same outermost block info as GC2018 | `ids[0]` is outermost per Autodesk FullSubentityPath docs; runtime untested | NotVerified (runtime) |
| AI-09 | Release x64 / net48, Autodesk SDK 24.1, correct C22 DLL & assembly V18 | GitHub Actions Windows [41660605059](https://github.com/Tidi6969/Dinformation/actions/runs/41660605059): BuildExitCode=0, AssemblyVersion=18.0.0.0, compiler errors=0, warnings=0 | PASS (build only) |
| AI-09 | NETLOAD, hover, ESC, selection, language and CAD appearance | Requires AutoCAD 2022 installation and DWG test samples | NotVerified |
| AI-11 | Existing DUser, multilingual embedded data, LISP overlay behavior unchanged | Only three source files patched | PASS (source review), runtime NotVerified |
| AI-12 / AUTO-04 | Release only when all required checks pass | Runtime remains NotVerified | HARD STOP for completed release |

## Required AutoCAD 2022 manual regression
1. Open representative DWG, NETLOAD `DinformationC22.dll`, invoke `Dinformation`.
2. Hover LINE, CIRCLE, ARC, LWPOLYLINE, open SPLINE, HATCH, TEXT, MTEXT, DIMENSION, INSERT, nested INSERT, proxy/custom entity: expect type/layer/handle and applicable properties.
3. Move fast through objects and empty space: compare missed-object count and tooltip responsiveness with GstarCAD2018.
4. Change UCS, zoom and pan; verify hit location under cursor and no text lag.
5. ESC and re-run command; confirm no lingering highlight, changes to DWG, or duplicate monitor handlers.
6. Confirm six-language labels via supported MIS_SET profile where available.

**Do not mark runtime PASS or announce V18 delivered until actual test evidence is provided and STD-03/04/16/17 release gates are met.**
