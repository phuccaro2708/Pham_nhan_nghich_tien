# PHASE3_STORY_ANALYSIS — Khám phá theo hiểu biết & tuyến Phàm Nhân → Luyện Khí

Phạm vi: Phàm Nhân → Luyện Khí. Phase 1 (đã làm): Knowledge System, cổng khám phá, Chương 1–3 với 3 đường tới Đoán Thể, gộp thẻ sự kiện vào trang Chính.
Phase 2 (kế hoạch): Chương 4–5 (tiên duyên, Dẫn Khí Quyết, nhập đạo → Cảm Khí → Luyện Khí). Phase 3 (kế hoạch): cân bằng lại.

## 1. Điểm bất hợp lý trước thay đổi

| # | Hiện trạng | Vì sao sai |
|---|---|---|
| 1 | "Rèn thể", "Đột phá", "Chữa trị kinh mạch", Thể Phách, "Tuổi x/80" hiện từ giây đầu | Nhân vật 16 tuổi, con nhà tiều phu, chưa biết linh căn/cảnh giới/kinh mạch/tu vi |
| 2 | Header "Cảnh giới: Vô" | "Cảnh giới" là khái niệm nhân vật chưa biết |
| 3 | `ch1_wounded_taoist` kích hoạt bởi `realm_at_least cuong_than` | Cốt truyện phụ thuộc cảnh giới đạt bằng nút Đột phá (nút mà nhân vật chưa nên biết) |
| 4 | Mở khóa theo mastery (gather_herbs mở khi gather_wood ≥ 5) | Nhân vật không "học" gì; chỉ lặp nhiều lần |
| 5 | Chỉ 1 đường tới tiên duyên (đạo sĩ bị thương) | Bỏ lỡ sự kiện là mất cả tuyến; không có lựa chọn học hỏi / giúp người / thám hiểm |
| 6 | `ch1_cave_rumor` không có trigger, chỉ vào được từ nhánh cướp | Nút mồ côi một phần |
| 7 | `visible_when` chỉ ẩn UI | Hàng đợi tự động và offline vẫn chạy được hành động "chưa biết" |

## 2. Thiết kế đã áp dụng

- **Knowledge System**: `data/knowledge/*.json` (`id`, `name_key`, `desc_key`, `group`), `GameState.knowledge` (mảng đã sắp xếp), điều kiện `knows`, effect `learn_knowledge` (idempotent).
- **Cổng thật**: `ActionSystem.check_can_start` trả `not_discovered` khi `visible_when` của action chưa thỏa. UI, `AutomationQueue.set_slots` (từ chối ô) và offline cùng dùng đường này. Tái dùng `ConditionEvaluator`, không có bộ điều kiện thứ hai.
- **Cảnh giới giữ id, đổi nghĩa**: `vo` = Phàm Nhân (thân phận, không phải cảnh giới), `cuong_than` = Đoán Thể (võ học nhập môn), `cam_khi` = nhập đạo. Stage `vo` có cờ `story_promotion` + `mortal`: bước lên Đoán Thể chỉ qua effect `promote_realm` của cốt truyện (không rủi ro, không nghi thức).
- **Đoán Thể → Cảm Khí** vẫn bằng hành động Đột phá, nhưng nút ẩn tới khi `knows dao_entry` (đạt qua chuỗi đạo sĩ ở Phase 1; Phase 2 sẽ có thêm đường).
- **Tuổi**: chỉ hiện "Tuổi: 16" tới khi `knows heard_of_cultivators` (cấu hình `ui.lifespan_visible_when`), sau đó mới hiện giới hạn thọ nguyên.
- **Đổi tên theo hiểu biết**: Rèn thể → "Làm việc nặng" (+Sức Bền, group Việc làng); Thể Phách → "Sức Bền"; Hái thảo dược → "Hái cây thuốc" (cần `herb_basics`).
- **UI**: bỏ tab Cốt truyện; sự kiện đang chờ là thẻ trên cùng trang Chính; quan hệ + lịch sử ở cuối cột phải (cuộn được). Nhóm hành động/tài nguyên trống tự ẩn tiêu đề.

## 3. Đồ thị tri thức (Phase 1)

| Kiến thức | Nhận từ |
|---|---|
| `village_life` | Ch1 `ch1_morning_smoke` (mọi lựa chọn) |
| `breathing` | `ch1_village_elder`/training; route Ch3 |
| `herb_basics` | `ch1_forest_edge`/go_deeper; route help |
| `literacy` | Ch3 route học hỏi |
| `heard_of_cultivators` | Ch2 `ch2_mountain_rumor` (cả 3 lựa chọn, kể cả bỏ qua); chuỗi đạo sĩ |
| `body_lore`, `martial_basics` | Ch3: 3 route × 2 lựa chọn; `martial_basics` luôn có |
| `qi_awareness`, `meridian_lore`, `dao_entry` (+`spirit_root_lore`) | Chuỗi đạo sĩ (`ch1_taoist_tale`) hoặc `ch1_qi_clue` |

## 4. Không softlock

- Mọi node có lựa chọn miễn phí (Registry kiểm tra).
- Ch3: `ch3_crossroads` có 2 lối miễn phí (help, explore); route học hỏi tốn 5 bạc nhưng không bắt buộc. Mỗi route có lựa chọn miễn phí dẫn tới `martial_basics` + `promote_realm`.
- `meridian_lore` đến cùng lúc `dao_entry`, nên Đột phá thất bại luôn có Chữa trị kinh mạch để gỡ.
- Save cũ (v3): `SaveManager.migrate` suy ra kiến thức từ cảnh giới/cờ nên không mất hành động nào đang dùng.

## 5. Rủi ro đã biết

- Điều kiện kích hoạt Ch2 (`gather_wood` ≥ 25) và Ch3 (Sức Bền ≥ 30) thay chi phí 30 Thể Phách cũ của nghi thức vô → cuong_than; Sức Bền không bị tiêu. Simulator: casual 5,31 h (trước 5,22 h), optimizer 4,74 h, idle 4,01 h.
- Văn bản tiếng Anh của Ch2–3 đang là bản giữ chỗ (copy tiếng Việt) tới khi có đợt dịch.
