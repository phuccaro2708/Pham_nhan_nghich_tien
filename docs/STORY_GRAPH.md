# STORY_GRAPH — Chương 1 "Khói Bếp Phàm Trần"

Nguồn: `godot/data/story/chapter1.json` (8 nút, sinh bởi `tools/gen_phase2b_data.py`). Quy ước: **◆ = lựa chọn miễn phí** (bắt buộc có ≥1 ở mỗi nút), `→` = `next`.

| Nút | Điều kiện mở | Lựa chọn (chi phí → hệ quả) |
|---|---|---|
| ch1_morning_smoke | Đốn củi ≥ 3 lần | biếu 5 gỗ → +2 quan hệ Bà Lý · bán 5 gỗ → +4 bạc · ◆ đi tiếp |
| ch1_village_elder | xong morning_smoke và Đốn củi ≥ 10 | nhận gánh nước → cờ `job_water`, +1 trưởng thôn · ◆ theo bài tập → +Thể Phách · ◆ từ chối |
| ch1_forest_edge | Rèn thể ≥ 5 lần | ◆ vào sâu → cờ `herb_path`, +thảo dược · ◆ nhặt củi → +gỗ · ◆ quay về |
| ch1_wounded_taoist | xong forest_edge và cảnh giới ≥ Đoán Thể | chữa (3 thảo dược) → taoist_tale · cướp → +bạc, cờ `taoist_robbed` → cave_rumor · ◆ hỏi han → taoist_tale |
| ch1_taoist_tale | chỉ qua `next` | ◆ nghe kỹ → `knows_qi_method`, `ch1_complete` · ◆ vội đi → `knows_qi_method`, `ch1_complete` |
| ch1_cave_rumor | chỉ qua `next` | ◆ khám phá → +Thể Phách → qi_clue · ◆ bỏ qua → qi_clue |
| ch1_qi_clue | Cảm Khí và chưa có pháp môn | ◆ ngộ ra → `knows_qi_method`, `ch1_complete` |
| ch1_neighbor_gift | quan hệ Bà Lý ≥ 2 | ◆ nhận → +bạc, +thảo dược · ◆ từ chối → +1 quan hệ |

```
morning_smoke ─▶ village_elder
forest_edge ─▶ wounded_taoist ─┬ chữa/hỏi ─▶ taoist_tale ─▶ [pháp môn]
                               └ cướp ─────▶ cave_rumor ─▶ qi_clue ─▶ [pháp môn]
neighbor_gift (nhánh phụ theo quan hệ)
```

**Không softlock**: mọi đường đến `knows_qi_method` (điều kiện của *Cảm ứng linh khí*, tức của Luyện Khí). Test `test_every_path_from_the_taoist_reaches_qi_method` duyệt mọi lựa chọn; `test_free_choices_alone_finish_chapter_one` hoàn thành chương chỉ bằng lựa chọn miễn phí. Hậu quả có thật nhưng không khóa vĩnh viễn: cướp đạo sĩ mất quan hệ/đổi nhánh nhưng vẫn nhận pháp môn.


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
