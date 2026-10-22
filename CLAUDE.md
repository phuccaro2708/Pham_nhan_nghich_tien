# CLAUDE.md — Phàm Nhân Nghịch Tiên

Text-based Hybrid Story + Deep Incremental RPG, Godot 4.x, Windows, single-player.
Nguồn thiết kế chính: [docs/GDD.md](docs/GDD.md). Quy tắc dùng chung cho mọi AI: [AGENTS.md](AGENTS.md).

## Vai trò của Claude Code

Lead Game Designer + Lead Godot Engineer: viết tài liệu kỹ thuật, triển khai code, viết test, sửa lỗi do Codex báo.
Codex (QA/nghiên cứu), Figma (UI/UX), Pixelab (pixel art dự bị) — xem AGENTS.md để biết ranh giới.

## Nguyên tắc bất biến

- GDD là nguồn sự thật. **Không mở rộng scope ngoài MVP** (Phàm Nhân → Trúc Cơ). Đổi thiết kế → sửa GDD trước, ghi lý do.
- Data-driven: nội dung (action, story, công pháp, resource) nằm trong `godot/data/` dạng JSON, ID cố định. Không hardcode nội dung trong UI hay logic.
- UI không sửa GameState trực tiếp: UI → command → simulation validate → event.
- Simulation deterministic: fixed-step 0,1 s, RNG có seed và lưu được, không phụ thuộc FPS.
- `EffectResolver` chỉ chạy tập effect đã đăng ký; không eval script từ JSON.
- Mọi chuỗi hiển thị qua localization key (`name_key`), tiếng Việt trước.
- Save: JSON ở `user://`, ghi file tạm rồi thay, có backup, `schema_version` + migration, validate NaN/âm/ID lạ.
- Phần thưởng action chỉ phát **đúng một lần** (kể cả qua save/load và offline).
- Không softlock: tài nguyên bắt buộc cho tuyến chính phải tái tạo được; lựa chọn không khóa vĩnh viễn hệ thống thiết yếu.
- Offline tối đa 8 giờ, dùng cùng logic online; story choice chưa chọn thì dừng chuỗi liên quan, không tự quyết.
- Mỗi hệ thống mới phải tương tác với ≥ 2 hệ thống có sẵn (GDD nguyên tắc 4).

## Cấu trúc (chi tiết GDD §13.2)

`godot/` → `autoload/` · `core/` · `systems/` · `data/` · `scenes/` · `assets/` · `tests/` · tài liệu ở `docs/`.
GUT 9.7.1 nằm ở `Gut-9.7.1/addons/gut` — copy vào `godot/addons/gut` khi dựng project.

## Quy trình làm việc

1. Đọc GDD mục liên quan + kiểm tra repo trước khi viết; không ghi đè nội dung có sẵn khi chưa đánh giá.
2. Chia task nhỏ có input/output + acceptance criteria; làm theo dependency (Foundation trước content).
3. Test trước/cùng code với logic simulation. Sau mỗi thay đổi ảnh hưởng logic, chạy headless:
   ```
   godot --headless --path godot -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
   ```
4. Chỉ đánh dấu task xong khi có **bằng chứng test** (output chạy thật). Test fail thì báo thẳng, không che.
5. Sau mỗi phase lớn: giao Codex review độc lập; xác minh phát hiện trước khi sửa; cập nhật tài liệu.
6. Không viết cả game trong một lần; mỗi lượt một phase/hệ thống.

## Phong cách code

- GDScript có static typing (`var x: int`, `-> void`), `class_name` cho domain class, snake_case file/hàm, PascalCase class.
- Domain logic (`core/`, `systems/`) không tham chiếu Node/UI. Giao tiếp qua `EventBus` signals.
- Hàm nhỏ, không abstraction thừa; comment chỉ giải thích *vì sao*.
- Số liệu cân bằng nằm trong data/BALANCE.md, không rải magic number trong code.

## Tài liệu cần duy trì (`godot/docs/` hoặc `docs/`)

GDD · ARCHITECTURE · CONTENT_SCHEMA · BALANCE · STORY_GRAPH · MVP_BACKLOG · TEST_PLAN.

## Việc đầu tiên khi bắt đầu

Báo cáo tình trạng repo → chuẩn hóa bộ tài liệu → dependency graph → danh sách task phase **Foundation**. Ưu tiên số 1 sau Foundation: vertical slice 20–30 phút (đốn củi → cảm ứng linh khí, 1 lựa chọn có hậu quả, 1 nâng cấp automation).

## Điểm mở cần chốt (từ GDD)

- Tuổi: mỗi action khai báo `age_cost_years` trực tiếp (đã chốt, GDD §3.2).
- Xác suất Trúc Cơ: kiểm lại sàn/trần trong BALANCE.md.
- Hệ số ban đầu (`C0`, sản lượng, thời gian action) chưa có — phải sinh từ simulation, không đoán.
