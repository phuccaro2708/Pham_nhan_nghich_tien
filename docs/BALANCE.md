# BALANCE — Phase 2A (giá trị khởi tạo, chưa tinh chỉnh)

Nguồn sự thật cho số liệu là `godot/data/**`; tài liệu này ghi cách chúng được sinh ra.
`tools/gen_cultivation_data.py` sinh `realms.json`, `cultivation.json` và các khóa liên quan (ghi đè resources/localization — chỉ chạy trên bản gốc Phase 1; sau đó sửa tay data).

| Số liệu | Giá trị | Ghi chú |
|---|---|---|
| Tu vi cần để qua Luyện Khí L | `Q(L) = round(100 · 1.8^(L-1))` | GDD §6.3: 100, 180, 324, 583, 1050, 1890, 3401, 6122, 11020 |
| Cap tu vi ở Luyện Khí L | `2 · Q(L)` | tối đa gấp đôi chi phí đột phá |
| Thọ nguyên | Phàm Nhân 80, Luyện Khí 120, Trúc Cơ 200 | năm |
| Đột phá Vô / Cường Thân / Cảm Khí | 30 body / 100 body / 200 body + 50 bạc | chắc chắn thành công |
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
