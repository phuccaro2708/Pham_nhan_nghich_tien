# GDD v1.0 — Phàm Nhân Nghịch Tiên

> Hybrid Story-driven + Deep Incremental RPG · Godot 4.x · Windows PC · Single-player · Text-based · Data-driven · Offline-first
> Phạm vi: định nghĩa toàn bộ định hướng; **chỉ triển khai MVP từ Phàm Nhân đến Trúc Cơ**.
> Mọi con số trong tài liệu này là **giả định cân bằng ban đầu**, chưa phải số liệu playtest.

---

## I. Product Vision

Phàm Nhân Nghịch Tiên là game RPG tu tiên dạng văn bản kết hợp incremental. Người chơi bắt đầu là một phàm nhân không tài nguyên, không sư phụ, chưa biết mình có linh căn hay không.

Từng hành động nhỏ (đốn củi, hái thuốc, đọc sách, luyện thể) dần mở khóa mạng lưới hệ thống: kinh tế, công pháp, tu luyện, chiến đấu, nhân quả, bí cảnh và tự động hóa.

### Ba cảm giác cốt lõi

- **Khám phá**: mỗi lần đủ mạnh, người chơi nhận ra thế giới còn nhiều hệ thống chưa biết.
- **Tiến bộ**: công việc thủ công dần được tự động hóa.
- **Tranh mệnh**: quyết định về thọ nguyên, công pháp, tài nguyên, nhân quả thay đổi con đường tu tiên.

### Bảy nguyên tắc không được phá vỡ

1. Không mở toàn bộ hệ thống ngay từ đầu.
2. Không để người chơi bấm một nút duy nhất trong hàng giờ.
3. Story choices phải có kết quả gameplay thực tế.
4. Một hệ thống mới phải tương tác với ít nhất hai hệ thống đã tồn tại.
5. Không ép người chơi reset chỉ vì chọn sai hoặc hết tuổi.
6. Tốc độ tăng trưởng có thể mạnh, nhưng phải có quyết định chiến lược.
7. Cơ chế idle không được làm người chơi mất sự kiện cốt truyện quan trọng.

Tham khảo nguyên lý (không sao chép công thức/nội dung): *Your Chronicle* — action system, auto-combat dungeon, nâng cấp Routine, automation, offline bonus, kết thúc phụ thuộc lựa chọn.

---

## II. Vòng lặp gameplay chính

| Lớp | Thời lượng | Vòng lặp |
|---|---|---|
| Micro-loop — Hành động | 3–60 giây | Lao động → nhận tài nguyên → mua nâng cấp → mở hành động mới |
| Meso-loop — Tu luyện & cốt truyện | 5–40 phút | Hoàn thành nhiệm vụ → học công pháp → xây nhân vật → đột phá |
| Macro-loop — Tu tiên nghịch mệnh | Nhiều giờ / nhiều phiên | Chọn đạo lộ → vượt đại cảnh giới → tranh cơ duyên → truyền thừa |

### Tốc độ mở khóa (thời gian chơi tích cực mục tiêu)

| Thời gian | Nội dung |
|---|---|
| 0–3 phút | Lao động, tài nguyên, thanh hành động |
| 3–8 phút | Nâng cấp, mở địa điểm, rèn thể |
| 8–15 phút | Sự kiện hang động, nhánh lựa chọn đầu tiên |
| 15–25 phút | Nhập đạo, mở linh khí và công pháp |
| 25–45 phút | Tu luyện, nâng cấp công pháp, automation cơ bản |
| 45–90 phút | Luyện Khí trung kỳ, chiến đấu, tài nguyên mới |
| 1,5–3 giờ | Luyện Khí hậu kỳ, chuẩn bị Trúc Cơ |
| 3–5 giờ | Hoàn thành một tuyến Trúc Cơ, kết thúc nội dung MVP |

---

## III. Progression

### 3.1. Cảnh giới

| Đại cảnh giới | Tiểu cảnh giới | Hệ thống mở |
|---|---|---|
| Phàm Nhân | Vô → Đoán thể → Cảm khí | Sinh tồn, lao động, luyện thể |
| Luyện Khí | Tầng 1–9 | Linh khí, pháp thuật, công pháp |
| Trúc Cơ | Sơ → Trung → Hậu → Viên Mãn | Đạo cơ, động phủ, trận pháp |
| Kim Đan | Sơ → Trung → Hậu → Viên Mãn | Bản mệnh Kim Đan |
| Nguyên Anh | 4 kỳ | Nguyên thần, phân thân |
| Hóa Thần | 4 kỳ | Đạo tắc, thần thông |
| Luyện Hư | 4 kỳ | Không gian, hư cảnh |
| Hợp Thể | 4 kỳ | Hợp nhất nguyên thần và thể xác |
| Đại Thừa | 4 kỳ | Hoàn thiện đạo lộ |
| Độ Kiếp | 9 trọng thiên kiếp | Nghịch thiên, vượt giới |
| Chân Tiên | Tiên đạo phân nhánh | Endgame |

**MVP:** chi tiết từ Phàm Nhân đến Trúc Cơ.

### 3.2. Thọ nguyên

Thọ nguyên là đồng hồ **trong thế giới game**, độc lập với thời gian thực.

| Cảnh giới | Thọ nguyên cơ bản |
|---|---|
| Phàm Nhân | 80 năm |
| Luyện Khí | 120 năm |
| Trúc Cơ | 200 năm |
| Kim Đan | 500 năm |
| Nguyên Anh | 1.000 năm |
| Hóa Thần | 2.000 năm |

Quy tắc:

