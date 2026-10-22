# BALANCE — Phase 2A (giá trị khởi tạo, chưa tinh chỉnh)

Nguồn sự thật cho số liệu là `godot/data/**`; tài liệu này ghi cách chúng được sinh ra.
`tools/gen_cultivation_data.py` sinh `realms.json`, `cultivation.json` và các khóa liên quan (ghi đè resources/localization — chỉ chạy trên bản gốc Phase 1; sau đó sửa tay data).

| Số liệu | Giá trị | Ghi chú |
|---|---|---|
| Tu vi cần để qua Luyện Khí L | `Q(L) = round(100 · 1.8^(L-1))` | GDD §6.3: 100, 180, 324, 583, 1050, 1890, 3401, 6122, 11020 |
| Cap tu vi ở Luyện Khí L | `2 · Q(L)` | tối đa gấp đôi chi phí đột phá |
| Thọ nguyên | Phàm Nhân 80, Luyện Khí 120, Trúc Cơ 200 | năm |
| Đột phá Phàm Thể / Cường Thân / Cảm Khí | 30 body / 100 body / 200 body + 50 bạc | chắc chắn thành công |
| Đột phá Luyện Khí 9 → Trúc Cơ | tu vi Q(9) + 500 bạc; P=45% (30–95%); pity sau 3 lần hỏng | số hạng Đạo Cơ/Đạo Tâm/Linh Lực chờ hệ thống tương ứng |
| Hỏng đột phá | cờ `meridian_damaged`; chữa 50 bạc, 20 s, 0,05 năm | |
| Action tu luyện | 4 s/vòng; train_body +2 body; absorb_qi +8 linh khí; refine_qi 8 linh khí → 8 tu vi | tuổi 0,002–0,004/vòng |
| Cảnh báo thọ | 5 năm (`config/progression.json`) | |

Đo bằng bot tham lam (seed 11): tới Trúc Cơ sau ~11,1 giờ, mục tiêu GDD 3–5 giờ → cần cân bằng ở Phase 2B.
