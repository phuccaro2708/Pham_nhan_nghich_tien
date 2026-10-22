# CONTENT_SCHEMA — Phase 1

Nội dung nằm ở `godot/data/`. Mỗi file `*.json` là **mảng** các định nghĩa. `ContentRegistry` nạp, kiểm tra và báo lỗi trước khi game chạy (`registry.errors`). Mọi `id` là chuỗi duy nhất trong loại của nó; không đổi ID sau khi đã phát hành save.

## Resource — `data/resources/*.json`

| Trường | Kiểu | Bắt buộc | Ghi chú |
|---|---|---|---|
| `id` | string | ✔ | |
| `name_key` | string | ✔ | phải có trong `data/localization/vi.json` **và** `en.json` |
| `group` | string | | nhóm hiển thị ở bảng tài nguyên; cần key `group.<group>` trong localization |
| `cap` | number > 0 \| null | | `null` = không giới hạn. Vượt cap thì phần dư mất (quy tắc kho, GDD §4.3) |
| `initial` | number ≥ 0 | | số lượng khi bắt đầu game mới |

## Upgrade — `data/upgrades/*.json`

| Trường | Kiểu | Ghi chú |
|---|---|---|
| `id`, `name_key` | string | |
| `cost_resource` | resource id | |
| `base_cost` | number > 0 | `C0` |
| `cost_growth` | number ≥ 1 | giá cấp n = `ceil(C0 × growth^n)` (GDD §11.2) |
| `max_level` | int ≥ 1 | |
| `bonuses` | `[{stat, per_level}]` | `stat`: `yield.<resource_id>`, `speed.all`, `speed.<action_id>`. Cộng dồn trong cùng nhóm: `level × per_level` |

## Action — `data/actions/*.json`

| Trường | Kiểu | Mặc định | Ghi chú |
|---|---|---|---|
| `id`, `name_key` | string | | |
| `type` | `INSTANT` \| `TIMED` \| `LOOP` | | Phase 1 chỉ có 3 loại này |
| `duration` | number (giây) | | > 0 với TIMED/LOOP; `INSTANT` phải là 0 hoặc bỏ trống. Thời gian thực tế `max(0.25, duration/(1+S+M))`, làm tròn lên bội 0,1 s |
| `costs` | `{resource_id: amount ≥ 0}` | `{}` | |
| `cost_timing` | `start` \| `complete` | `start` | trừ khi bắt đầu mỗi chu kỳ, hoặc khi hoàn thành (không đủ lúc đó → dừng, không thưởng). Hủy action `start` sẽ hoàn lại chi phí |
| `upgrade` | upgrade id | | action mua nâng cấp: chi phí lấy từ đường cong giá; tự chặn khi đạt `max_level` |
| `effects` | array Effect | `[]` | |
| `requirements` | Condition | `{}` | `{}` = luôn đạt |
| `age_cost_years` | number ≥ 0 | `0` | **nguồn duy nhất làm tăng tuổi**, cộng mỗi lần hoàn thành |
| `offline_allowed` | bool | `false` | `false` → bị dừng (hoàn chi phí) khi tính offline |
| `mastery_enabled` | bool | | dành cho phase sau, hiện chưa xử lý |
| `group` | string | | nhóm thu gọn được trong cột hành động; cần key `group.<group>` trong localization. Cột do UI suy ra từ `upgrade`/`type` (GDD §XII) |

## Effect (danh sách đăng ký cố định — không script)

| `type` | Trường | Hành vi |
|---|---|---|
| `add_resource` | `resource`, `amount ≥ 0`, `chance?` ∈ [0,1] | cộng `amount × (1 + Σ yield.<resource>)`, bị cắt theo `cap`. `chance` dùng RNG có seed trong GameState |
| `set_flag` | `flag`, `value` | |
| `add_upgrade_level` | `upgrade`, `levels?` (mặc định 1) | tối đa `max_level` |

## Condition

