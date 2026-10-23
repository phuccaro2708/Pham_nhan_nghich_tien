# MVP_BACKLOG — 3 giai đoạn × 6 tính năng

Nguồn: GDD §XIV.1. Mỗi version nhỏ: docs → test → GUT xanh → báo cáo → duyệt. Version nào đụng state thì nâng `schema_version`.

| Version | Tính năng | Giai đoạn | Schema | Trạng thái |
|---|---|---|---|---|
| V0 | Nền, scope, backlog | GĐ1 | 6 | Xong (183/183 GUT) |
| V1 | Tiên Lộ + phản hồi lựa chọn | GĐ1 | 6 | Xong (đã duyệt) |
| V2 | Công pháp chủ tu + thương tích | GĐ1 | 7 | Xong (đã duyệt) |
| V3 | Thám hiểm chuẩn bị (Hắc Thạch Động, không rút lui tự động) | GĐ1 | 8 | Xong (đã duyệt) |
| V4 | Nghịch Mệnh Tàn Kinh | GĐ1 | 9 | Xong (đã duyệt) |
| V5 | Story hệ quả về sau | GĐ1 | 9 | Xong (đã duyệt) |
| V6 | Đột phá Trúc Cơ + cổng lát cắt (3 hướng) | GĐ1 | 9 | Xong (đã duyệt) |
| V7 | Chống softlock chiến dịch dài | GĐ1 | 9 | Xong (đã duyệt) |
| V8 | Nền GĐ2: đại cảnh giới Kim Đan–Hóa Thần trong `realms.json`, thọ nguyên, validator; chưa có nội dung chơi | GĐ2 |  9 | Xong (đã duyệt) |
| V9 | Kim Đan: ổn định công pháp, `dan_grade` từ công pháp + mastery + thương tích | GĐ2 | 10 | Xong (chờ duyệt) |
| V10 | Truyền thừa hậu duệ + Đạo Quả (thay `deceased` cụt) | GĐ2 | 11 | Đề xuất |
| V11 | Nguyên Anh: tri thức + quan hệ, nguyên thần | GĐ2 | 12 | Đề xuất |
| V12 | Khu thám hiểm + biến thể Tàn Kinh tầng Kim Đan/Nguyên Anh (dùng lại V3–V4) | GĐ2 | 12 | Đề xuất |
| V13 | Hóa Thần: chọn đạo tắc, đóng hướng còn lại | GĐ2 | 13 | Đề xuất |
| V14 | Cổng GĐ2: bot 3 hướng tới Hóa Thần (qua một truyền thừa), softlock, cân bằng | GĐ2 | 13 | Đề xuất |
| GĐ3 | Độ Kiếp → Phi Thăng | GĐ3 | — | Backlog |

Cổng sang GĐ2: bot đi 3 hướng công pháp tới `truc_co_so` còn sống (cả khi thiếu một tài nguyên hiếm), báo cáo cân bằng, Codex review độc lập.

## Chốt giai đoạn 1 (V0–V7 đã duyệt, 255/255 GUT)

Còn mở trước khi code GĐ2 (cổng chưa đạt đủ):
- Codex review độc lập cho toàn bộ GĐ1.
- Bot biết đi thám hiểm/nghiên cứu để mô phỏng số hạng thương tích và Đạo Tâm, rồi chỉnh trọng số `chance.terms` (xem `BALANCE_SIM_V6.md`).
- Thử tay UI V4–V7.
