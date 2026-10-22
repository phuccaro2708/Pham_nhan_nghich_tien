# STORY_GRAPH — Chương I "Khói Bếp Phàm Trần" + Luân hồi lần đầu

Nguồn: `godot/data/story/chapter1.json` (ch1, **sửa tay từ v1.1**), `chapter4.json` (nhánh quay lại + pháp môn), `chapter5.json` (stub Luyện Khí 9 → Trúc Cơ). `tools/gen_phase2b_data.py` đã **không còn sinh** `chapter1.json` — chạy lại sẽ ghi đè bản này, đừng chạy nó. Quy ước: **◆ = lựa chọn miễn phí** (không `costs`, không `requirements`; bắt buộc có ≥1 ở mỗi nút), `→` = `next`, `[M]` = cần ký ức (`knows mem_*`). Lý do thiết kế: GDD §7.2, §7.4.

## 1. Kiếp thứ nhất (đến mốc, chết, tua)

| Nút | Điều kiện mở | Lựa chọn (chi phí → hệ quả) |
|---|---|---|
| ch1_morning_smoke | Đốn củi ≥ 3 | biếu 5 gỗ → +2 Bà Lý · bán 5 gỗ → +4 bạc · ◆ đi tiếp |
| ch1_village_elder | xong morning_smoke và Đốn củi ≥ 10 | nhận gánh nước · ◆ theo bài tập → +Thể Phách · ◆ từ chối |
| ch1_forest_edge | Rèn thể ≥ 5 | ◆ vào sâu → thảo dược · ◆ nhặt củi · ◆ quay về |
| ch2_mountain_rumor, ch3_crossroads → ch3_study/help/explore | xem phần Chương 2–3 | → `promote_realm cuong_than` |
| **ch1_before_mountain** (mới) | xong ch3_crossroads, ≥ Đoán Thể, chưa `dao_entry`, chưa cờ cũ `ch1_complete` | gói lương 5 gỗ → +1 Thợ săn, cờ `prepared_pack` · ◆ đi tay không. **Cả hai kết bằng `set_checkpoint`.** |
| ch1_wounded_taoist | xong before_mountain | chữa 3 thảo dược → Đạo sĩ +3, `taoist_grateful` · lục túi → +30 bạc, Đạo sĩ −2, `taoist_robbed` · ◆ hỏi han → Đạo sĩ +1. Cả ba cho `mem_taoist_wound` → incident |
| ch1_mountain_incident (chain) | chỉ qua `next` | `[Đạo sĩ ≥ 1]` ở lại bên đạo sĩ → `mem_last_words` · ◆ nép nhìn thợ săn → `mem_cave_site` · ◆ chạy về làng → `mem_pursuer_sign`. **Mọi lựa chọn kết bằng `rewind`** → ch1_return |

Chương I **không cấp** `knows_qi_method`, `dao_entry`, `qi_awareness`, `meridian_lore`.

## 2. Bốn nhánh quay lại

```
                             ┌ rescue [M tai nạn đạo sĩ] ─▶ r_rescue ─▶ taoist_tale ───────────▶ qi_source=guided
ch1_return (chain, ◆ keep) ──┼ trace_hunter [M cave_site] ─▶ r_hunter ─▶ cave_relic ───────────▶ qi_source=relic
                             ├ warn_village [M pursuer_sign] ─▶ r_warn ─▶ r_proof ────────────▶ qi_source=evidence
                             └ ◆ keep_secret ─▶ r_rogue ─┬ ◆ slip_away ─────────────────────────▶ qi_source=rogue
                                                        └ ◆ rob_pouch ─▶ cave_rumor ─────────▶ qi_source=rogue
```

| Nhánh | Nút và lựa chọn chính (giá → hệ quả) | NPC / quan hệ | Tri thức | Nguồn pháp môn |
|---|---|---|---|---|
| (a) cứu | r_rescue: chữa 3 thảo dược (+3) · nẹp 2 gỗ (+2) · `[M last_words]` nhắc lời trăn trối (+3) · ◆ hỏi (+1) → taoist_tale: nghe kỹ `[Đạo sĩ ≥ 3]` thêm `meridian_lore`, `spirit_root_lore` · ◆ vội đi | đạo sĩ **sống** (`npc_taoist_alive`) | `dao_entry`, `heard_of_cultivators`, (+2) | lời đạo sĩ → `ch4_method_guided` |
| (b) thợ săn → hang | r_hunter: phụ 5 gỗ (Thợ săn +2) · ◆ bám theo (−1) → cave_relic: ◆ chép tay (không lấy) · ◆ lấy cả cuộn (Thợ săn −2, +Thể Phách) | thợ săn **sống**, đạo sĩ chết | `dao_entry`, `meridian_lore` nếu chép | Tàn Kinh → `ch4_method_relic` |
| (c) cảnh báo | r_warn: ◆ nói thẳng (Trưởng thôn −2) · biếu Bà Lý 3 gỗ (Bà Lý +2, Trưởng thôn −1) → r_proof: vẽ ấn 2 gỗ (Trưởng thôn +3, `village_believes`) · ◆ tự tìm (+1) | làng nghi rồi tin | `dao_entry`, `heard_of_cultivators` | sách của trưởng thôn → `ch4_method_evidence` |
| (d) im lặng | r_rogue: ◆ rời đi (Bà Lý +1) · ◆ lấy túi (+30 bạc, Đạo sĩ −2) → cave_rumor (**nguồn hang riêng**): ◆ khám phá (+Thể Phách, Bà Lý −1) · ◆ bỏ qua (Bà Lý +1). **Không `next`** — nút sau không còn mở mà không kiểm trigger (F2) | đạo sĩ chết | `dao_entry` | tán tu ở chợ → `ch4_method_rogue` |