```
{}                                        luôn đạt
{"all_of": [Condition…]}                  mảng rỗng = đạt
{"any_of": [Condition…]}                  mảng rỗng = KHÔNG đạt
{"not": Condition}
{"type": "resource_at_least",     "resource": id, "amount": n}
{"type": "flag_is",               "flag": s, "value": v}
{"type": "stat_at_least",         "stat": "age_years", "value": n}
{"type": "upgrade_level_at_least","upgrade": id, "level": n}
{"type": "action_count_at_least", "action": id, "count": n}
```
Mỗi object chỉ được một dạng (một khóa composite *hoặc* `type`). Loại chưa biết bị từ chối khi nạp và không bao giờ được coi là đạt khi chạy. Các loại còn lại của GDD §5.4 (`realm_at_least`, `quest_completed`, …) sẽ thêm khi hệ thống tương ứng tồn tại.

## Save (schema_version 1)

File `user://saves/save.json` là envelope `{schema_version, checksum (SHA-256 của payload), payload (chuỗi JSON của GameState.to_dict())}`. Có `save.json.bak` (bản trước) và `.tmp` khi đang ghi. Checksum chỉ phát hiện hỏng file, **không** chống gian lận. Migration: `SaveManager.migrate`, mỗi lần tăng phiên bản thêm một nhánh (hiện có v0→v1: `age` → `age_years`).

## Quy tắc bổ sung (sau review Phase 1)

- `ResourceSystem.MAX_AMOUNT = 1e7`: trần cứng của mọi tài nguyên; `cap: null` nghĩa là trần = MAX_AMOUNT.
- `initial <= cap`; `bonuses[].per_level >= 0`; `add_upgrade_level.levels` là số nguyên >= 1; `chance` thuộc [0,1].
- Hoàn chi phí (`stop_action`) bỏ qua `cap` (cap chỉ giới hạn phần thưởng), vẫn bị chặn bởi MAX_AMOUNT.
- Hành động mà mọi effect đều là `add_resource` và mọi đích đã đầy cap bị từ chối với lý do `reward_capped` (không đốt tuổi vô ích); LOOP dừng với `action_stopped(id, "reward_capped")`.
- `flag_is` so sánh chặt theo kiểu: khác kiểu => false.
- Save: chỉ xoay main -> .bak khi main hợp lệ.

## Phase 2A — Core Progression (schema_version 2, content_version 1)

**Số lớn.** `MAX_AMOUNT = 1e15` (float64, không dùng BigNumber — fuzz 300k giá trị 1e-6…1e15 round-trip JSON 0 lỗi). `GameState.snap`: dưới `SNAP_LIMIT = 1e8` làm tròn 6 chữ số thập phân; từ 1e8 trở lên làm tròn số nguyên (JSON của Godot chỉ in ~15 chữ số có nghĩa). Hệ quả chấp nhận: lượng cộng < 0,5 bị mất khi tài nguyên ≥ 1e8.

**Resource**: thêm `cap_from: "cultivation_cap"` (cap lấy từ stage cảnh giới hiện tại; loại trừ với `cap`).

**Realm — `data/realms/realms.json`** (mảng, thứ tự = thang cảnh giới; `realm_id == ""` = stage đầu):
```
{"id", "name_key", "lifespan_years", "cultivation_cap",
 "breakthrough": {"costs": {res: n}, "requirements": <condition>,
   "chance": {"base","min","max","pity_failures","terms":[{"resource","weight","max"}]},   // tùy chọn; không có = chắc chắn
   "on_fail_flag": flag}}                                                                 // tùy chọn
```
Stage cuối không cần `breakthrough` hữu dụng (không còn stage kế). Công thức `P = clamp(base + Σ weight·clamp(res/max,0,1), min, max)`; đạt `pity_failures` lần thất bại liên tiếp thì chắc chắn thành công. Thất bại: không chết, `breakthrough_failures += 1`, đặt `on_fail_flag`; thành công: reset, xóa flag, bật lại cảnh báo thọ.

