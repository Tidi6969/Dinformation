# Dinformation GstarCAD 2018 V17

Command: `Dinformation`

Build with `Build_Release.cmd`. Output: `bin\DinformationG18.dll`.
Final shared runtime after root `Build_All.cmd`: `Dprogram\DinformationG18.dll`.

Language is embedded from `Buildtime\Language\lang.dat`. `MIS_SET.SET` is read-only and is resolved only from a valid `DUser` in the current CAD Support File Search Path: direct `DUser` or registered-root `DUser`. Sibling inference from `DData/DProgram/DHelp/Dicon` is forbidden. Missing/invalid line 28 falls back to English; the file is never created or repaired.

Reference SDK DLLs are build-only and are not copied to `bin` or `Dprogram`.

Runtime technical diagnostics are written to `%TEMP%\DCAD\Dinformation\log`; no runtime log is written beside the DLL in `DProgram`.

## Reference behavior in V17

GstarCAD 2018 remains the reference LISP implementation. Its temporary LISP command and in-canvas overlay behavior are unchanged; AutoCAD 2022/2025 and GstarCAD 2027 reuse its recognition/property-reading logic but send returned lines to their existing native tooltip.