- Khởi đầu 16 tuổi.
- Thời gian game trôi theo **hành động hoàn thành** và sự kiện, không theo giây thực.
- **Quyết định triển khai (đóng điểm mâu thuẫn của bản nháp):** mỗi action khai báo trực tiếp `age_cost_years` (đơn vị: năm trong game) cho mỗi lần hoàn thành. Không có đồng hồ "ngày/giây thực" thứ hai. Giá trị ví dụ ban đầu: lao động thường ≈ 0,002 năm/lần.
- Bế quan cao cấp tiêu hao nhiều năm, đổi lại lượng Tu Vi lớn.
- Đột phá thành công tăng giới hạn thọ nguyên, không trẻ hóa.
- Cảnh báo và lựa chọn cứu vãn khi sắp tọa hóa.
- Không dùng hao hụt tuổi theo thời gian thực quá cao trong MVP: tuổi tạo áp lực chiến lược, **không biến idle thành hình phạt**.

---

## IV. Resource Economy

### 4.1. Phân tầng tài nguyên

| Nhóm | Tài nguyên | Vai trò |
|---|---|---|
| Phàm tục | Bạc, Gỗ, Thảo Dược, Thực Phẩm | Kinh tế đầu game |
| Thể chất | Thể Phách, Sinh Lực | Luyện thể, sinh tồn, chiến đấu |
| Tu tiên | Linh Khí, Tu Vi, Linh Thạch | Tăng trưởng sức mạnh |
| Tinh thần | Lĩnh Ngộ, Đạo Tâm | Công pháp và đột phá |
| Chuyên môn | Dược Lý, Kiếm Ý, Trận Đạo | Mở build riêng |
| Dài hạn | Thiên Mệnh, Ký Ức Đạo, Đạo Quả | Truyền thừa (hậu MVP) |

### 4.2. Luồng chuyển hóa (khái niệm)

```
Gỗ / Thảo Dược / Thực Phẩm ──bán──► Bạc ──mua──► Nâng cấp / Vật phẩm
Thực Phẩm ──► Sinh Lực ──► Luyện thể ──► Thể Phách
Linh Khí (môi trường) ─hấp thu─► Linh Khí (kho) ─chuyển hóa─► Tu Vi ─► Đột phá
Tĩnh tâm / Sự kiện ──► Đạo Tâm, Lĩnh Ngộ ──► Công pháp, Đột phá
Chiến đấu / Khám phá ──► Linh Thạch, Mảnh công pháp
```

Các nhánh phụ (đan dược, chiến đấu, nhân quả) mở dần.

### 4.3. Quy tắc kinh tế

- Kho có giới hạn (tạo lý do nâng cấp); **vật phẩm cốt truyện và tiền tệ đặc biệt không bao giờ bị mất do đầy kho**.
- Tài nguyên dư có thể chuyển đổi, bán hoặc tự dùng.
- Không tạo nhiều vật phẩm chỉ khác tên.
- Mỗi tài nguyên có tối thiểu **một nguồn tạo và một công dụng thực tế**.
- Đầu game tăng trưởng theo cấp nâng cấp; về sau dùng hệ số nhân từ công pháp, linh mạch, đạo cơ, automation.

---

## V. Action System

### 5.1. Loại hành động

| Type | Quy tắc |
|---|---|
| `INSTANT` | Trả chi phí, nhận kết quả tức thời |
| `TIMED` | Chạy một lần theo thời lượng |
| `LOOP` | Lặp nếu đủ điều kiện và chưa bị dừng |
| `STORY` | Một lần, có thể mở lựa chọn |
| `RESEARCH` | Tích lũy tiến độ nghiên cứu |
| `COMBAT` | Chiến đấu mô phỏng |
| `BREAKTHROUGH` | Kiểm tra điều kiện và đột phá |
| `AUTOMATION` | Điều phối các hành động đã mở |

### 5.2. Thời gian hành động

```
T_final = max(T_min, T_base / (1 + S + M))
```

- `T_base`: thời gian gốc · `S`: bonus tốc độ từ kỹ năng (thập phân) · `M`: bonus từ công pháp và nâng cấp · `T_min`: tối thiểu, mặc định **0,25 s** cho hành động lặp đơn giản (chống vòng lặp quá nhanh gây treo).

### 5.3. Sản lượng

```
R_final = R_base × (1 + U) × (1 + P) × (1 + B)
```

`U`: nâng cấp · `P`: công pháp · `B`: buff. **Cùng nhóm cộng, khác nhóm nhân.**

### 5.4. Quy tắc mở khóa (condition system)

Điều kiện: `resource_at_least`, `realm_at_least`, `stat_at_least`, `flag_is`, `quest_completed`, `location_discovered`, `technique_mastery_at_least`, và tổ hợp `all_of`, `any_of`, `not`.

Ví dụ: *Cảm Ứng Linh Khí* cần Dẫn Khí Tàn Quyển + hoàn thành nghiên cứu nhập môn + Đạo Tâm ≥ 30.

### 5.5. Action Mastery

```
XP_required(L) = 20 × 1.35^(L-1)
```

Làm tròn chỉ khi hiển thị; giá trị tính toán lưu chính xác. Mốc **cấp 5, 10, 20** cấp khả năng mới; sau đó có thể chuyển sang automation.

**Triển khai (Phase 2B).** Mỗi lần hoàn tất *đủ một chu kỳ* cho `xp_per_completion` (=1) XP; hành động bị hủy/dừng giữa chừng không có XP. Mốc là dữ liệu (`data/mastery/*.json`): `bonuses` (cộng vào nhóm `mastery` của công thức §5.3, **suy ra từ cấp, không lưu**) và `effects` (phần thưởng một lần, ghi `claimed[]` *trước* khi áp để không thể trả hai lần). Mastery không được `advance_realm`. Hàng đợi tự động (§9.1 cấp 2) mở khi Đốn củi đạt cấp 3.

### 5.6. Chống bế tắc

Hành động không chạy được phải hiển thị **nguyên nhân** và áp chính sách:

