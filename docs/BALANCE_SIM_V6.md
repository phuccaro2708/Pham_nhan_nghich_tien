# Cân bằng V6 — bot đi hang và nghiên cứu

## Phạm vi và cách chạy

Commit nền `f8ad245`; Godot 4.7.2. Chạy `godot --headless --path godot -s tools/balance_sim.gd -- --seeds=20 --matrix-v6 --out=matrix_v6.json` từ gốc worktree. Ma trận gồm seed 1–20 × ba công pháp chủ tu × có/không thám hiểm = 120 lượt. Hai nhánh của mỗi cặp dùng cùng seed; chiến lược `optimizer`, giới hạn 40 giờ chủ động. Thời gian dưới đây là giờ chủ động, gồm cả combat; không tính thời gian offline. Median là giá trị thứ 11 sau khi sắp tăng, đúng cách tính của simulator hiện có.

Bot học và chọn công pháp qua `ActionSystem`, không gán trực tiếp vào state. Ngũ Hành chọn `watch_hunter` rồi `trace_hunter` để nhận `mem_cave_site`; hai tuyến còn lại chọn truyện khả dụng đầu tiên. Nhánh thám hiểm bắt đầu ở Luyện Khí 5: qua Rừng Trúc, chế đủ 5 `healing_pill`, vào Hắc Thạch Động, tiếp tục sau mỗi tầng, nghỉ khi có thương tích, chọn echo hợp lệ ở `ch6_rock_echo`, học `flaw_dan_khi` và nghiên cứu `fix_stable`. Thiếu mảnh công pháp thì bot đi hang thêm; nghiên cứu thất bại thì thử lại. Nhánh không thám hiểm vẫn học cùng công pháp chủ tu, nhưng bỏ các bước đi hang và nghiên cứu. Cả hai dùng cùng chính sách tu luyện còn lại.

## Kết quả

| Công pháp chủ tu | Thám hiểm | Tới Trúc Cơ / 20 | Median giờ | Nhanh nhất | Chậm nhất | Đột phá hỏng TB | Xác suất lần Trúc Cơ đầu | Hang hoàn tất | Echo | Biến thể nghiên cứu |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| `thanh_moc_duong_khi` | Không | 20 | 3,874 | 3,874 | 5,312 | 0,65 | 0,61 | 0 | 0 | 0 |
| `thanh_moc_duong_khi` | Có | 20 | 3,848 | 3,826 | 5,986 | 0,25 | 0,67 | 20 | 20 | 20 |
| `huyet_luyen_than_kinh` | Không | 20 | 4,757 | 4,008 | 6,178 | 0,95 | 0,58 | 0 | 0 | 0 |
| `huyet_luyen_than_kinh` | Có | 20 | 3,989 | 3,980 | 6,154 | 0,50 | 0,64 | 20 | 20 | 20 |
| `ngu_hanh_dan_khi` | Không | 20 | 3,934 | 3,934 | 5,384 | 0,30 | 0,66 | 0 | 0 | 0 |
| `ngu_hanh_dan_khi` | Có | 20 | 3,909 | 3,903 | 6,063 | 0,25 | 0,72 | 20 | 20 | 20 |

120/120 lượt về đích còn sống, không lượt nào kẹt, và 120/120 thật sự chọn công pháp chủ tu được yêu cầu. Trong 60 lượt thám hiểm, bot vào dungeon trung bình 2,03 lần và nghiên cứu trung bình 1,23 lần; 40 lượt chọn `echo_guided`, 20 lượt chọn `echo_relic`. `huyet_luyen_than_kinh` phải nghỉ hồi thương ở 20/20 lượt thám hiểm (trung bình 20,5 giây/lượt); hai công pháp còn lại không cần nghỉ trong 20 seed này. Không lượt nào còn thương tích lúc thử đột phá Trúc Cơ.

So sánh theo cặp seed: thám hiểm nhanh hơn ở 18/20 seed Thanh Mộc, 16/20 seed Huyết Luyện, 18/20 seed Ngũ Hành. Chênh lệch giờ trung bình (có trừ không) lần lượt là −0,317; −0,348; −0,062. Worst-case Thanh Mộc và Ngũ Hành **chậm hơn** khi thám hiểm, nên lợi ích thời gian không bảo đảm cho mọi seed. Lợi ích đo được còn gồm mảnh công pháp, `fix_stable` và thay đổi dòng RNG do combat/nghiên cứu; không thể quy toàn bộ chênh lệch cho riêng số hạng echo +0,06.

## Đánh giá `chance.terms`

**Không đề xuất đổi trọng số lúc này.** Sáu nhóm đều 20/20 về đích; median 3,848–4,757 giờ ở hai chế độ nằm trong mục tiêu 3–5 giờ của GDD §11.1, dù các seed chậm nhất vượt 5 giờ. Xác suất lần thử đầu 0,58–0,72, chưa chạm trần 0,80 hoặc sàn 0,30; số lần thất bại trung bình 0,25–0,95. Dữ liệu không chỉ ra một tuyến bị kẹt hoặc một chế độ có lợi thế chắc chắn cần sửa bằng `chance.terms`. Giữ nguyên `min=0.30`, `max=0.80`, `pity_failures=3` và mọi trọng số hiện tại.

Giới hạn bằng chứng: bot luôn chữa thương trước đột phá, nên số hạng phạt thương tích không được lấy mẫu trong ma trận; test đơn vị xác nhận công thức, chưa chứng minh cân bằng cho người chơi cố tình đột phá khi bị thương. Đây là một chính sách bot, 20 seed, không phải playtest người chơi hay kiểm tra các chiến lược casual/idle. Các lần vượt 5 giờ cần theo dõi ở tập seed lớn hơn trước khi thay đổi cân bằng.

## Kiểm chứng

GUT headless: 256/256 test pass, gồm `test_exploring_bot_prepares_cave_researches_and_reaches_goal` cho ba công pháp ở seed 1. Runner báo 2 warning và 9 orphan từ các test khác; Godot khi thoát báo lỗi đọc root certificate store và resource leak, dù exit code bằng 0. Kết quả ma trận cũng được đối chiếu với `actual_main` và cờ `stuck` trong 120 bản ghi JSON.