**Action**: `"breakthrough": true` + effect `advance_realm` (không tham số). Chi phí/điều kiện lấy từ stage hiện tại; lý do từ chối thêm `deceased`, `max_realm`.
**Condition** mới: `realm_at_least {realm}`. `action_count_at_least.action` và mọi id tham chiếu được validate khi nạp.
**Config**: `data/config/progression.json` → `lifespan_warning_years` (mặc định 5).

**Thọ nguyên**: tuổi chỉ đổi qua `LifespanSystem.commit_age` khi action hoàn tất; kẹp ở giới hạn stage; chạm giới hạn → `life.status = "deceased"`, `life.ended` ghi lại, action đang chạy bị hủy, mọi action sau đó bị từ chối (`deceased`). Không có luân hồi.

**Save v2** thêm: `content_version`, `realm_id`, `breakthrough_failures`, `life {status, warned, ended}`, `orphans`. Migration schema v1→v2 trong `SaveManager.migrate`.

**Content migration — `data/migrations/content.json`**: `{"content_version": N, "migrations": [{"to_version", "renames": {"resources"|"upgrades"|"actions": {old: new}}}]}`. Đổi tên chỉ áp dụng khi id đích còn trống. Id không còn tồn tại được chuyển vào `orphans` (không bao giờ xóa; trả lại nếu id xuất hiện lại; action đang chạy bị hủy, hoàn chi phí vào tài nguyên còn tồn tại, bản ghi nằm ở `orphans.active_actions[id]`). Save có `content_version` mới hơn game bị từ chối và không bị ghi đè. Save v1 đã ở giới hạn tuổi được đánh dấu `deceased`.

Sửa so với Phase 1: `MAX_AMOUNT` 1e7 → 1e15 (mục "Quy tắc bổ sung" ở trên).


## Localization (menu + đa ngôn ngữ)

- `data/localization/vi.json` là bản gốc và là cơ sở kiểm tra `name_key`/`group`; `en.json` phải có **đủ mọi key** của `vi.json` (thiếu → lỗi nạp content). Key thiếu lúc chạy rơi về tiếng Việt, rồi về chính key. Ngoại lệ duy nhất cho chuỗi hardcode: thông báo lỗi nạp dữ liệu ở `main_ui.gd` (song ngữ cố định, vì registry/bảng dịch có thể chính là thứ hỏng). Mã lỗi hàng đợi cần key `ui.auto.error.<code>` (test kiểm đủ).
- Danh sách ngôn ngữ: `GameController.LANGUAGES` (tên bản ngữ, không dịch). Lựa chọn lưu ở `user://settings.cfg`, đổi được ở menu chính.
- Tiền tố key: `resource.` `upgrade.` `action.` `realm.` `group.` `area.` `ui.` `menu.` `reason.` (mã lý do dừng/từ chối từ simulation, UI luôn hiển thị qua `reason.<code>`).


## Phase 2B — Story, Mastery, Automation (schema_version 3, content_version tăng)

`tools/gen_phase2b_data.py` (idempotent) sinh dữ liệu Phase 2B và thay thế `gen_cultivation_data.py` cho các file nó chạm vào; sau Phase 2B có thể sửa tay JSON hoặc sửa núm trong script rồi chạy lại.

**Mastery — `data/mastery/*.json`**: `{id, action, name_key, xp_base=20, xp_growth=1.35, xp_per_completion, max_level, milestones:[{level, name_key, bonuses:[{stat, value}], effects:[<effect>]}]}`. `stat` dạng `yield.<resource>` hoặc `speed.<action>`; mỗi action tối đa một định nghĩa. `effects` chỉ dùng effect đã đăng ký và **cấm `advance_realm`**.

**Relation — `data/relations/*.json`**: `{id, name_key, min, max}`; effect `add_relation {relation, amount}` kẹp trong [min, max].

