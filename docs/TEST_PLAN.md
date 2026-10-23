# TEST_PLAN

Chạy toàn bộ: `godot --headless --path godot -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` (hiện **173/173 pass**, xem mục Luân hồi).

| Nhóm | File | Bao phủ |
|---|---|---|
| Unit | `tests/unit/*` | resource/condition/effect, tuổi, cảnh giới, save |
| Unit Phase 2B | `tests/unit/test_phase2b.gd` (28) | đường cong XP; XP chỉ khi hoàn tất đủ chu kỳ; mốc trả đúng một lần; bonus suy ra (không lưu); nhóm bonus cộng trong/nhân giữa; trigger story, chọn có chi phí/yêu cầu, nút `chain_only`; chuỗi tu luyện; công pháp; hoàn thất bại; validator (không lựa chọn miễn phí, chu trình, `next` lạ, `advance_realm` trong mastery/story, thiếu text, breakthrough automatable) |
| Integration | `tests/integration/test_save_offline.gd` | save/load, offline, hỏng file, migration |
| Integration Phase 2B | `tests/integration/test_automation.gd` (14) | khóa mở, validate ô, chạy tuần tự, skip/stop/wait, deadlock, vòng lặp không tiến triển, ghi đè tay, story chặn hàng đợi, offline từ chối action không cho phép, **offline ≡ online**, round-trip save giữa chừng, migration v2→v3 |
| Simulation | `tests/simulation/test_progression_sim.gd`, `tools/balance_sim.gd` | bot chơi hết MVP; báo cáo cân bằng theo chiến lược |
| Thủ công | `tools/ui_shot.gd` | ảnh chụp UI 1280×720 cho mọi tab |

Quy tắc: sửa lỗi logic phải kèm test hồi quy; số cân bằng trong test đọc từ data (không hard-code).


## Phase 3 — Knowledge System

`tests/unit/test_knowledge.gd` (+ `TestHelpers.world(seed, knowing_all)`):
- `knows`/`learn_knowledge` idempotent, validate id lạ.
- `not_discovered` ở `check_can_start`, `set_slots`, và khi hàng đợi/offline chạy action đã bị "quên" trong save.
- Migration v3→v4 suy kiến thức (đã tu luyện / phàm nhân), id lạ → `orphans`.
- `promote_realm` chỉ từ stage `story_promotion`.
- 3 route Ch3 và 3 lựa chọn dự phòng đều tới `martial_basics` + Đoán Thể; người thiếu bạc vẫn qua được; sự kiện không tự chọn.
- Tri thức tu luyện đến sau luân hồi, không phải ở kiếp một (`test_cultivation_knowledge_comes_after_the_rewind_not_in_life_one`).


## Luân hồi lần đầu (GDD §7.4)

`tests/unit/test_luan_hoi.gd` (19): hợp đồng tua (giữ story/knowledge/đồng hồ/RNG; khôi phục tài nguyên, cờ, quan hệ, cảnh giới, tuổi; bỏ action đang chạy không hoàn phí; checkpoint dùng một lần); lựa chọn `mem_*` bị chặn khi thiếu ký ức; cả 4 nhánh chỉ bằng lựa chọn miễn phí tới `sense_qi` + Luyện Khí 1 bằng action thật; `sense_qi` bị từ chối trước node pháp môn; kết cục 4 nhánh khác nhau từng cặp; nhánh cướp có nguồn hang riêng; `ch1_qi_clue` không với tới ở game mới; round-trip save sau tua; migration v4→v5; checkpoint hỏng bị từ chối; `rewind` không phải effect cuối bị validator chặn.

Kết quả chạy đầy đủ (headless): **169/169 pass**, 10 script, 1581 assert.


## Bí cảnh / combat (schema 6)
`tests/unit/test_combat.gd` (10): điều kiện vào (chưa khám phá, đang trong bí cảnh, ID lạ); vào dừng action và chặn start; cùng seed → trạng thái giống hệt, HP không âm, run luôn kết thúc; thanh tẩy trả thưởng đúng một lần; thua/rút lui chỉ tốn tuổi; tỉ lệ thắng của nhân vật gốc; round-trip JSON giữa trận tiếp tục giống hệt; save combat hỏng bị từ chối; migration v5→v6; offline hủy lượt không phí.

Kết quả chạy đầy đủ (headless): **183/183 pass**, 11 script, 1852 assert.

## V1 — `tests/unit/test_path.gd`

Ẩn mục chưa khám phá, lý do chặn + việc kế, chỉ manh mối đã biết, PathSystem thuần (không đổi `to_dict`), key vi/en đủ, validate tham chiếu sai, xem trước lựa chọn không spoil, biến thể văn bản, sổ nhân quả. Kết quả: 194/194 pass.

## V2 — `tests/unit/test_main_technique.gd`

Chỉ chủ tu có bonus; 3 build khác biệt; luật + chi phí đổi chủ tu; 3 hành động học; thương tích (thua, Huyết Luyện, abort, trần, hồi, Thanh Mộc); save round-trip + validate; migration v6→v7 (cả mốc); mốc mang build/thương; validate traits/role. Kết quả: 205/205 pass.

## V3 — `tests/unit/test_prepared_dungeon.gd`

Tầng là dữ liệu (kể cả `enemies` phẳng); điều kiện vào; tầng sâu mạnh hơn và lợi hơn; chuyến dừng chờ người chơi, đợi không tốn tuổi, offline không quyết thay; `leave_run` giữ lợi và trả tuổi theo tầng; `continue/leave` chỉ khi đang dừng; thông hết trả thưởng đúng một lần và ghi `last_run`; đan trừ khi vào, từ chối không tốn gì; đan tự uống khi máu thấp; thua ghi nguyên nhân + thương tích; tái lập từ cùng seed; chuẩn bị đổi kết quả (20 seed, không đan vs 5 đan); luyện đan; save round-trip lúc đang dừng + validate (tier/pills/index/last_run sai); migration 7→8; validate content tầng sai.

## V4 — `tests/unit/test_research.gd`

Khiếm khuyết cần chứng cứ; hướng nghiên cứu đóng đến khi thấy khiếm khuyết; cần công pháp gốc; từ chối không mất gì; biến thể có cái giá; 3 hướng ra 3 biến thể khác nhau; thất bại hoàn một phần + pity; tất định theo seed; thưởng một lần và save round-trip + validate; không nghiên cứu khi ở bí cảnh/đã chết; migration 8→9; validate content; localization vi/en.

## V5 — `tests/unit/test_story_echo.gd`

Node chờ thông hang mới mở; văn bản khác nhau cho từng nguồn pháp môn; mỗi nhánh chỉ thấy lựa chọn riêng + lựa chọn miễn phí; 4 nhánh hội tụ ở một node với cờ/quan hệ/tài nguyên khác nhau; `walk_on` vẫn hội tụ; không mở lại và không trả thưởng hai lần qua save/load; mọi choice có hint và hiện trong sổ Nhân Quả; localization vi/en.

## V6 — `tests/unit/test_breakthrough_chance.gd`, `tests/simulation/test_vertical_slice_sim.gd`

Số hạng có dữ liệu, P trong [min, max ≤ 0,8]; P phản ánh mastery/thương tích/Đạo Tâm/công pháp; kẹp sàn trần; automation và offline không đột phá; pity ssau 3 lần hỏng; số hạng sai bị validate chặn. Sim: 3 công pháp chủ tu × 3 seed tới Trúc Cơ còn sống, cả khi thiếu mảnh công pháp.