## 3. Pháp môn tại Cảm Khí, và kết chương

Nút `ch4_method_<nguồn>` mở khi **≥ Cảm Khí, chưa `knows_qi_method`, và `qi_source` đúng nguồn**. Mỗi nút có một lựa chọn miễn phí (cấp `knows_qi_method`) và một lựa chọn trả giá/điều kiện (thêm `spirit_root_lore`). `ch1_qi_clue` chỉ còn là đường dọn cho save cũ (Cảm Khí, chưa pháp môn, chưa `qi_source`); game mới không bao giờ tới nó (có test).

Chương III stub (`ch5_path_*`, ≥ Luyện Khí 9 và đúng nguồn): `guided`/`evidence` → Thanh Huyền ngoại môn, `relic` → Tàn Kinh tầng sâu, `rogue` → con đường tán tu. Chỉ đặt cờ `truc_co_path`. **AC còn thiếu** (stub): nội dung ngoại môn/bí cảnh, kiểm tra điều kiện Trúc Cơ riêng cho từng đường — làm khi viết Chương III.

## 4. Luật trạng thái khi tua (`rewind`)

| Trạng thái | Khi tua | Lý do |
|---|---|---|
| `story.done`, `story.pending` | **giữ** | đã trải qua; không mở lại sự cố |
| `knowledge` (kể cả `mem_*`) | **giữ** | ký ức/bí mật đã biết |
| `game_time_ticks`, `rng_seed/state`, `save_metadata`, `orphans`, `life.status`, `loop` | **giữ** (`loop` +1) | tính liên tục của nhân vật và mô phỏng |
| `resources`, `upgrades`, `mastery`, `action_counts` | khôi phục từ mốc | thế giới tại mốc |
| `flags`, `relations`, `techniques`, `realm_id`, `age_years`, `breakthrough_failures`, `life.warned` | khôi phục từ mốc | niềm tin phải xây lại; tuổi quay về |
| `active_action` | **xóa, không hoàn chi phí**; `automation` về idle | snapshot là thế giới *trước* khi hành động bắt đầu (chi phí đã trả được cộng vào snapshot) |
| `checkpoint` | **bị dùng hết** (rỗng) | tua lần hai là no-op: không farm được |

Hệ quả có chủ ý: vì `story.done` giữ, mọi effect một-lần của node nằm **sau** mốc không chạy lại. Vì vậy mốc đặt sau Đoán Thể.

## 5. Không softlock — bằng chứng (`tests/unit/test_luan_hoi.gd`)

- Mỗi nhánh × chỉ lựa chọn miễn phí → chạy action `breakthrough`/`sense_qi` thật tới `qi_sensed` và Luyện Khí 1 (`test_every_branch_reaches_sense_qi_with_free_choices_and_real_actions`).
- Trước node pháp môn, `sense_qi` bị từ chối ở cả 4 nhánh; không node nào ngoài `ch4_method_*` và `ch1_qi_clue` đặt `knows_qi_method`.
- Bốn kết cục khác nhau từng cặp ở quan hệ + cờ; bốn `qi_source` khác nhau.
- Save/load ngay sau tua bằng nhau; checkpoint hỏng (NaN, ID lạ, thiếu khóa) bị `validate_state` từ chối; save v4 migrate sang v5.

**Giới hạn đã biết:** chỉ một vòng luân hồi theo truyện; save cũ đang treo `ch1_wounded_taoist` sẽ đi tiếp vào sự cố mà không có mốc (tua là no-op, người chơi vẫn đi tiếp được ở `ch1_return`).

---

# Chương 2–3 (Phase 3, Phase 1)

`ch2_mountain_rumor` (sau `ch1_village_elder` + 25 lần đốn củi) — cả 3 lựa chọn đều cho `heard_of_cultivators`, khác nhau ở hậu quả (quan hệ trưởng thôn / thảo dược / cờ `rumor_dismissed`).

`ch3_crossroads` (sau Ch2 + Sức Bền ≥ 30) — 3 đường:

```
ch3_crossroads ─ study (5 bạc, +literacy) ─▶ ch3_study   ─ careful | skim
               ├ help  (miễn phí)           ─▶ ch3_help    ─ learn_all | take_pay
               └ explore (miễn phí)         ─▶ ch3_explore ─ follow | watch_hidden
```

Mọi lựa chọn cuối cùng: `learn martial_basics` + `promote_realm cuong_than` (Đoán Thể). Lựa chọn "đầy đủ" thêm `body_lore`/`breathing`/…; lựa chọn "nhanh" cho bạc/gỗ thay thế. Chuỗi đạo sĩ (Ch1) giờ chạy sau Đoán Thể và cấp `dao_entry`, `qi_awareness`, `meridian_lore`, `heard_of_cultivators`.

Test: `tests/unit/test_knowledge.gd` — `test_three_routes_reach_martial_basics_and_dan_the`, `test_every_route_has_a_free_fallback_that_still_promotes`, `test_poor_player_can_still_take_a_route`.
