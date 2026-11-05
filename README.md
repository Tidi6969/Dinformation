# Dinformation — phiên bản mới nhất V29

## Trạng thái hiện hành (05/11/2026, Asia/Bangkok)

- **Mới nhất đã lưu thực tế trên GitHub:** **V29**, [Dinformation-V29.zip](Dinformation-V29.zip) ở thư mục gốc.
- **Đề nghị ghi nhận OK:** chủ dự án nói “tương tự https://github.com/Tidi6969/Dinformation” ngay sau yêu cầu đồng bộ “tương tự V105 ok” cho Dlayout. Theo ngữ cảnh, ghi `UserReportedWorking=YES (ContextInferred)` đối với phiên bản V29 mới nhất; đây là **diễn giải yêu cầu tương tự, không phải lời xác nhận trực tiếp 'V29 đã chạy test OK' hay bằng chứng từ CAD thực tế**.
- **Xác nhận build riêng của V29:** `UserReportedBuild=NotSpecified`. **BuildStatus, NETLOAD, Runtime theo từng CAD host:** `NotVerified`; chưa có log hoặc danh sách host V29. Không tự gán PASS bốn host.
- **StandardsStatus:** `NotVerified` cho source/SDK/cấu trúc ZIP V29; nội dung ZIP, CRC, SHA-256 chưa kiểm tra trong lần đồng bộ metadata.
- **CAD target lịch sử:** AutoCAD 2022, AutoCAD 2025, GstarCAD 2018, GstarCAD 2027 (ghi trong hồ sơ V20, không phải kết quả kiểm thử V29).
- **ZIP V29:** `Dinformation-V29.zip`, **10.886.377 byte**, Git blob `30de9f8934c9e311455489d68fa60b7f65a7f509`. [Commit upload](https://github.com/Tidi6969/Dinformation/commit/8c206a4e6a88042beb520937f0813f8e7feff734).
- **Baseline mặc định cho yêu cầu phát triển mới không chỉ định nguồn:** **V29**, theo STD-17 §2.1, cần xác minh nội dung ZIP trước khi sửa. Nếu tạo bản phần mềm mới mà không chỉ định version đích thì **V30** theo max+1; **không tạo V30 trong lần cập nhật metadata này**. Nguồn kỹ thuật tạo V29 chưa xác minh.

## Hồ sơ và liên kết

- [ZIP V29](Dinformation-V29.zip)
- [Change log / ghi nhận V29](Change%20log/V29.txt)
- [Biên bản đánh giá V29 trên DCAD](https://github.com/Tidi6969/DCAD/blob/main/Assessments/Dinformation-V29.md)
- [Danh mục DCAD tổng hợp](https://github.com/Tidi6969/DCAD/blob/main/README.md)
- [Quy ước 17](https://github.com/Tidi6969/QuyUoc/blob/main/17_Autoupdate.md)

## Cây lưu trữ trên main

```text
Dinformation/
├── Dinformation-V29.zip
├── V17/
│   └── Dinformation-V17.zip
├── V18/
│   └── Dinformation-V18.zip
├── V19/
│   └── Dinformation-V19.zip
├── V20/
│   └── Dinformation-V20.zip
├── Change log/
│   ├── V17.txt
│   ├── V18.txt
│   ├── V19.txt
│   ├── V20.txt
│   └── V29.txt
└── README.md
```

## Lịch sử và baseline chức năng V16

- Trong lần phản hồi trước ngày 05/11/2026, chủ dự án từng chỉ định **V16 làm bản nguồn ưu tiên về hành vi chức năng** sau khi các thử nghiệm dựa trên V17/V21 chưa đáp ứng mong muốn. ZIP V16 đã được gửi qua ChatGPT, **chưa lưu trong repo này**; không tạo đường dẫn GitHub V16 giả.
- Hồ sơ V16 từng được rà soát CRC PASS và SHA-256 `1931870d9e7b343463bee5ea0644b04cfa132001e06daf77fc8584477bb672c9`; ZIP nguồn đó không có DLL mới build, Build/NETLOAD/Runtime riêng host `NotVerified`.
- Ghi V29 là phiên bản mới nhất không chứng minh các hành vi ưu tiên của V16 đã có trong V29. Nếu anh chỉ định V16 làm baseline cho một sửa đổi cụ thể, vẫn phải ưu tiên chỉ định đó và dùng đúng gói nguồn.
- **V20** đã lưu như một bản source/build candidate của bốn host (theo metadata của V20, Build PASS, NETLOAD/Runtime/Standards `NotVerified`, ReleaseApproved=NO). [Changelog V20](Change%20log/V20.txt). Không áp kết quả build V20 sang V29.
- Các ZIP V17/V18/V19/V20 cùng changelog được giữ nguyên. Đợt đồng bộ này chỉ cập nhật README, changelog V29 và hồ sơ đánh giá trong DCAD, **không sửa/bổ sung mã nguồn hay ZIP, không build lại**.
