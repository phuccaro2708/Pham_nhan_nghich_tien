# Báo cáo Phase 2B — Story-driven Incremental Core

## Kết quả
- Balance Simulator (casual / optimizer / idle), 20 seed, median giờ chủ động tới Trúc Cơ:

| Chiến lược | Trước | Sau |
|---|---|---|
| optimizer | 11,13 | **4,70** |
| casual | 11,87 | 5,22 |
| idle | 9,75 | 4,01 |

  Số liệu thô: [BALANCE_SIM_PHASE2B.md](BALANCE_SIM_PHASE2B.md). Phân tích và các núm đã chỉnh: [BALANCE.md](BALANCE.md). Không đổi công thức; chỉ đổi dữ liệu có bằng chứng (hoàn trả `on_fail_refund` 0,8; tốc độ công pháp mở đầu; mốc mastery hấp thu/luyện hóa) — ghi trong GDD §6.5.
- Action Mastery, Automation Queue (≤3 slot, repeat/skip/wait/stop, phát hiện deadlock, online ≡ offline, không tự chọn story, không tự đột phá), Story Graph chương 1 (không softlock), chuỗi tu luyện gắn công pháp mở đầu, UI 4 tab ở 1280×720 (đã chụp kiểm tra).

## Test (GUT headless)
- Toàn bộ suite: **132/132 pass**, 910 assert. Phase 2B thêm `test_phase2b.gd` (28), `test_automation.gd` (20 gồm 6 hồi quy từ Codex).
- Cảnh báo ObjectDB leak lúc thoát là của harness GUT, không phải lỗi logic.

## Thay đổi schema
- `schema_version` 2 → 3: thêm `mastery`, `relations`, `techniques`, `story`, `automation`. Migration v2→v3 giữ nguyên tiến trình (có test). ID lạ vào `orphans`, trở lại khi nội dung quay lại (kể cả `story_pending`).

## Review độc lập (Codex, read-only) — xử lý
| # | Phát hiện | Kết luận |
|---|---|---|
| 1 | `set_slots`/`start` khi đang chạy để lại `queue_slot` cũ → ghi nhầm slot | Xác nhận, đã sửa + test |
| 2 | `start()` khi LOOP thủ công đang chạy → hàng đợi kẹt `running` | Xác nhận, đã sửa (dừng action với lý do `switched`) + test |
| 3 | INSTANT thủ công không dừng hàng đợi | Chủ ý thiết kế: chỉ action *có thời lượng* làm gián đoạn; ghim bằng test |
| 4 | `add_resource` dùng cộng gộp thay vì `yield_multiplier` | Xác nhận, đã sửa + test phần thưởng thực (6,6). Bot không mua rìu nên số cân bằng không đổi |
| 5 | Save chấp nhận choice id lạ trong `story.done` | Chấp nhận có chủ ý (không brick save khi sửa nội dung); ghi vào tồn đọng |
| 6 | `story.pending` bị park không được khôi phục | Xác nhận, đã sửa + test |

## Tồn đọng
- Bot mô phỏng không mua rìu nên mốc `first_upgrade` trống, và không dùng hàng đợi (chỉ tiết kiệm thao tác, không đổi tốc độ).
- Choice id lạ trong `story.done` được dung thứ.
- Codex không chạy được Godot; kết quả test chỉ do phía này chạy.
- Chưa commit.

## Đề xuất Phase 3
1. Bot dùng nâng cấp và hàng đợi để đo giá trị automation thật.
2. Chương 2 + nhánh quan hệ ảnh hưởng đột phá Trúc Cơ.
3. Công pháp thứ hai và ràng buộc tương tác với mastery.
4. Cân lại sàn/trần xác suất Trúc Cơ (điểm mở còn lại).
5. Thêm âm thanh/phản hồi cho sự kiện story và mốc mastery.
