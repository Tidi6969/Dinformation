# Dinformation V17

## Phạm vi thay đổi

AutoCAD 2022, AutoCAD 2025 và GstarCAD 2027 chuyển phần nhận diện và đọc thuộc tính đối tượng sang LISP theo cơ chế của nhánh GstarCAD 2018. GstarCAD 2018 giữ nguyên cơ chế launcher + temporary LISP của V16.

**Giao diện không đổi:** AutoCAD/GC2027 vẫn dùng tooltip hiện tại qua `PointMonitor.AppendToolTipText`; không vẽ bảng `SOLID`/`TEXT` theo overlay GC2018.

## Pipeline nhận dạng và hiển thị

1. .NET `PointMonitor` chỉ chuyển tọa độ con trỏ (WCS) vào LISP; không dùng `GetPickedEntities`, không phân loại entity và không đọc thuộc tính bằng .NET.
2. LISP chuyển điểm WCS sang UCS rồi gọi `nentselp`, lấy entity sâu nhất trong block bằng đúng quy tắc của LISP gốc.
3. LISP so sánh entity hiện tại với entity trước, bỏ qua việc đọc lại nếu không đổi, highlight/unhighlight và đọc thuộc tính qua hàm `dis`/ActiveX như nhánh GC2018.
4. LISP trả danh sách dòng thông tin về .NET; .NET chỉ chuyển các dòng sang tooltip hiện tại.
5. Không tạo overlay CAD, không thay UCS/view và không thay đổi dữ liệu bản vẽ.

LISP được nhúng trong DLL dưới dạng template ASCII; nội dung ngôn ngữ được mã hóa `\U+XXXX` khi sinh file tạm. File tạm được load đồng bộ rồi xóa. Hàm LISP được expose cho .NET bridge bằng `vl-acad-defun`.

## Build/package

Run `Build_All.cmd`. After all four host builds pass, the final runtime folder is:

```text
Dprogram\
├─ DinformationC22.dll   # AutoCAD 2022
├─ DinformationC25.dll   # AutoCAD 2025
├─ DinformationG18.dll   # GstarCAD 2018
├─ DinformationG27.dll   # GstarCAD 2027
└─ README.txt
```

Load only the DLL matching the active CAD host. Command: `Dinformation`.

Dinformation does not require DData business files. `Buildtime\Language\lang.dat` is embedded.

## Quy tắc dữ liệu

Runtime path/data rules follow `DCAD-DATA-001`:
- CAD Support File Search Path is read fresh at the start of each command (`ACADPREFIX` adapter per host).
- `MIS_SET.SET` is accepted only from a valid `DUser` resolved from the registered Support Path list.
- A registered `...\DData`, `...\DProgram`, `...\DHelp` or `...\Dicon` entry does **not** allow Dinformation to infer a sibling `DUser`.
- A registered root such as `C:\DCAD` may resolve `C:\DCAD\DUser` when that folder exists.
- Multiple `DUser\MIS_SET.SET` matches are resolved by CAD Support Path order and logged as a conflict.
- Missing/invalid line 28 falls back to embedded Lang_0 (English); Dinformation never creates, rewrites or repairs `MIS_SET.SET`.
- Runtime diagnostics are written only to `%TEMP%\DCAD\Dinformation\log`; the plugin never writes logs beside DLLs in `DProgram`.

## Verification status

V17 source/static package candidate only. This environment does not contain Windows MSBuild/.NET SDK or the CAD hosts, so no compile, NETLOAD or hover runtime result is claimed. `Data\BUILD-STATUS.txt` records this explicitly.
