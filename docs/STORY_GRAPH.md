# STORY_GRAPH — Chương 1 "Khói Bếp Phàm Trần"

Nguồn: `godot/data/story/chapter1.json` (8 nút, sinh bởi `tools/gen_phase2b_data.py`). Quy ước: **◆ = lựa chọn miễn phí** (bắt buộc có ≥1 ở mỗi nút), `→` = `next`.

| Nút | Điều kiện mở | Lựa chọn (chi phí → hệ quả) |
|---|---|---|
| ch1_morning_smoke | Đốn củi ≥ 3 lần | biếu 5 gỗ → +2 quan hệ Bà Lý · bán 5 gỗ → +4 bạc · ◆ đi tiếp |
| ch1_village_elder | xong morning_smoke và Đốn củi ≥ 10 | nhận gánh nước → cờ `job_water`, +1 trưởng thôn · ◆ theo bài tập → +Thể Phách · ◆ từ chối |
| ch1_forest_edge | Rèn thể ≥ 5 lần | ◆ vào sâu → cờ `herb_path`, +thảo dược · ◆ nhặt củi → +gỗ · ◆ quay về |
| ch1_wounded_taoist | xong forest_edge và cảnh giới ≥ Cường Thân | chữa (3 thảo dược) → taoist_tale · cướp → +bạc, cờ `taoist_robbed` → cave_rumor · ◆ hỏi han → taoist_tale |
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