**Technique — `data/techniques/*.json`**: `{id, name_key, desc_key, element, grade, bonuses:[{stat, value}], insight_modifier}`; effect `learn_technique {technique}` (không học hai lần).

**Story — `data/story/*.json`**: mảng nút `{id, chapter, title_key, text_key, trigger:<condition> | chain_only:true, choices:[{id, text_key, result_key, costs, requirements, effects, next}]}`. Validate khi nạp: mọi nút có ≥1 lựa chọn **không** costs/requirements (chống softlock); `next` phải tồn tại và đồ thị không có chu trình; effect chỉ từ tập đăng ký (cấm `advance_realm`); mọi `*_key` có trong `vi.json`. Nút `chain_only` chỉ mở qua `next`.

**Condition mới**: `story_done {node}`, `relation_at_least {relation, value}`, `mastery_level_at_least {action, level}`, `technique_known {technique}`. **Effect mới**: `add_relation`, `learn_technique`.

**Realm**: `breakthrough.on_fail_refund {resource: ratio∈[0,1]}`. **Config**: `config/progression.json → automation {max_slots ≤ 3, requirements}`.

**Action**: `automation_allowed` (mặc định true; `breakthrough` phải false), `offline_allowed`. Hàng đợi từ chối `breakthrough` và action có `automation_allowed: false`.

**Save v3** thêm `mastery {action: {level, xp, claimed[]}}`, `relations`, `techniques[]`, `story {pending, done{node: choice}}`, `automation {slots, cursor, loop, status, reason, instant_streak}`. Migration v2→v3 điền giá trị rỗng; `ContentMigration` đưa id mastery/relation không còn tồn tại vào `orphans` thay vì xóa.

## Phase 3 — Knowledge System (schema_version 4)

- **Knowledge** — `data/knowledge/*.json`: `{id, name_key, desc_key, group}`. `name_key`/`desc_key` phải có trong localization.
- **Condition** `knows {knowledge}` — kiểm tra `GameState.knowledge`.
- **Effect** `learn_knowledge {knowledge}` (idempotent) và `promote_realm {realm}` (chỉ cho stage kế tiếp của stage có `story_promotion: true`; cốt truyện dùng, không phải `advance_realm`).
- **Effect** `set_checkpoint {}` và `rewind {}` (luân hồi, GDD §7.4; **chỉ trong lựa chọn story**). `set_checkpoint` lưu ảnh thế giới vào `GameState.checkpoint`; `rewind` khôi phục nó (giữ `story`, `knowledge`, đồng hồ, RNG), xóa checkpoint và tăng `loop`. `rewind` phải là effect **cuối** của lựa chọn (validator báo lỗi nếu không) và là no-op khi không có checkpoint. Chi tiết trạng thái giữ/reset: `STORY_GRAPH.md` §4.
- **Knowledge `group: "memory"`** — ký ức luân hồi (`mem_*`). Cổng lựa chọn bằng `requirements: {"knows": "mem_..."}`; không có loại điều kiện mới.
- **Cờ `qi_source`** (`guided|relic|evidence|rogue`) do nhánh quay lại đặt; node `ch4_method_<nguồn>` và `ch5_path_<nguồn>` mở theo cờ này. `knows_qi_method` chỉ được cấp ở `ch4_method_*` (và `ch1_qi_clue` cho save cũ).
- **Save schema v5**: thêm `loop` (int ≥ 0) và `checkpoint` (object rỗng hoặc đúng bộ khóa `GameState.WORLD_KEYS`, được validate như một state). Migration v4→v5: `loop=0`, `checkpoint={}`.
- **Realm** thêm `mortal` (header hiện "Thân phận") và `story_promotion`.
- **Action** `visible_when` nay là *cổng khám phá thật*: `check_can_start` trả `not_discovered`; `AutomationQueue.set_slots` từ chối ô đó.
- **Config** `ui.lifespan_visible_when`: điều kiện hiện giới hạn thọ nguyên trong header; `ui.tab_visible_when` không còn trang `story`.
- **Save v4** thêm `knowledge`; migration v3→v4 suy ra qua điều kiện `legacy_when` khai báo trong từng kiến thức (`ContentMigration`); id lạ vào `orphans["knowledge"]`.

