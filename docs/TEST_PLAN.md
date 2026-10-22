# TEST_PLAN

Chạy toàn bộ: `godot --headless --path godot -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` (Phase 2B: **126/126 pass**).

| Nhóm | File | Bao phủ |
|---|---|---|
| Unit | `tests/unit/*` | resource/condition/effect, tuổi, cảnh giới, save |
| Unit Phase 2B | `tests/unit/test_phase2b.gd` (28) | đường cong XP; XP chỉ khi hoàn tất đủ chu kỳ; mốc trả đúng một lần; bonus suy ra (không lưu); nhóm bonus cộng trong/nhân giữa; trigger story, chọn có chi phí/yêu cầu, nút `chain_only`, mọi đường tới pháp môn, hoàn chương chỉ bằng lựa chọn miễn phí; chuỗi tu luyện; công pháp; hoàn thất bại; validator (không lựa chọn miễn phí, chu trình, `next` lạ, `advance_realm` trong mastery/story, thiếu text, breakthrough automatable) |
| Integration | `tests/integration/test_save_offline.gd` | save/load, offline, hỏng file, migration |
| Integration Phase 2B | `tests/integration/test_automation.gd` (14) | khóa mở, validate ô, chạy tuần tự, skip/stop/wait, deadlock, vòng lặp không tiến triển, ghi đè tay, story chặn hàng đợi, offline từ chối action không cho phép, **offline ≡ online**, round-trip save giữa chừng, migration v2→v3 |
| Simulation | `tests/simulation/test_progression_sim.gd`, `tools/balance_sim.gd` | bot chơi hết MVP; báo cáo cân bằng theo chiến lược |
| Thủ công | `tools/ui_shot.gd` | ảnh chụp UI 1280×720 cho mọi tab |

Quy tắc: sửa lỗi logic phải kèm test hồi quy; số cân bằng trong test đọc từ data (không hard-code).
