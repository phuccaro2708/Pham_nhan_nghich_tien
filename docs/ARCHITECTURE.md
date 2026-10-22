# ARCHITECTURE — Phase 2B

Nguồn thiết kế: [GDD.md](GDD.md) §XIII. Tài liệu này mô tả những gì **đã có trong code**.

```
UI (scenes/ui) ──lệnh──▶ GameController ──▶ ActionSystem (facade, đường ghi trạng thái duy nhất)
      ▲                                         ├─ ResourceSystem, LifespanSystem, RealmSystem
      └──────── EventBus (signals) ◀────────────├─ MasterySystem   (XP, mốc, bonus suy ra)
                                                ├─ StorySystem     (đồ thị nút, 1 sự kiện treo)
                                                └─ AutomationQueue (≤3 ô, dùng chính start_action)
GameState (dữ liệu thuần) ◀─ ConditionEvaluator / EffectResolver (tập đã đăng ký) ◀─ ContentRegistry (JSON)
SaveManager (autoload): envelope + SHA-256, file tạm + backup, schema_version + migrate, validate
OfflineSystem: ActionSystem.advance(ticks) với offline_mode = true (≤ 8 giờ)
```

## Luồng một chu kỳ hoàn tất (`ActionSystem._finish_cycle`)

1. Trừ chi phí nếu `cost_timing = complete`, xóa `active_action` **trước** khi trả thưởng (không thể trả hai lần nếu bị gọi lồng).
2. `_complete`: `effects.apply` → tuổi → `action_counts++` → `mastery.on_completed` → `story.scan` → signal.
3. Nếu chu kỳ thuộc hàng đợi: `automation.on_completed` rồi dừng; ô kế do `AutomationQueue.pump` quyết ở tick sau (cùng code online/offline).
4. Ngược lại LOOP tự bắt đầu lại nếu còn đủ điều kiện.

## Bất biến quan trọng

- **Một đường ghi**: UI chỉ gọi `GameController.start_action / stop_action / choose_story / set_queue / start_queue / stop_queue`.
- **Phần thưởng một lần**: mốc mastery ghi `claimed[]` trước khi áp effect; nút story được đánh dấu `done` trước khi áp effect.
- **Hàng đợi không quyết định thay người chơi**: có sự kiện treo → `reason = story_pending`, không chọn gì; `breakthrough` bị cấm xếp hàng; thao tác tay dừng hàng đợi (`manual_override`).
- **Online ≡ offline**: test `test_offline_equals_online_with_queue` (cùng trạng thái cuối). Offline chỉ chạy action `offline_allowed`.
- **Không softlock**: validator đảm bảo mỗi nút story có lựa chọn miễn phí; trigger đơn điệu (chỉ thêm tiến độ); `treat_meridian`/tài nguyên bắt buộc tái tạo được.
- **Bonus là hàm của trạng thái**: `yield = base × (1+U)(1+P)(1+M)`, tốc độ cộng dồn `T = Tbase/(1+S+M)`; không có bonus nào được lưu.

## Tool

`godot/tools/balance_simulator.gd` + `balance_sim.gd` (CLI headless), `tools/ui_shot.gd` (chụp UI, cần cửa sổ thật), `tools/gen_phase2b_data.py` (sinh dữ liệu).

## Combat / Bí cảnh (schema 6)
`CombatSystem` (domain thuần) giữ `state.combat` (dungeon, index, HP hai bên, cooldown). Tiến theo tick cố định qua `ActionSystem.advance`; mọi đòn dùng `SimRng` đã lưu nên tái lập được từ save. Thưởng (loot, clear_effects, tuổi) chỉ áp trong `_kill_enemy`/`_end` sau khi bộ đếm tiến, nên save/load không trả hai lần. Vào bí cảnh dừng action đang chạy và chặn `start_action` (`in_dungeon`). Offline/chết/luân hồi → `abort` (không phí). Tương tác: Lifespan (tuổi mỗi lượt), Resource (loot/thưởng qua EffectResolver), Realm (chỉ số theo tầng) + stat `combat.*` từ nâng cấp.
