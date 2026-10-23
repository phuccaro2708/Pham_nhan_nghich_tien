# BALANCE — Phase 2A (giá trị khởi tạo, chưa tinh chỉnh)

Nguồn sự thật cho số liệu là `godot/data/**`; tài liệu này ghi cách chúng được sinh ra.
`tools/gen_cultivation_data.py` sinh `realms.json`, `cultivation.json` và các khóa liên quan (ghi đè resources/localization — chỉ chạy trên bản gốc Phase 1; sau đó sửa tay data).

| Số liệu | Giá trị | Ghi chú |
|---|---|---|
| Tu vi cần để qua Luyện Khí L | `Q(L) = round(100 · 1.8^(L-1))` | GDD §6.3: 100, 180, 324, 583, 1050, 1890, 3401, 6122, 11020 |
| Cap tu vi ở Luyện Khí L | `2 · Q(L)` | tối đa gấp đôi chi phí đột phá |
| Thọ nguyên | Phàm Nhân 80, Luyện Khí 120, Trúc Cơ 200 | năm |
| Đột phá Vô / Đoán Thể / Cảm Khí | 30 body / 100 body / 200 body + 50 bạc | chắc chắn thành công |
| Đột phá Luyện Khí 9 → Trúc Cơ | tu vi Q(9) + 500 bạc; P=45% (30–95%); pity sau 3 lần hỏng | số hạng Đạo Cơ/Đạo Tâm/Linh Lực chờ hệ thống tương ứng |
| Hỏng đột phá | cờ `meridian_damaged`; chữa 50 bạc, 20 s, 0,05 năm | |
| Action tu luyện | 4 s/vòng; train_body +2 body; absorb_qi +8 linh khí; refine_qi 8 linh khí → 8 tu vi | tuổi 0,002–0,004/vòng |
| Cảnh báo thọ | 5 năm (`config/progression.json`) | |

Đo bằng bot tham lam (seed 11): tới Trúc Cơ sau ~11,1 giờ, mục tiêu GDD 3–5 giờ → cần cân bằng ở Phase 2B.


---

# BALANCE — Phase 2B (đo bằng Balance Simulator)

`godot/tools/balance_simulator.gd` chơi trọn một đời bằng cùng lệnh với UI (`ActionSystem`), 3 chiến lược dùng chung một chính sách tham lam (`BalanceSimulator.policy`, cũng là bot của test GUT):
**casual** (nhìn màn hình mỗi 30 s), **optimizer** (phản ứng ngay), **idle** (phiên 5 phút rồi vắng mặt 8 giờ qua `OfflineSystem`). Mọi bot chọn lựa chọn khả dụng đầu tiên của mỗi sự kiện cốt truyện.
Chạy: `godot --headless --path godot -s tools/balance_sim.gd -- --seeds=20 --out=docs/BALANCE_SIM_PHASE2B.md`. Số liệu thô đầy đủ: [BALANCE_SIM_PHASE2B.md](BALANCE_SIM_PHASE2B.md).

## Phân tích nguyên nhân (đo trước khi sửa)

| Quan sát (20 seed, trước Phase 2B) | Hệ quả |
|---|---|
| 80–85% thời gian chủ động là Hấp thu + Chuyển hóa tu vi; tốc độ cơ sở đúng 1 tu vi/s | thời gian ≈ tổng chi phí tu vi, mọi hệ số đều nhân thẳng vào đó |
| Đột phá thất bại đốt **toàn bộ** Q(9)=11.020 tu vi + 500 bạc; kỳ vọng ~1 lần thất bại/đời | một lần hỏng ≈ +3 giờ, phương sai lớn (worst-best ≈ 3 giờ) |
| Không có nguồn tăng tốc nào ngoài nâng cấp rìu (gỗ) | tu luyện không có "đầu tư" nào cho người chơi |

Không đổi công thức chi phí `Q(L)`, thời gian action, hay P(Trúc Cơ): chỉ thêm *nguồn* tăng tốc có dữ liệu.

## Núm chỉnh (đều trong `tools/gen_phase2b_data.py`)

| Núm | Giá trị | Vai trò |
|---|---|---|
| `FAIL_REFUND_CULTIVATION` | 0,8 (đã thử 0,7) | tỉ lệ tu vi hoàn lại khi đột phá thất bại |
| `TECH_SPEED_ABSORB` / `TECH_SPEED_REFINE` | +50% / +50% (đã thử 25/15, 50/40) | tốc độ của Dẫn Khí Nhập Môn |
| `TECH_INSIGHT` | +5% | cộng vào P(Trúc Cơ) |
| Mastery Hấp thu/Chuyển hóa | cấp 5: +20% sản lượng; cấp 10: +20% tốc độ; cấp 20: +40% sản lượng | bonus suy ra từ cấp |

## Kết quả (median giờ chủ động tới Trúc Cơ, 20 seed, 20/20 tới nơi)