- Manual: không cho bắt đầu.
- Loop: tạm dừng và thông báo.
- Automation: bỏ qua hoặc chờ tùy cấu hình.
- Story: giữ lựa chọn nguyên trạng, không tự thực hiện.
- Breakthrough: không tự tiêu hao nguyên liệu vô hạn khi thất bại.

---

## VI. Cultivation System

### 6.1. Chu trình

Linh khí môi trường → Hấp thu → Chuyển hóa thành Tu Vi → Lĩnh ngộ bình cảnh → Đột phá. Mỗi công pháp tác động lên một hoặc nhiều bước.

### 6.2. Linh căn (MVP)

| Linh căn | Hấp thu | Lĩnh ngộ | Lợi thế |
|---|---|---|---|
| Tạp Linh Căn | ×0,80 | ×1,00 | Dễ dung hợp đa hệ |
| Tam Linh Căn | ×1,00 | ×1,00 | Cân bằng |
| Song Linh Căn | ×1,20 | ×0,95 | Hấp thu tốt hơn |

Thiên / dị linh căn: mở rộng. **Linh căn kém không được chỉ là bản yếu hơn** — Tạp Linh Căn cần con đường riêng: dung hợp công pháp đa thuộc tính, ổn định thuật pháp hỗn hợp, ưu thế khi nghiên cứu Ngũ Hành.

### 6.3. Tích lũy tu vi

```
Q(L) = round(100 × 1.8^(L-1))
```

| Luyện Khí | Tu vi cần |
|---|---|
| 1 → 2 | 100 |
| 2 → 3 | 180 |
| 3 → 4 | 324 |
| 4 → 5 | 583 |
| 5 → 6 | 1.050 |
| 6 → 7 | 1.890 |
| 7 → 8 | 3.401 |
| 8 → 9 | 6.122 |
| 9 → Trúc Cơ | Nghi thức Trúc Cơ riêng |

Sau khi vượt tầng, trừ đúng lượng yêu cầu và **giữ phần dư** (không mất tiến độ khi xử lý nhiều chu kỳ offline).

### 6.4. Công pháp

Trường dữ liệu: `element`, `grade`, `absorption_modifier`, `conversion_modifier`, `insight_modifier`, `stability_modifier`, `life_cost_modifier`, `mastery_level`, `special_effects`.

| Công pháp | Loại | Hiệu ứng | Phù hợp |
|---|---|---|---|
| **Thanh Mộc Dưỡng Khí Quyết** | Hệ Mộc · Chính đạo · An toàn | +15% hấp thu, tăng hồi sinh lực, −20% tốc độ phát sinh bất ổn kinh mạch | Bế quan dài hạn |
| **Huyết Luyện Thân Kinh** | Luyện thể · Mạo hiểm | +30% kinh nghiệm thể phách, +15% sát thương vật lý, tăng tiêu hao sinh lực khi luyện | Chiến đấu, thám hiểm |
| **Ngũ Hành Dẫn Khí Thuật** | Đa hệ · Nghiên cứu | Không bonus lớn ban đầu; mỗi nhánh ngũ hành lĩnh ngộ tạo bonus cộng hưởng (tối đa 5) | Build dài hạn |

### 6.5. Đột phá

- Luyện Khí tầng 1–8: **chắc chắn** thành công khi đủ điều kiện.
- Tầng 9 → Trúc Cơ: thử thách chiến lược.

Nghi thức Trúc Cơ có 3 yếu tố: **Linh Lực** (E), **Đạo Cơ** (D), **Đạo Tâm** (M).

```
P = clamp(0.45 + 0.15·D + 0.10·M + 0.10·E, 0.30, 0.95)     (D, M, E ∈ [0,1])
```

- Thất bại **không giết nhân vật**: tạo trạng thái kinh mạch tổn thương + mở hành động khắc phục.
- Sau **3 lần thất bại**, mở nghi thức ổn định đảm bảo thành công nếu đủ tài nguyên (pity).
- Lưu ý: với hệ số trên, P tối đa lý thuyết = 0,80 trước clamp; mức sàn/trần cần xác nhận lại ở BALANCE.md.

**Thay đổi thiết kế Phase 2B — hoàn một phần chi phí khi thất bại (`on_fail_refund`).** Trước đây thất bại đốt toàn bộ giá nghi thức (Q(9) = 11.020 tu vi ≈ 3 giờ chơi) — mâu thuẫn với §5.6 ("không tự tiêu hao nguyên liệu vô hạn khi thất bại") và là nguyên nhân chính khiến Trúc Cơ mất ~11 giờ thay vì 3–5 giờ (đo bằng Balance Simulator, `docs/BALANCE.md`). Nay `realms.json` có `on_fail_refund: {tài_nguyên: tỉ_lệ}`: thất bại trả lại tỉ lệ đó của *giá đã trả* (hiện 80% tu vi; bạc vẫn mất để thất bại còn có giá). Không đổi công thức P, pity hay trạng thái kinh mạch tổn thương.

**Công pháp nhập môn.** *Dẫn Khí Nhập Môn* (học bằng 2 Thảo Dược, một lần) cộng tốc độ cho Hấp thu/Chuyển hóa và `insight_modifier` +5% vào P (§6.4). Chuỗi tu luyện: Rèn thể → Cảm ứng linh khí (cần pháp môn từ cốt truyện) → Hấp thu → Chuyển hóa tu vi → Đột phá.

---

## VII. Story & Worldbuilding

### 7.1. Bối cảnh

Thiên địa từng trải qua **Đoạn Tiên Kỷ**, khiến các phương pháp phi thăng cổ xưa biến mất. Các tông môn chỉ giữ công pháp không hoàn chỉnh; người không xuất thân/thiên phú bị loại khỏi tiên đạo.

