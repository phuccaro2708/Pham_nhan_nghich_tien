# AGENTS.md — Phàm Nhân Nghịch Tiên

Quy tắc chung cho mọi AI tham gia dự án. Nguồn thiết kế: [docs/GDD.md](docs/GDD.md). Hướng dẫn riêng cho Claude Code: [CLAUDE.md](CLAUDE.md).

**Dự án:** Text-based Hybrid Story + Deep Incremental RPG · Godot 4.x · Windows · single-player · 3 giai đoạn: GĐ1 (MVP) Phàm Nhân → Trúc Cơ, GĐ2 → Hóa Thần, GĐ3 → Phi Thăng (GDD §XIV.1).

## Phân vai

| Agent | Vai trò | Được làm | Không làm |
|---|---|---|---|
| **Claude Code** | Lead design + engineering | Tài liệu kỹ thuật, code, test, sửa bug đã xác nhận, merge kết quả review | Mở rộng scope ngoài giai đoạn hiện tại |
| **Codex** | QA độc lập + nghiên cứu tính năng thêm | Review code/data, tìm bug, softlock, exploit nhân đôi tài nguyên, kiểm cân bằng, viết thêm test, đề xuất tính năng | Sửa code logic lớn khi chưa được giao; tự thêm tính năng vào MVP |
| **Figma** | UI/UX | Wireframe, layout cột 1280×720 (GDD §XII), design tokens, component UI | Quyết định logic game; hardcode số liệu |
| **Pixelab** | Pixel art (dự bị, chỉ khi chủ dự án yêu cầu) | Icon, nền, sprite vào `godot/assets/pixellab/` | Tự ý thay phong cách text-based của MVP |

Chủ dự án là người quyết định cuối cùng. Xung đột thiết kế → sửa GDD có ghi lý do, không tự ý làm lệch.

## Quy tắc chung

1. GDD là nguồn sự thật. Không đổi thiết kế âm thầm trong code.
2. Không mở rộng scope ngoài giai đoạn hiện tại (xem GDD §XIV.1); ngoài GĐ1 gồm tông môn toàn diện, đa nhân vật, PvP, cloud sync, đấu giá, luân hồi hoàn chỉnh, cảnh giới từ Kim Đan.
3. Data-driven, ID cố định duy nhất; không hardcode nội dung/chuỗi hiển thị trong logic hoặc UI.
4. Simulation deterministic, tách khỏi UI; UI chỉ gửi command.
5. Không đánh dấu "xong" nếu thiếu bằng chứng (output test thật). Báo trung thực test fail/bỏ qua.
6. Không ghi đè file người khác đang làm khi chưa đọc và đánh giá. Mỗi lượt chỉ sửa trong phạm vi được giao.
7. Báo cáo tiếng Việt, ngắn gọn; thuật ngữ kỹ thuật/identifier giữ nguyên.

## Quy trình phối hợp

```
Claude Code triển khai ─► test headless pass ─► Codex review độc lập
        ▲                                              │
        └── sửa lỗi đã xác nhận, cập nhật tài liệu ◄───┘
Figma: thiết kế UI ─► Claude Code hiện thực ở scenes/ui
Pixelab: asset ─► godot/assets/pixellab/ (chỉ khi được yêu cầu)
```

## Hướng dẫn riêng cho Codex (QA + nghiên cứu)

Checklist review bắt buộc (khớp GDD §15):

- **Reward một lần:** hoàn thành action qua tick biên, load save giữa chừng, đổi action, offline → có bị phát thưởng 2 lần không?
- **Softlock:** mọi tài nguyên bắt buộc có nguồn tái tạo? Lựa chọn story nào khóa vĩnh viễn tuyến chính? Hàng đợi automation có kẹt vô hạn?
- **Cultivation:** đột phá giữ phần tu vi dư? Tầng 1–8 chắc chắn; Trúc Cơ có pity sau 3 lần thất bại?
- **Offline ≡ online:** cùng seed, cùng kết quả ở các action được hỗ trợ; trần 8 giờ; story chưa chọn thì dừng.
- **Save/Load/Migration:** round-trip bảo toàn state; save cũ nâng cấp được; reject NaN/âm/ID lạ.
- **Combat:** không NaN, HP âm bất hợp lệ, vòng chiến đấu vô hạn.
- **Balance:** chạy headless 5 chiến lược (Casual, Optimizer, Idle, Explorer, Risk) → báo cáo Time-To-… (GDD §11.3) so với mục tiêu §11.1.

Định dạng báo cáo mỗi phát hiện: `[mức độ] file:dòng — mô tả — kịch bản tái hiện — đề xuất`. Phân biệt **bug đã xác nhận** với **ý kiến/đề xuất**. Đề xuất tính năng mới ghi vào mục "Nghiên cứu", không sửa thẳng vào MVP.

## Hướng dẫn riêng cho Figma (UI/UX)

- Khung 1280×720, bố cục như GDD §XII: Tab/điều khiển | Khu vực | Hành động tức thì | Hành động lặp | Nâng cấp | Tài nguyên; đầu trang tên + mô tả khu vực; chân trang action đang chạy + Nhật ký. Menu chính là scene riêng (`scenes/main_menu.tscn`).
- Ngôn ngữ chính thức: Tiếng Việt + English. Mọi chuỗi qua key trong `vi.json` **và** `en.json` (thiếu key ở `en.json` là lỗi nạp content); văn bản Figma phải có đủ hai ngôn ngữ, chừa chỗ cho chuỗi tiếng Anh dài hơn.
- Phong cách giấy cổ, nâu xám, xanh mộc; hạn chế hiệu ứng.
- Cần có: tooltip nêu công thức và lý do bị khóa, panel sự kiện cốt truyện tách khỏi log sản lượng, báo cáo offline, cảnh báo thọ nguyên.
- Xuất design tokens (màu, cỡ chữ, spacing) để map sang Godot Theme. Font phải hỗ trợ đầy đủ dấu tiếng Việt. Tokens đã được hiện thực ở `godot/scenes/ui/ui_theme.gd` (Noto Serif, `godot/assets/fonts/`); xem GDD §XII.

## Hướng dẫn riêng cho Pixelab (dự bị)

- Chỉ dùng khi được yêu cầu. Xuất vào `godot/assets/pixellab/`, đặt tên rõ ràng, nền trong suốt.
- Giữ bảng màu thống nhất với UI giấy cổ; kèm ghi chú nguồn/prompt.

## Định nghĩa "Done"

Một task xong khi: (1) đáp ứng acceptance criteria trong MVP_BACKLOG, (2) test liên quan pass có output, (3) không phá test cũ, (4) tài liệu liên quan được cập nhật, (5) Codex không còn phát hiện nghiêm trọng chưa xử lý.
