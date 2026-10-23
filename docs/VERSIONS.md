# VERSIONS — nhật ký toàn bộ version V0 → cuối

Nguồn kế hoạch: [MVP_BACKLOG.md](MVP_BACKLOG.md) · thiết kế: [GDD.md](GDD.md) §XIV. Mỗi version: docs → test → GUT xanh → duyệt. Số GUT là tổng test sau version đó.

## Giai đoạn 1 — Phàm Nhân → Trúc Cơ (đã chốt)

| Version | Nội dung | Commit | Schema | GUT | Trạng thái |
|---|---|---|---|---|---|
| V0 | Nền, scope 3 giai đoạn, MVP_BACKLOG, sửa CLAUDE/AGENTS | `b2fc5ab` | 6 | 183 | Đã duyệt |
| V1 | Tiên Lộ (PathSystem), xem trước lựa chọn, biến thể văn bản, sổ Nhân Quả | `57a79d0` | 6 | — | Đã duyệt |
| V2 | Công pháp chủ tu (Thanh Mộc, Huyết Luyện, Ngũ Hành), thương tích | `74baadd` | 7 | — | Đã duyệt |
| V3 | Thám hiểm có chuẩn bị, Hắc Thạch Động, tầng + tạm dừng, đan hồi phục | `e6b6c48` | 8 | — | Đã duyệt |
| V4 | Nghịch Mệnh Tàn Kinh: nghiên cứu công pháp biến thể, pity | `9b5da19` | 9 | 242 | Đã duyệt |
| V5 | Story hệ quả về sau, node `ch6_rock_echo` | `4ce0bab` | 9 | 250 | Đã duyệt |
| V6 | Số hạng đột phá Trúc Cơ, trần 0,80, sim cổng lát cắt (+ `4dbf948` sửa chính tả) | `5188b1b` | 9 | 255 | Đã duyệt |
| V7 | Kiểm tĩnh chống softlock, test hết thọ nguyên | `5ffb0a9` | 9 | 255 | Đã duyệt |
| — | Chốt GĐ1, ghi việc còn mở | `f8ad245` | 9 | — | — |
| — | Bot đi hang trong balance simulator, test lát cắt có thám hiểm | `333226a` | 9 | 256 | — |

(Ô "—" ở cột GUT: không còn số ghi lại; xem báo cáo từng lượt.)

## Giai đoạn 2 — Kim Đan → Hóa Thần

| Version | Nội dung | Commit | Schema | GUT | Trạng thái |
|---|---|---|---|---|---|
| — | Đề xuất GDD §XIV.2, chia V8–V14 | `dae7844` | 9 | — | Đã duyệt |
| V8 | Thang 28 bậc tới Hóa Thần Viên Mãn, thọ nguyên, validator | `2c01884` | 9 | 261 | Đã duyệt |
| V9 | Kết Đan, phẩm Kim Đan (`dan_grade`) | `0fdc995` | 10 | 270 | Chờ duyệt |
| V10 | Truyền thừa hậu duệ + Đạo Quả (thay `deceased` cụt) | `25dfc98` | 11 | 283 | Chờ duyệt |
| V11 | Nguyên Anh: tri thức + quan hệ, nguyên thần | — | 12 | — | Chưa làm |
| V12 | Khu thám hiểm + biến thể Tàn Kinh tầng Kim Đan/Nguyên Anh | — | 12 | — | Chưa làm |
| V13 | Hóa Thần: chọn đạo tắc, đóng hướng còn lại | — | 13 | — | Chưa làm |
| V14 | Cổng GĐ2: bot 3 hướng tới Hóa Thần qua một truyền thừa, softlock, cân bằng | — | 13 | — | Chưa làm |

## Giai đoạn 3 — Phi Thăng (chưa chia version)

Backlog ghi "Độ Kiếp → Phi Thăng", nhưng thang GDD §3.1 còn Luyện Hư, Hợp Thể, Đại Thừa giữa Hóa Thần và Độ Kiếp. Cần chốt scope và chia version (ước lượng 6–7) sau cổng GĐ2.

## Việc cổng GĐ1 còn mở

- Codex review độc lập toàn bộ GĐ1.
- Bot đi hang chỉnh trọng số `chance.terms` (brief: [CODEX_TASK_bot_hang.md](CODEX_TASK_bot_hang.md)).
- Thử tay UI V4–V9.