Người chơi sinh ra tại **Thanh Khê Thôn**, nơi từng có một tu sĩ vô danh mất tích. Trong một lần lên núi, tìm được **Nghịch Mệnh Tàn Kinh** — không trực tiếp cho sức mạnh mà cho phép thấy **khiếm khuyết và khả năng cải tiến** của công pháp đã lĩnh ngộ. Đây là cơ chế đặc trưng: người chơi học cách *thay đổi* con đường tu luyện, không chỉ nhận công pháp mạnh hơn.

### 7.2. Ba chương đầu (sửa v1.1 — luân hồi lần đầu vào MVP)

> **Lý do đổi (v1.1):** bản cũ để chương I kết thúc bằng "manh mối" nhưng dữ liệu thực tế cho `knows_qi_method` ngay trong chương I (Codex F3), nên không có khoảng trống nào để lựa chọn tạo khác biệt thật. Luân hồi lần đầu cho đúng thứ GDD thiếu: một cái chết, một mốc, và bốn cách quay lại có hậu quả khác nhau lên NPC, quan hệ, tri thức, **nguồn pháp môn** và kết chương. Chỉ **một** lần luân hồi theo cốt truyện, không có vòng lặp tự do; hệ thống nhiều kiếp (§X) vẫn hậu MVP.

| Chương | Nội dung | Kết thúc |
|---|---|---|
| **I — Khói Bếp Phàm Trần** | Thanh Khê Thôn: lao động, bà Lý / trưởng thôn / lão thợ săn, học nghề, **mốc "Ngày lên núi"**, đạo sĩ bị thương, **sự cố trên núi** (chết) → **luân hồi lần đầu**. KHÔNG cấp pháp môn. | Mở mắt ở mốc, mang theo ký ức |
| **II — Tiên Lộ Vô Môn** *(chương "ch4" trong dữ liệu)* | Bốn nhánh quay lại (xem 7.4): cứu đạo sĩ / theo thợ săn tới hang / cảnh báo cả làng / giữ bí mật. Mỗi nhánh kết bằng `dao_entry` + `qi_source` khác nhau. Đến **Cảm Khí** mới có node cấp pháp môn theo nguồn. | Có pháp môn, cảm ứng linh khí, bước vào Luyện Khí |
| **III — Bách Luyện Thành Đạo** *(stub "ch5")* | Luyện Khí 9: Thanh Huyền ngoại môn / Tàn Kinh / tán tu | Chuẩn bị Trúc Cơ: chính đạo / tán tu / lối cải biến |

Chương cũ "ch2/ch3" trong dữ liệu (tin đồn núi, ngã ba) là phần mở đầu của chương I và chạy **trước** mốc luân hồi (vì Đoán Thể là điều kiện của mốc, xem 7.4).

### 7.3. Story Graph

Mỗi sự kiện là một node: ID ổn định, điều kiện kích hoạt, đoạn văn, lựa chọn, kết quả, node kế tiếp. Lựa chọn có thể mở nhánh nhưng **không được khóa vĩnh viễn** hệ thống thiết yếu. Đồ thị đầy đủ và bảng trạng thái khi tua: [STORY_GRAPH.md](STORY_GRAPH.md).

**Nút "Đạo sĩ bị thương"** (chạy thật, `ch1_wounded_taoist`): dùng 3 thảo dược băng bó (quan hệ +3, biết ơn) · lục túi lấy 30 bạc (quan hệ −2, cờ `taoist_robbed`) · hỏi han (miễn phí, quan hệ +1). Ba lựa chọn khác nhau về giá **và** hậu quả; không lựa chọn miễn phí nào trội hơn (lựa chọn tốn kém mở thêm tuyến sau luân hồi).

### 7.4. Luân hồi lần đầu (MVP) — quy tắc bất biến

Luân hồi là cơ chế truyện, không phải vòng lặp farm. Tái dùng hệ tri thức (`knowledge`, nhóm `memory`) thay vì thêm hệ ký ức riêng, để nó tương tác với **Knowledge** (điều kiện `knows`), **Story** (mở/đóng lựa chọn), **Save** (checkpoint trong schema v5), **Quan hệ** và **Cultivation** (nguồn pháp môn → `sense_qi`).

1. **Ký ức nhân vật giữ lại:** sự kiện đã trải qua (`story.done`), bí mật và kỹ thuật đã biết (`knowledge`, kể cả nhóm `memory`). Đồng hồ, RNG, metadata save không tua.
2. **Thế giới tại mốc được đặt lại:** tài nguyên, nâng cấp, cờ, quan hệ, đếm hành động, thành thạo, công pháp, cảnh giới, tuổi, số lần thất bại đột phá. Niềm tin phải xây lại. Hành động đang chạy bị hủy **không hoàn chi phí** (snapshot đã là thế giới trước khi nó bắt đầu).
3. **Lựa chọn mới chỉ mở khi ký ức liên quan đã được chứng kiến** (`requirements: knows mem_*`). Ký ức nào có được phụ thuộc vào lựa chọn ở sự cố; một lần chơi chỉ chứng kiến một phần, nên các nhánh có yêu cầu ký ức loại trừ nhau, còn nhánh tự do thì luôn mở.
4. **Mốc là điều nhân vật đã sống qua:** `set_checkpoint` chỉ xuất hiện trong lựa chọn story của node đã xong. Mốc nằm **sau Đoán Thể**, nếu không effect một lần của các node sau mốc (như `promote_realm cuong_than`) sẽ mất vĩnh viễn vì `story.done` được giữ.
5. **Chết luôn có đường về, tua chủ động bị giới hạn:** `rewind` dùng hết checkpoint (rỗng thì là no-op). Không có hàng tồn, không farm được. Cái giá trong truyện: tua là một lần duy nhất, nên các nhánh sau là cam kết thật.
6. **Không lựa chọn nào khóa hết đường chính:** mọi node có lựa chọn miễn phí, mọi nhánh tới `dao_entry` và một `qi_source`; mỗi nguồn có node pháp môn với lựa chọn miễn phí.
7. **Mỗi nhánh đổi khác thật** NPC còn sống, quan hệ, tri thức, cách có pháp môn và kết chương (bảng ở STORY_GRAPH).

