# Báo cáo Phase 1 — Foundation

Kiểm thử: GUT 9.7.1 headless, **49/49 pass** (unit, integration, simulation). Boot headless sạch.
Lệnh: `godot --headless --path godot -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json`

## Đã triển khai
Dự án Godot 4.7 + GUT; GameState, SimulationClock (10 tick/s, số nguyên), ResourceSystem, ActionSystem (INSTANT/TIMED/LOOP, một cổng `advance`), ConditionEvaluator, EffectResolver, ContentRegistry (validate chéo), SaveManager (checksum, atomic, .bak, migration v0→v1, validate), OfflineSystem (cap 8h, báo cáo, `offline_allowed`), RNG seed xorshift32 lưu trong state. Lát cắt kỹ thuật: chặt củi (LOOP) → bán củi → mua rìu sắt → tăng sản lượng; autosave 30 s; UI tối thiểu sinh từ data. Schema: `docs/CONTENT_SCHEMA.md`.

## Review độc lập
Codex **không khả dụng** trong môi trường này; review do một subagent Claude độc lập thực hiện. Các lỗi đã xác minh và sửa: LOOP đốt tuổi khi tài nguyên đã đầy cap (`reward_capped`); handler `action_completed` bắt đầu hành động khác làm mất chi phí; refund bị cap cắt; save hỏng đè mất .bak; `flag_is` lỗi khi khác kiểu; validate nội dung không lưu được (initial>cap, levels, per_level âm, chance). Mỗi lỗi có test hồi quy. **Nên chạy Codex review thật khi có.**

## Chưa triển khai (đúng phạm vi)
Tuổi thọ/tọa hóa (tuổi chỉ tăng), tu luyện/cảnh giới, mastery, hàng đợi tự động cấp 2–3, cốt truyện, chiến đấu, UI hoàn chỉnh (Figma), loại hành động khác của GDD §5.1.

## Vấn đề còn tồn
1. Save có id lạ (nội dung bị xóa/đổi tên) bị từ chối — cần chính sách migration nội dung.
2. `action_count_at_least.action` và tên stat trong bonus chưa validate; action `upgrade` không bắt buộc có `add_upgrade_level`.
3. Không fsync; `load_save()` không phát `game_loaded`.
4. MAX_AMOUNT 1e7 giới hạn tăng trưởng lớn (cần big-number).
5. Bắt đầu lại cùng action = hoàn + trả lại chi phí (đúng nhưng cần UX xác nhận).

## Đề xuất Phase 2 (theo thứ tự phụ thuộc)
1. Lưu trữ số lớn / kinh tế (gỡ MAX_AMOUNT) + chính sách migration id nội dung.
2. Tuổi thọ & tọa hóa; dữ liệu cảnh giới, linh khí, tu vi.
3. Mastery hành động.
4. Hàng đợi tự động cấp 1–3 + xử lý deadlock.
5. Story graph / StoryNode, flag, tạm dừng offline khi có lựa chọn chờ.
6. Công cụ báo cáo cân bằng bằng simulation.
7. UI hoàn chỉnh (Figma), localization hardening.
