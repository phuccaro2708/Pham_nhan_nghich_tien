# TEST_PLAN

Chạy toàn bộ: `godot --headless --path godot -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` (hiện **169/169 pass**, xem mục Luân hồi).

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