**Nguồn pháp môn (`qi_source`)** — pháp môn (`knows_qi_method`) chỉ cấp ở node `ch4_method_*` khi đã tới Cảm Khí, theo nguồn:

| Nhánh | `qi_source` | Nguồn | Ai còn sống / quan hệ chính | Kết chương |
|---|---|---|---|---|
| (a) Cứu đạo sĩ | `guided` | Lời chỉ dẫn của đạo sĩ | đạo sĩ sống, `dao_si` cao | Thanh Huyền ngoại môn |
| (b) Theo thợ săn tới hang | `relic` | Tàn Kinh trong hang | thợ săn sống, đạo sĩ chết | Tàn Kinh tầng sâu |
| (c) Cảnh báo công khai | `evidence` | Sách người tu hành của trưởng thôn | làng nghi rồi tin, `truong_thon` | Sứ giả Thanh Huyền |
| (d) Giữ bí mật | `rogue` | Tán tu ở phiên chợ (cướp túi mở thêm hang riêng) | đạo sĩ chết, `ba_ly` | Con đường tán tu |

**Ngoài MVP:** nhiều kiếp tự do, Đạo Quả, chuyển hậu duệ (§X). Mỗi hệ thống luân hồi mới phải qua cổng "≥ 2 hệ thống có sẵn" trước khi thêm.

### 7.5. Nhân quả

Dữ liệu kiểm tra được, không phải đạo đức một chiều. Ba trục: `faction_reputation`, `karma_debt`, `relationships`. **Không dùng chỉ số Thiện/Ác toàn cục.** Một hành động có thể giúp người này và gây thù với người khác.

---

## VIII. Combat & Exploration

Combat MVP **hoàn toàn tự động**; trọng tâm là chọn công pháp, trang bị, khả năng sống sót.

**Chỉ số:** HP, ATK, DEF, SPD, HIT, CRIT.

```
DMG = max(1, round(ATK × SkillMultiplier − DEF × 0.5))
```

Combat giải quyết theo nhịp mô phỏng cố định, không phụ thuộc FPS.

### Ba khu vực khám phá MVP

| Địa điểm | Thử thách | Phần thưởng |
|---|---|---|
| Rừng Trúc Ảnh | Thú hoang, hái thuốc | Thảo dược, nguyên liệu |
| Hắc Thạch Động | Yêu thú, đá linh khí | Linh thạch thô |
| Phế Tích Vô Danh | Tàn trận, thủ vệ cổ | Mảnh công pháp, bí mật cốt truyện |

Mỗi địa điểm: hành động thường, sự kiện hiếm, một thử thách kết thúc. Chưa cần bản đồ di chuyển vật lý.

---

## IX. Automation & Offline

### 9.1. Cấp automation

| Cấp | Khả năng | Mở khi |
|---|---|---|
| 0 | Chọn hành động bằng tay | Ban đầu |
| 1 | Lặp một hành động | Sau hướng dẫn |
| 2 | Hàng đợi tối đa 3 hành động | Nhập đạo |
| 3 | Chờ đủ nguyên liệu, ưu tiên hành động | Luyện Khí trung kỳ |
| 4 | Điều kiện `IF/THEN` | Luyện Khí hậu kỳ |
| 5 | Nhiều lịch và phân thân | Nguyên Anh (hậu MVP) |

MVP: cấp 0–3.

**Triển khai hàng đợi (Phase 2B).** Tối đa 3 ô `{action, repeat (0 = vô hạn), on_block: skip|wait|stop, until}`, tùy chọn lặp cả hàng. Chạy qua đúng đường `ActionSystem.start_action` nên online ≡ offline. Quy tắc: không bao giờ chọn story choice (hàng đợi chờ khi có sự kiện đang treo) và không xếp `breakthrough`; người chơi tự bắt đầu hành động thì hàng đợi dừng (`manual_override`); offline chỉ chạy action có `offline_allowed`; `wait` được "nuôi" bằng ô khác của hàng đợi, không ô nào tạo được tài nguyên thiếu → trạng thái `deadlock` (UI cảnh báo trước khi chạy); chuỗi INSTANT liên tiếp > 64 thì dừng.

### 9.2. Scheduler

Một chu kỳ: (1) kiểm tra trạng thái action hiện tại → (2) kiểm tra điều kiện/nguyên liệu → (3) chọn action kế từ hàng đợi → (4) trừ tài nguyên khi bắt đầu *hoặc* hoàn thành (theo định nghĩa action) → (5) cập nhật tiến độ → (6) áp kết quả **đúng một lần** → (7) đánh giá điều kiện dừng rồi mới bắt đầu chu kỳ kế.

**Tuyệt đối không phát thưởng hai lần** khi load save hoặc khi tick đi qua thời điểm hoàn thành.

### 9.3. Offline (MVP)

- Tối đa **8 giờ** mô phỏng.
- Dùng cùng logic simulation online.
- Action có cờ `offline_allowed`.
- Story choice chưa chọn **tạm dừng chuỗi liên quan**, AI không tự quyết.
- Có báo cáo: tài nguyên nhận, tu vi tích lũy, nguyên nhân action bị dừng.
- Không tự Trúc Cơ hay quyết định không đảo ngược.
- Tối ưu được bằng bước nhảy theo lần hoàn thành action, miễn kết quả tương đương mô phỏng online.

---

## X. Prestige — Luân hồi (hậu MVP, save phải chuẩn bị từ đầu)

- **Tọa hóa**: hết thọ nguyên → chuyển hậu duệ hoặc luân hồi sau khi mở điều kiện.
- **Chủ động chuyển thế**: kết thúc một kiếp để nhận truyền thừa.

