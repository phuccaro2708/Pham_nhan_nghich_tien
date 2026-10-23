# Báo cáo cân bằng V6 — đột phá Trúc Cơ

Lệnh: `godot --headless --path godot -s tools/balance_sim.gd -- --seeds=20`.

## Công thức mới
`P = clamp(0,45 + Σ số hạng + insight công pháp, 0,30, 0,80)`; pity sau 3 lần hỏng vẫn chắc chắn thành.

| Số hạng (`when`) | Trọng số | Ý nghĩa |
|---|---|---|
| mastery `absorb_qi` ≥ 10 / ≥ 20 | +0,08 / +0,05 | nền tảng |
| thương tích ≥ 1 / ≥ 3 / ≥ 5 | −0,05 / −0,05 / −0,10 | cái giá của thám hiểm và nghiên cứu liều |
| chọn một `echo_*` ở `ch6_rock_echo` | +0,06 | Đạo Tâm từ story (V5) |
| `insight_modifier` công pháp (có sẵn) | +0,03…+0,10 | ổn định công pháp / biến thể |

Trần 0,80 theo GDD §6.5 (trước đó dữ liệu là 0,95).

## Kết quả bot (20 seed, 20/20 tới Trúc Cơ, 0,95 lần hỏng TB)
casual median 5,31 giờ chủ động; optimizer 4,74; idle 4,01 — không đổi đáng kể so với Phase 2B.

## Hạn chế (nói thẳng)
- Bot không đi thám hiểm, không nghiên cứu, không chọn echo, nên các số hạng thương tích/Đạo Tâm chưa được mô phỏng, chỉ được test đơn vị (`test_breakthrough_chance.gd`).
- `test_vertical_slice_sim.gd`: 3 công pháp chủ tu × 3 seed tới `truc_co_so` còn sống, kể cả khi không có mảnh công pháp. Đây là kiểm tra không softlock, chưa chứng minh 3 hướng khác nhau về nhịp chơi.
- Các trọng số chưa tinh chỉnh bằng mô phỏng có thám hiểm; cổng "3 hướng khác nhau thật" cần bot biết đi hang trước khi nhân rộng sang GĐ2.
