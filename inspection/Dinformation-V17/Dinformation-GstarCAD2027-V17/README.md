# Dinformation GstarCAD 2027 V17

Command: `Dinformation`

Build with `Build_Release.cmd`. Output: `bin\DinformationG27.dll`.
Final shared runtime after root `Build_All.cmd`: `Dprogram\DinformationG27.dll`.

Language is embedded from `Buildtime\Language\lang.dat`. `MIS_SET.SET` is read-only and is resolved only from a valid `DUser` in the current CAD Support File Search Path: direct `DUser` or registered-root `DUser`. Sibling inference from `DData/DProgram/DHelp/Dicon` is forbidden. Missing/invalid line 28 falls back to English; the file is never created or repaired.

Reference SDK DLLs are build-only and are not copied to `bin` or `Dprogram`.

Runtime technical diagnostics are written to `%TEMP%\DCAD\Dinformation\log`; no runtime log is written beside the DLL in `DProgram`.

## Recognition and tooltip pipeline (V17)

- LISP performs `nentselp` hit testing, deepest nested entity resolution, change detection, highlighting and property reading using the GC2018 `dis` logic.
- .NET `PointMonitor` only forwards the cursor point and appends the returned lines to the existing native tooltip.
- The previous .NET `ObjectInformationService` reader is removed from this host.
- No GC2018 `SOLID`/`TEXT` overlay is created; current tooltip presentation is retained.
- The LISP template is embedded in the DLL and materialized as an ASCII temporary file only while loading.