| Giữ lại | Làm mới |
|---|---|
| Thành tựu tài khoản | Tu vi |
| Ký ức công pháp | Tài nguyên thông thường |
| Một phần điểm truyền thừa | Quan hệ trong kiếp |
| Bách khoa thế giới đã khám phá | Địa điểm cần tiếp cận |
| Nâng cấp vĩnh viễn | Tiến độ luyện thể |

Công thức Đạo Quả dự kiến (không đưa vào cân bằng đầu tiên):

```
DQ = floor( 3 × sqrt(P / P0) × (1 + 0.1·A) )
```

`P`: tổng điểm thành tựu kiếp này · `P0`: điểm chuẩn một lần luân hồi hợp lệ · `A`: số thử thách thiên mệnh đã hoàn thành.

---

## XI. Balance

### 11.1. Mục tiêu

| Chỉ số | Mục tiêu |
|---|---|
| Thời gian hành động đầu tiên | 5–10 giây |
| Nâng cấp đầu tiên | 60–120 giây |
| Nội dung mới đầu game | Mỗi 2–5 phút |
| Chờ không có quyết định mới (đầu game) | ≤ 3 phút |
| Chờ chủ động giai đoạn sau | 5–15 phút |
| Offline tối đa | 8 giờ |
| Số loại tài nguyên đồng thời giai đoạn đầu | 3–5 |
| Số tài nguyên quan trọng trước Trúc Cơ | ~8–12 |

### 11.2. Giá nâng cấp

```
Cost(n) = ceil(C0 × 1.18^n)
```

Cho nâng cấp kinh tế lặp lại. Nâng cấp cốt truyện/công pháp quan trọng dùng giá cố định theo cấp.

### 11.3. Chỉ số theo dõi khi playtest

Time To First Upgrade · First Meaningful Choice · First Cultivation · First Automation · Foundation Establishment · số lần action dừng do thiếu tài nguyên · tỉ lệ chọn từng nhánh · số action kém hiệu quả hơn phương án khác · thời lượng chờ không có quyết định đáng kể · số lần gặp trạng thái không thể tiến triển.

### 11.4. Chống softlock

- Tài nguyên bắt buộc cho cốt truyện phải có **ít nhất một nguồn tái tạo được** hoặc nguồn bảo đảm không thể bỏ lỡ.
- Tài nguyên hiếm cho nghi thức Trúc Cơ có thể khó tìm nhưng **không được mất vĩnh viễn** khiến save không hoàn thành được.
- Lựa chọn khóa nhánh truyện phải có đường thay thế cho tuyến chính.

---

## XII. UI/UX

Wireframe 1280×720, **dạng cột theo loại hành động** (đổi từ 3 cột ban đầu, theo yêu cầu của chủ dự án ngày 2026-10-21): Tab/điều khiển · Khu vực · Hành động tức thì · Hành động lặp · Nâng cấp · Tài nguyên (phải); đầu trang: tên + mô tả khu vực, cảnh giới/tuổi; chân trang: action đang chạy + Nhật ký.