## Phase B — Bí cảnh (schema_version 6)
- `data/enemies/*.json`: `{id, name_key, hp, atk, def, spd, hit, crit, effects[]}` (effects = loot, qua EffectResolver, hỗ trợ `chance`).
- `data/dungeons/*.json`: `{id, name_key, desc_key, visible_when, requirements, age_cost_years, enemies[], clear_effects[]}`.
- `config/progression.json.combat`: `player{hp,atk,def,spd,hit,crit}`, `stage_bonus`, `crit_multiplier`, `interval_base`, `heal_after_kill`.
- Stat mới cho effect `modify_stat`: `combat.hp|atk|def|spd`.
- Save: `combat` (object, rỗng khi không ở bí cảnh), `dungeon_clears` (id → số lần). Migration 5→6 thêm hai trường rỗng.

## V1 — `data/path/*.json`, `later_hint_key`, `text_variants`

- Path entry: `{id, name_key, goal_key, visible_when?, done_when?, clues?: [knowledge id], blockers?: [{needs, reason_key, visible_when?}]}`. Thứ tự file = thứ tự hiển thị. Validator kiểm key vi, condition, clue là knowledge có thật.
- Story choice: `later_hint_key?` (gợi ý hệ quả về sau, hiện ở sổ Nhân Quả).
- Story node: `text_variants?: [{when: condition, text_key}]`, lấy mục đầu tiên đúng, không có thì dùng `text_key`.

## V2 — technique `role`/`traits`, `heal_wounds`, `wounds_at_least`, config

- Technique: `role: "base"|"main"` (mặc định `base`), `traits: {injury_per_run?, heal_bonus?}` (số nguyên ≥ 0), bonuses vẫn ≥ 0.
- Effect `heal_wounds {amount ≥ 1}`; condition `wounds_at_least {value}`.
- `config/progression.json`: `combat.max_wounds`, `combat.wound_hp_penalty`, `technique.switch_age_years`.
- Save v7: `main_technique` ("" hoặc công pháp `main` đã học), `wounds` ∈ [0, max_wounds]; mốc cũ được migration bổ sung 2 trường.

## V3 — dungeon tiers, `prep`, resource mới (schema_version 8)

- Dungeon: đúng một trong `enemies[]` (1 tầng) hoặc `tiers[]` = `{enemies[], enemy_scale ≥ 0 (mặc định 0), loot_mult ≥ 0 (mặc định 1), clear_effects?[]}`; thêm `danger ≥ 0` (hiển thị 1–5) và `tier_age_years ≥ 0` (tuổi tốn thêm cho mỗi tầng đã vượt). `clear_effects` của tầng chạy khi vượt tầng đó; `clear_effects` của bí cảnh chạy khi thông tầng cuối.
- `enemy_scale` nhân hp/atk/def; `loot_mult` nhân `amount` của effect `add_resource` trong `effects` của quái (xác suất `chance` giữ nguyên).
- `config/progression.json.combat`: `max_pills`, `pill_threshold`, `pill_heal`, `tier_heal`.
- Resource `healing_pill` (id cố định, Combat dùng), `technique_fragment`.
- `enter_dungeon(id, prep)` với `prep = {pills: n}`; lý do từ chối mới: `too_many_pills`, `no_pills`, `not_paused` (cho continue/leave).
- Save v8: `combat.tier/paused/pills`; `last_run` = `{}` hoặc `{dungeon, result ∈ cleared|defeated|retreated|left, depth ∈ [0, số tầng], cause ∈ ""|wounded|out_of_pills|too_strong}`. Chuyến đang dừng phải có `index` = số quái của tầng, `enemy_hp` 0 và chưa phải tầng cuối.
