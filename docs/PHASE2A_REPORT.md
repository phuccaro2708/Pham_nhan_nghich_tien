# Báo cáo Phase 2A — Core Progression

Ngày: 2026-10-21 · Godot 4.7.2 · GUT 9.7.1 · Kết quả test cuối: **79/79 pass** (lệnh headless trong CLAUDE.md).

## 1. Hệ thống đã triển khai

- **Audit**: chạy lại GUT (51/51 trước khi sửa), boot headless scene chính không lỗi, xử lý vấn đề tồn đọng của Phase 1 (id lạ, validate `action_count_at_least`/stat, số lớn).
- **Validate nội dung + migration**: `ContentRegistry` kiểm tra mọi id tham chiếu (action/realm/resource/upgrade, stat bonus, condition, effect, breakthrough, `cap_from`, config, migrations). `ContentMigration` đổi tên id theo `data/migrations/content.json` (có phiên bản), id lạ vào `orphans` (không xóa, trả lại khi id trở lại), action đang chạy mà không còn tồn tại bị hủy + hoàn chi phí. Save từ content mới hơn bị từ chối, không ghi đè.
- **Số lớn**: giữ float64, `MAX_AMOUNT` 1e7 → 1e15; `snap` theo độ lớn (thập phân 6 chữ số dưới 1e8, số nguyên từ 1e8). Không dùng BigNumber — bằng chứng: fuzz 300k giá trị 1e-6…1e15, 0 lỗi round-trip JSON.
- **Tuổi & thọ nguyên** (`LifespanSystem`): tuổi chỉ đổi khi action hoàn tất (qua `commit_age`); không trừ tuổi khi từ chối khởi động/reward_capped; thọ theo từng stage; cảnh báo một lần ở ≤ 5 năm (config); chạm giới hạn → tọa hóa, hủy action, chặn mọi action. Không có luân hồi.
- **Cảnh giới** (`RealmSystem`, `data/realms/realms.json`): Phàm Thể → Cường Thân → Cảm Khí → Luyện Khí 1–9 → Trúc Cơ Sơ Kỳ (13 stage). Chi phí/điều kiện/xác suất/pity/cap tu vi đều trong data; một đường đổi trạng thái duy nhất `RealmSystem.attempt` qua effect `advance_realm`. Đột phá Luyện Khí 9 → Trúc Cơ: xác suất 45% (30–95%), 3 lần hỏng thì chắc chắn, thất bại gây `meridian_damaged` (chữa bằng `treat_meridian`).
- **Nội dung mới**: tài nguyên `body`, `spirit_qi`, `cultivation`; action `train_body`, `absorb_qi`, `refine_qi`, `breakthrough`, `treat_meridian`; điều kiện `realm_at_least`.
- **UI/Controller**: hiển thị cảnh giới, tuổi/thọ, cảnh báo, trạng thái tọa hóa, nút “cuộc đời mới” chỉ khi đã chết; UI đi qua command của `GameController`; báo cáo offline đọc từ controller.

## 2. File tạo / sửa

Tạo: `core/content_migration.gd`, `systems/realm_system.gd`, `systems/lifespan_system.gd`, `data/realms/realms.json`, `data/config/progression.json`, `data/migrations/content.json`, `data/actions/cultivation.json`, `tests/unit/test_progression.gd`, `tests/simulation/test_progression_sim.gd`, `docs/PHASE2A_REPORT.md`.

Sửa: `core/{game_state,content_registry,effect_resolver,condition_evaluator}.gd`, `systems/{resource_system,action_system}.gd`, `autoload/{save_manager,game_controller,event_bus}.gd`, `scenes/ui/main_ui.gd`, `data/resources/base.json`, `data/localization/vi.json`, `tests/integration/test_save_offline.gd`, `docs/CONTENT_SCHEMA.md`.

## 3. Kết quả test

- GUT headless: **79 test, 79 pass, 0 fail** (51 của Phase 1 + 28 mới).
- Mới: nội dung hợp lệ + tham chiếu sai bị báo; số lớn round-trip/clamp/cap theo cảnh giới; cảnh báo một lần; tọa hóa; không trừ tuổi khi từ chối; đột phá (thiếu chi phí, thất bại, pity, stage cuối, cổng realm); migration (đổi tên, không ghi đè, orphan, trả orphan, hủy action lạ, v1→v2, content mới hơn); mô phỏng bot tới Trúc Cơ còn sống, deterministic; offline = online cho vòng tu luyện.
- Mô phỏng bot tham lam (seed 11): tới Trúc Cơ sau **~11,1 giờ** chơi, tuổi ~53,5 (thọ Luyện Khí 120) — **chưa đạt mục tiêu GDD 3–5 giờ** (xem rủi ro).
- UI: chỉ kiểm tra boot headless (không lỗi script, `_build`/`_refresh` chạy). **Chưa** chụp/xem trực quan UI.

**Review độc lập**: Codex CLI 0.163.0 có sẵn và đã chạy 2 lần (read-only, chỉ đọc code, không chạy Godot): (a) Phase 1 → 2 P0, 3 P1, 1 P2; (b) Phase 2A → 2 P1, 2 P2. Mọi phát hiện được tự xác minh trên code trước khi sửa. Không có review nào gán nhãn Codex cho kết quả của Claude.

