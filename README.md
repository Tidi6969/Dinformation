# Dinformation
Latest saved: **V20 — four-host source/build candidate**, baseline V19.
[Download Dinformation-V20.zip](V20/Dinformation-V20.zip)
[Changelog V20](Change%20log/V20.txt)
CAD branches: AutoCAD2022, AutoCAD2025, GstarCAD2018, GstarCAD2027.
Only the AutoCAD2022 recognition source was modified; the other 3 hosts'
functional code is identical to V17. All 4 rebuilt using separate SDKs.
Build PASS; NETLOAD/Runtime/Standards NotVerified; ReleaseApproved=NO.
CAD acceptance: Chua xac nhan.
Historical V17/V18/V19 ZIPs and changelogs remain available.

## Preferred working baseline reported 05/11/2026

- User supplied an original `Dinformation-V16.zip` in chat and described **V16 as the best working version** after reporting the V17-derived/V21 test variants were not working as expected.
- **Preferred functional baseline for the next correction: V16** (explicitly user supplied; this is not a claim that V16 is the latest stored on GitHub).
- Uploaded V16 ZIP integrity: 171 archive entries; CRC check PASS; SHA256 `1931870d9e7b343463bee5ea0644b04cfa132001e06daf77fc8584477bb672c9`.
- V16 source has four historical host trees (AutoCAD2022, AutoCAD2025, GstarCAD2018, GstarCAD2027), and AutoCAD2022 uses native .NET `InformationSession` + `ObjectInformationService`. V17 replaced that C22 property reader with a LISP-based implementation.
- The supplied V16 archive does **not** contain built DLLs; its `Data/BUILD-STATUS.txt` records `NOT BUILT`. This does not contradict the user's preference for its functional behavior. **Host-specific Build/NETLOAD/Runtime/Standards: NotVerified** in this archive. UserReportedPreferredWorkingBaseline=V16; UserReportedWorkingDetails=NotSpecified.
- V16 original archive is **not yet uploaded to this GitHub repository**; it was supplied in ChatGPT. Do not create an invented `V16/` link.
- Latest ZIP actually stored in `main` remains **V20**. The separately prepared V21 candidate was *not* accepted and must not replace the V16 preferred baseline. No module source/ZIP or package version was changed in this metadata update.