- Cột tab/điều khiển: Chính, Dừng hành động, Tạm dừng, Tốc độ ×1/×2/×5, Lưu, Tải, Về menu chính (+ cuộc đời mới khi tọa hóa).
- Cột khu vực: MVP chỉ có 1 khu vực (Làng), nút để sẵn chỗ cho khu vực sau.
- Cột hành động: action vào cột theo dữ liệu — có `upgrade` → *Nâng cấp*, `INSTANT` → *Tức thì*, còn lại (`TIMED`/`LOOP`) → *Lặp*. Trong cột gom thành nhóm thu gọn được theo `group`. Hành động đang chạy hiện thanh tiến độ hồng ngay trên nút; hành động bị khóa hiện xám, tooltip nêu lý do.
- Cột tài nguyên: gom nhóm theo `group`, mỗi dòng `giá trị/trần` + thanh hồng theo tỉ lệ.
- Giao diện Godot: `godot/scenes/ui/ui_theme.gd` dựng Theme từ tokens trùng tên biến Figma (file `pham_nhan_nghich_tien`: surface/page, surface/panel, ink/*, accent/jade, accent/cinnabar, fill/progress, state/disabled). Phông duy nhất Noto Serif (bản variable, giấy phép OFL, `godot/assets/fonts/`). Đổi màu/phông phải sửa Figma và `ui_theme.gd` cùng lúc. Lý do: một nguồn token cho mọi màn hình, hỗ trợ đầy đủ dấu tiếng Việt.
- Chưa làm (ngoài MVP): cột *Next Action*, *Dungeon*, các tab Party/Ritual/Shop/Achievements; **Auto Queue** chờ phase automation.
- Menu chính: scene riêng `scenes/main_menu.tscn` (Tiếp tục / Game mới / Ngôn ngữ / Thoát); ở menu, simulation và autosave dừng. Ngôn ngữ chính thức: Tiếng Việt + English (`data/localization/vi.json`, `en.json`), lưu ở `user://settings.cfg`.

Quy tắc:

- Desktop-first, 1280×720, co giãn cửa sổ lớn hơn.
- Tài nguyên và tiến độ chính luôn hiển thị.
- Hành động chưa mở: ẩn hoặc hiện gợi ý theo nội dung.
- Tooltip giải thích công thức, hiệu quả, **lý do hành động bị khóa**.
- Thông báo cốt truyện tách riêng khỏi log sản lượng.
- Phong cách giấy cổ, nâu xám, xanh mộc; hạn chế hiệu ứng.
- Việt/Anh qua khóa localization; **không viết chuỗi hiển thị trong logic**.

---

## XIII. Godot Technical Architecture

### 13.1. Lớp kiến trúc

Data-driven + event-driven + deterministic simulation. UI **không** sửa số liệu trực tiếp: UI gửi command → simulation validate → phát event.

```
UI Layer              Controls · Tooltips · Story Panels
Game Controller/Bus   Commands · Signals · Validation
Simulation Domain     Actions · Cultivation · Story · Combat · Automation
Data / Persistence    Content Definitions · Runtime State · Save Repository
```

### 13.2. Cấu trúc thư mục

```
godot/
├── project.godot
├── autoload/      event_bus.gd · game_controller.gd · save_manager.gd
├── core/          simulation_clock.gd · game_state.gd · condition_evaluator.gd
│                  effect_resolver.gd · content_registry.gd · number_formatter.gd
├── systems/       action · resource · cultivation · story · combat · automation · offline
├── data/          actions/ resources/ cultivation/ techniques/ locations/
│                  encounters/ story/ localization/
├── scenes/        main.tscn · ui/
├── assets/        fonts/ icons/ backgrounds/ pixellab/
├── tests/         unit/ integration/ simulation/
└── docs/          GDD · CONTENT_SCHEMA · BALANCE · ARCHITECTURE · TEST_PLAN
```

### 13.3. Quy tắc dữ liệu

Mọi nội dung có **ID cố định, duy nhất**. Ví dụ action:

```json
{
  "id": "gather_wood",
  "type": "LOOP",
  "name_key": "action.gather_wood",
  "duration": 10.0,
  "costs": {},
  "effects": [{ "type": "add_resource", "resource": "wood", "amount": 3 }],
  "requirements": { "all_of": [{ "type": "flag_is", "flag": "tutorial_started", "value": true }] },
  "offline_allowed": true,
  "mastery_enabled": true
}
```

Tài nguyên, công pháp, nhiệm vụ, sự kiện có schema riêng. `EffectResolver` chỉ xử lý **tập hiệu ứng đã đăng ký**, không thực thi script tùy ý từ JSON.

### 13.4. GameState

```
GameState
├── schema_version, game_time
├── character: age, realm, cultivation_level, stats, techniques
├── resources, inventories
├── unlocked_actions, action_mastery, active_action, automation_queues
├── story_flags, quest_states, relationships
├── combat_state, discovered_locations, achievements, save_metadata
```

`active_action` lưu ID + tiến độ + tham số; **không lưu tham chiếu Node**.

### 13.5. Simulation tick

- Online: fixed-step **0,1 s**.
- UI cập nhật theo event hoặc tối đa 5–10 lần/giây; không rebuild toàn bộ danh sách action mỗi frame.
- Offline: xử lý theo sự kiện kế tiếp, có giới hạn bước và kiểm tra tương đương online.
- RNG có seed, state lưu được → test tái lập.

### 13.6. Save System

- JSON tại `user://`; ghi file tạm rồi thay file chính; giữ backup gần nhất.
- `schema_version` + migration theo phiên bản.
- Validate: NaN, giá trị âm bất hợp lệ, ID không tồn tại.
- Autosave theo chu kỳ và khi thoát.
- Hash trong client **không** được coi là chống gian lận.

---

## XIV. MVP Scope & Development Phases

1. **Foundation** — simulation, tài nguyên, action, condition/effect engine, save. Test nền trước khi viết content lớn.
2. **Playable Village** — chương Thanh Khê Thôn, hành động phàm tục, rèn thể, 5–8 sự kiện, cơ chế địa điểm.
3. **Cultivation** — linh khí, tu vi, linh căn, 3 công pháp, Luyện Khí 1–9, đột phá, giới hạn thọ nguyên.
4. **Incremental Depth** — nâng cấp sản lượng, mastery, automation, hàng đợi, offline.
5. **Adventure & Story** — 3 khu vực, auto-combat, nhân quả, nhánh nhiệm vụ, nghi thức Trúc Cơ.
6. **Balancing & RC** — mô phỏng tiến trình, kiểm save/load, cân bằng pacing, UI/UX, đóng gói Windows.

### MVP Content Budget

| Thành phần | Mục tiêu |
|---|---|
| Chương truyện | 3 |
| Địa điểm | 5 |
| Hành động | 30–40 |
| Story nodes | 20–30 |
| Công pháp | 3 |
| Cảnh giới hoàn chỉnh | Phàm Nhân, Luyện Khí |
| Mục tiêu cuối | Trúc Cơ |
| Kẻ địch | 6–8 |
| Boss | 2 |
| Nâng cấp | 15 |
| Automation | Cấp 0–3 |
| Ngôn ngữ đầu tiên | Tiếng Việt |

### Ngoài MVP

Tông môn toàn diện, đa nhân vật, PvP, cloud sync, đấu giá, hàng trăm công pháp, tự sáng tạo công pháp phức tạp, luân hồi hoàn chỉnh, cảnh giới từ Kim Đan trở lên.

---

## XV. QA & Acceptance

### 15.1. Test tự động bắt buộc

| Nhóm | Điều kiện đạt |
|---|---|
| Resource | Không mất tài nguyên ngoài quy tắc |
| Action | Một lần hoàn thành chỉ phát thưởng một lần |
| Unlock | Không mở nội dung khi thiếu điều kiện |
| Story | Lựa chọn không gây softlock |
| Cultivation | Đột phá đúng điều kiện, giữ tu vi dư |
| Automation | Hàng đợi không kẹt vô hạn |
| Offline | Tương đương online ở trường hợp được hỗ trợ |
| Save/Load | Bảo toàn trạng thái sau khởi động lại |
| Migration | Save cũ nâng cấp được |
| Combat | Không NaN, HP âm bất hợp lệ, vòng chiến đấu vô hạn |

### 15.2. Simulation playtest (headless)

Casual · Optimizer · Idle (rời game nhiều giờ) · Explorer · Risk Player.

### Điều kiện chấp nhận MVP

- Hoàn thành Phàm Nhân → Trúc Cơ không cần cheat.
- Không softlock đã biết trong các đường chơi được hỗ trợ.
- Mọi sự kiện quan trọng hoạt động sau save/load.
- Không exploit nhân đôi tài nguyên khi đổi action hoặc dùng offline.
- Ít nhất **hai hướng build** khả thi.
- Thời gian chơi tích cực tuyến chính: 3–5 giờ.
- Có báo cáo số liệu thực tế so với mục tiêu cân bằng.

---

## XVI. Design Decisions đã chốt

| Hạng mục | Quyết định v1.0 |
|---|---|
| Thể loại | Text-Based Incremental RPG |
| Gameplay | Hybrid Story + Deep Incremental |
| Engine / Nền tảng | Godot 4.x / Windows PC |
| Giao diện | Cột theo loại hành động + bảng tài nguyên (§XII), ưu tiên thông tin |
| Tiến trình | Khám phá mở khóa dần hệ thống |
| Automation | Theo cấp, mở dần |
| Cốt truyện | Nhánh có điều kiện và hậu quả |
| Thọ nguyên | Tài nguyên chiến lược, không phạt idle |
| Combat | Auto-battle |
| Offline | Tối đa 8 giờ |
| Cảnh giới đầu | "Vô" (id `vo`, trước là Phàm Thể): nông dân chưa có cảnh giới; Tu Vi/Linh Khí ẩn trên UI tới Cảm Khí (`visible_when` trong resource), xưng hô lời kể là "ngươi" |
| Thất bại đột phá | Hoàn một phần tu vi (`on_fail_refund`, Phase 2B) — xem §6.5 |
| Story | Đồ thị nút, một sự kiện treo tại một thời điểm, mỗi nút có lựa chọn miễn phí (không softlock) |
| Luân hồi lần đầu | Một lần theo cốt truyện trong MVP (§7.4): `set_checkpoint` + `rewind`, ký ức = knowledge nhóm `memory`, save v5 |
| Prestige | Thiết kế trước, triển khai sau MVP |
| Multiplayer / Monetization | Không |
| Công nghệ nội dung | Data-driven |
| Ngôn ngữ | Tiếng Việt trước, kiến trúc hỗ trợ tiếng Anh |

---

## XVII. Ba rủi ro lớn nhất

1. **Quá nhiều hệ thống quá sớm** → nhiều menu, ít tương tác sâu. Giải pháp: phát triển từng lớp; mỗi lớp phải thêm ít nhất một quyết định mới có ý nghĩa.
2. **Cốt truyện mâu thuẫn idle.** Sự kiện bắt buộc chặn action thì không idle được; AI tự chọn thì story mất ý nghĩa. Giải pháp: các chuỗi tài nguyên độc lập tiếp tục chạy, chỉ dừng nhánh cần quyết định.
3. **Cân bằng thủ công không scale.** Cần simulation headless, báo cáo tiến trình, kiểm định bất biến trước khi tăng content.

---

## XVIII. Bộ tài liệu kỹ thuật cần tách

| Tài liệu | Nội dung |
|---|---|
| `GDD.md` | Vision, gameplay, progression, scope (file này) |
| `ARCHITECTURE.md` | State, services, simulation, signals |
| `CONTENT_SCHEMA.md` | Schema JSON và validation |
| `BALANCE.md` | Công thức, bảng giá trị, mục tiêu pacing |
| `STORY_GRAPH.md` | Node, choice, flags, nhánh nhiệm vụ |
| `MVP_BACKLOG.md` | Task, dependency, acceptance criteria |
| `TEST_PLAN.md` | Unit, integration, offline, simulation |

---

## Kết luận thiết kế — Ba trụ cột

- **Story Discovery**: đọc, lựa chọn, khám phá để mở khóa hệ thống.
- **Incremental Progression**: mỗi nâng cấp đổi hiệu quả tu luyện và mở cách tích lũy mới.
- **Cultivation Automation**: thoát dần thao tác thủ công để tập trung nghiên cứu công pháp, chọn đạo lộ, vượt cảnh giới.

**Ưu tiên số 1:** vertical slice 20–30 phút đầu (đốn củi → cảm ứng linh khí) gồm một lựa chọn cốt truyện có hậu quả thực tế và một nâng cấp tự động hóa. Chỉ khi phần này hấp dẫn mới đầu tư tiếp.

**Bước thiết kế kế tiếp:** đặc tả chi tiết 30–40 action, 20–30 story node và bảng cân bằng từng phút của MVP trước khi viết lượng lớn gameplay code.

---

## XII. Phụ lục — Khám phá theo hiểu biết (Phase 3, Phase 1)

*Lý do thay đổi:* nhân vật mở đầu là thiếu niên 16 tuổi con nhà tiều phu, chưa biết linh căn, cảnh giới, kinh mạch hay tu vi; UI không được nói thay nhân vật. Chi tiết: [PHASE3_STORY_ANALYSIS.md](PHASE3_STORY_ANALYSIS.md).

- **Knowledge System**: hành động, chỉ số và khái niệm chỉ hiện/chạy được sau khi nhân vật *học* kiến thức tương ứng (`knows`, `learn_knowledge`). Ngăn cả automation và offline, không chỉ UI.
- **Cảnh giới (đổi nghĩa, giữ id)**: Vô = *Phàm Nhân* (thân phận); Cường Thân = **Đoán Thể** (võ học nhập môn, chỉ đạt qua cốt truyện); Cảm Khí = nhập đạo; Luyện Khí… giữ nguyên.
- **Tuyến mở đầu**: Phàm Nhân → học nghề → võ học nhập môn (Đoán Thể) → phát hiện tiên duyên → cảm ứng linh khí → Luyện Khí. Phase 1 làm tới Đoán Thể + bước đệm tới Cảm Khí; Chương 4–5 thuộc Phase 2.
- **Ba đường tới võ học nhập môn**: học hỏi, giúp người, thám hiểm; đều có lựa chọn miễn phí, không softlock.
- **Tuổi**: hiển thị "16 tuổi" không giới hạn thọ nguyên tới khi nghe chuyện người tu hành.