| Chiến lược | Baseline | Sau hoàn 70% + công pháp 25/15 + mastery 10/10/20 | **Hiện tại** | Mục tiêu GDD §11.1 |
|---|---|---|---|---|
| optimizer | 11,13 | 6,48 | **4,70** (3,95–6,12) | 3–5 |
| casual | 11,87 | 8,55 | **5,22** (4,44–6,75) | ~4,5–5 |
| idle (+ offline 8 giờ) | 9,75 | 5,69 | **4,01** (3,51–5,02) | 3–5 |

Bước trung gian cho thấy từng núm: (a) hoàn 70% + công pháp + mastery nhẹ: −42%; (b) công pháp 50/40 và mastery ×2: thêm −24%; (c) hoàn 80% + công pháp 50/50: thêm −9%.
Tuổi lúc tới Trúc Cơ ≈ 38–39 (thọ Luyện Khí 120) → không áp lực thọ nguyên trong MVP.

## Giới hạn đã biết của simulator

- Bot không mua rìu sắt nên mốc `first_upgrade` không xuất hiện; bot không dùng hàng đợi (hàng đợi chỉ đổi *sự tiện lợi*, không đổi sản lượng — đã kiểm bằng test offline ≡ online).
- Chọn story đầu tiên khả dụng; chưa so sánh nhánh (nhánh "cướp" so với "cứu" chỉ khác bạc/quan hệ, không đổi tốc độ tu luyện).
- Casual đang ở cận trên mục tiêu; cần playtest người thật trước khi hạ thêm.


# BALANCE — Phase 3 (Phase 1: Knowledge System)

Bước vô → Đoán Thể chuyển từ nghi thức tốn 30 Thể Phách sang sự kiện Ch3 (cần Sức Bền ≥ 30, không tiêu). Điều kiện Ch2: `gather_wood` ≥ 25.

Simulator 20 seed (`balance_sim --seeds=20`), 20/20 tới Trúc Cơ:

| Chiến lược | Trước | Sau |
|---|---|---|
| casual | 5,22 h | 5,31 h |
| optimizer | 4,70 h | 4,74 h |
| idle | 4,01 h | 4,01 h |

Casual vượt mục tiêu 3–5 h ~0,3 h (đã lệch từ trước, không phải do thay đổi này). Chưa chỉnh số: để Phase 3 của kế hoạch.


## Bí cảnh Rừng Trúc Ảnh (Phase B)
`DMG = max(1, round(ATK − DEF×0.5))`, trượt = 0, chí mạng ×1,5; nhịp = `round(100 / SPD)` tick (0,1 s). Người chơi gốc: HP 60, ATK 7, DEF 1, SPD 10, HIT 0,9; +5%/tầng cảnh giới; hồi 20% HP sau mỗi kẻ địch. Kẻ địch: sói (18/5/0/12), heo rừng (30/6/1/8), rắn (40/8/1/10). Thua chỉ mất 0,02 tuổi (không mất tài nguyên) → không softlock. Mục tiêu: nhân vật gốc thắng khoảng 40–95% (test `test_base_character_can_clear_the_first_dungeon`, 20 seed). Chưa mô phỏng tinh chỉnh sâu hơn.

## Hắc Thạch Động (V3) — đo bằng 40 seed, nhân vật không công pháp chủ tu, đi hết 3 tầng

| Cảnh giới | Đan mang theo | Thông hết | Số tầng vượt trung bình |
|---|---|---|---|
| Luyện Khí 3 | 0 | 0/40 | 1,2 |
| Luyện Khí 3 | 2 | 0/40 | 2,0 |
| Luyện Khí 3 | 5 | 24/40 | 2,6 |
| Luyện Khí 6 | 0 | 0/40 | 1,7 |
| Luyện Khí 6 | 2 | 5/40 | 2,1 |
| Luyện Khí 6 | 5 | 40/40 | 3,0 |

Ý đồ: ở mức cảnh giới yêu cầu, đi tay không thì thua và phải biết rút ở tầng 1–2, mang đủ đan mới có cơ hội thông; vài tầng cảnh giới sau thì đủ đan là chắc. Số đan, `pill_threshold` 0,4, `pill_heal` 0,5, `tier_heal` 0,3, `enemy_scale` 0 / 0,25 / 0,5 là hệ số khởi điểm, sẽ chỉnh tiếp ở cổng cân bằng V6 cùng công pháp chủ tu.

## Nghiên cứu Tàn Kinh (V4) — hệ số khởi điểm

| Hướng | Mảnh | Bạc | Cơ hội | Pity | Hoàn khi hỏng | Thương tích khi hỏng |
|---|---|---|---|---|---|---|
| Ổn Định | 3 | 20 | 0,9 | 0 | 50% | 0 |
| Cấp Tốc | 5 | 40 | 0,65 | 2 | 50% | 0 |
| Nghịch Kinh | 8 | 60 | 0,4 | 2 | 40% | 1 |

Chưa đo bằng simulation; sẽ chỉnh ở cổng cân bằng V6.
