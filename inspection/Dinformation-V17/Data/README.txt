Dinformation-V17

Command: DINFORMATION

Build/package architecture:
- Four independent host source trees, synchronized to V17.
- Root Build_All.cmd is the main build command.
- Each host builds one uniquely named DLL into its own flat bin folder.
- After all four builds pass, Build_All.cmd recreates Dprogram and copies only the four runtime DLLs there.
- CAD SDK Reference DLLs remain build-only.

Final Dprogram mapping:
- AutoCAD 2022  = DinformationC22.dll
- AutoCAD 2025  = DinformationC25.dll
- GstarCAD 2018 = DinformationG18.dll
- GstarCAD 2027 = DinformationG27.dll

Data system (DCAD-DATA-001):
- Embedded language source: Buildtime\Language\lang.dat
- Runtime language selector: DUser\MIS_SET.SET only, line 28
- Support Path source: current CAD/profile via host adapter; resolver order is preserved
- Direct DUser registration and registered-root\DUser are supported
- Sibling inference is forbidden: a registered DData/DProgram/DHelp/Dicon does not imply DUser
- Find never creates folders or files
- Duplicate MIS_SET.SET files: select first by Support Path order and log CONFLICT
- Missing/invalid MIS_SET.SET: fallback embedded English; never modify MIS_SET.SET
- Runtime technical diagnostics: %TEMP%\DCAD\Dinformation\log
- No DData business files are required by Dinformation V17

Recognition pipeline V17:
- AutoCAD 2022/2025 and GstarCAD 2027 use embedded LISP nentselp/dis for hit-testing and data extraction.
- .NET only forwards cursor points and renders the existing native tooltip.
- GstarCAD 2018 remains the reference LISP launcher/overlay host.
- V17 compile and CAD runtime tests are not yet verified; see BUILD-STATUS.txt.