## 4. Thay đổi schema / save

- `schema_version` 1 → 2: thêm `content_version`, `realm_id`, `breakthrough_failures`, `life {status, warned, ended}`, `orphans`. Migration v1→v2 trong `SaveManager.migrate`, rồi `ContentMigration.apply`.
- Validate thêm: `content_version` không vượt content hiện có, `life`, `realm_id` hợp lệ, tuổi ≤ thọ stage và nhân vật sống phải có tuổi < thọ.
- `MAX_AMOUNT` 1e15 (save cũ vẫn hợp lệ). `orphans.active_actions` khóa theo id.
- Chi tiết: `docs/CONTENT_SCHEMA.md` mục “Phase 2A”.

## 5. Lỗi tìm thấy và đã sửa (đều có test hồi quy)

| # | Mức | Lỗi | Nguồn |
|---|-----|-----|-------|
| 1 | P0 | Thử đổi action khi tài nguyên ở trần: hoàn bị cắt nhưng bước hoàn tác vẫn trừ đủ → mất tài nguyên. Sửa: khôi phục snapshot. | Codex (Phase 1) |
| 2 | P0 | Listener `action_stopped` có thể bắt đầu action khác rồi action mới ghi đè, chạy miễn phí/mất phí đã trả. Sửa: kiểm tra lại sau signal, trả `interrupted`. | Codex (Phase 1) |
| 3 | P1 | Báo cáo offline không tới UI (autoload phát signal trước khi UI tồn tại). Sửa: `last_offline_report`. (Chưa có test tự động — cần scene; đã xác minh bằng đọc luồng + boot.) | Codex (Phase 1) |
| 4 | P1 | `initial` > `MAX_AMOUNT` qua được validate nội dung. Sửa: báo lỗi. | Codex (Phase 1) |
| 5 | P2 | UI gọi thẳng `ActionSystem`/`clock`. Sửa: command trên `GameController`. | Codex (Phase 1) |
| 6 | P1 | Save v1 ở đúng giới hạn tuổi bị “hồi sinh” (status alive). Sửa: migration đánh dấu `deceased`; validate cấm sống ở/vượt giới hạn. | Codex (Phase 2A) |
| 7 | P2 | Nhân vật `deceased` còn `active_action` vẫn hoàn thành action khi load/offline. Sửa: `advance` hủy action và không hoàn thành. | Codex (Phase 2A) |
| 8 | P2 | Orphan action thứ hai ghi đè cái thứ nhất. Sửa: lưu theo id. | Codex (Phase 2A) |

Không sửa (có chủ đích): **P1 Phase 1 #3** — `SimulationClock.feed` bỏ phần dư khi một frame > 5 s mô phỏng; đây là chống “spiral of death”, thời gian vắng mặt đã có đường offline (tối đa 8 h). **P1 Phase 2A #1** — lượng cộng < 0,5 mất khi tài nguyên ≥ 1e8; đã chấp nhận và ghi tài liệu (nội dung hiện chỉ dùng số nguyên).

## 6. Rủi ro còn lại

1. **Cân bằng**: bot tham lam ~11,1 h tới Trúc Cơ so với mục tiêu GDD 3–5 h; hệ số `C0`, Q(L)=100·1,8^(L−1), năng suất vẫn là giá trị khởi tạo từ simulation, chưa tinh chỉnh. Số hạng xác suất Đạo Cơ/Đạo Tâm/Linh Lực chưa có (các hệ thống chưa tồn tại) → xác suất Trúc Cơ hiện chỉ là base 45% + pity.
2. Mất độ chính xác thập phân từ 1e8 (đã chấp nhận); chưa có test khẳng định nội dung không dùng amount lẻ ở quy mô đó.
3. UI mới chỉ kiểm tra boot, chưa xem trực quan; báo cáo offline lúc mở game chưa có test scene.
4. Không fsync khi lưu; “cuộc đời mới” xóa tiến trình hiện tại khi người chơi bấm (chưa có hộp xác nhận).
5. Tọa hóa chưa dẫn tới luân hồi/màn kết thúc — chỉ là trạng thái cuối (đúng phạm vi).
6. Review Codex chỉ đọc code, không chạy runtime; xác nhận runtime chính là bộ test GUT.

## 7. Đề xuất Phase 2B

1. Công cụ báo cáo cân bằng bằng simulation (nhiều seed, chiến lược khác nhau) → chỉnh Q(L), năng suất, giá để về 3–5 h; kiểm lại sàn/trần xác suất Trúc Cơ.
2. Mastery hành động và công pháp cơ bản (tương tác ≥ 2 hệ thống có sẵn), thêm các số hạng Đạo Cơ/Linh Lực cho xác suất đột phá.
3. Hàng đợi tự động cấp 1–3 (+ resume LOOP bị `reward_capped`, xử lý deadlock), tôn trọng tọa hóa và offline 8 h.
4. Story Graph tối thiểu: 1 lựa chọn có hậu quả, tạm dừng offline khi chờ chọn; mở rộng migration cho dữ liệu story.
5. UI: test scene cho báo cáo offline, hộp xác nhận “cuộc đời mới”, hoàn thiện theo Figma.
