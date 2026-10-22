# CẢNH BÁO: chapter1.json và localization của ch1/ch4/ch5 đã được sửa tay từ v1.1 (luân hồi). Chạy script này sẽ GHI ĐÈ chúng.
"""Phase 2B content: herb, relations, technique, mastery, chapter 1, new actions, automation config.
Idempotent: patches the Phase 2A JSON in place and (re)writes the new files. Run from anywhere.
gen_cultivation_data.py is the Phase 2A generator and is NOT re-run after this (it would drop these patches)."""
import json, os
os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "godot", "data"))

# ---- tuning knobs (see docs/BALANCE.md, "Phase 2B") ----
FAIL_REFUND_CULTIVATION = 0.8   # share of the Luyện Khí 9 -> Trúc Cơ cultivation cost returned on a failed ritual
TECH_SPEED_ABSORB = 0.50
TECH_SPEED_REFINE = 0.50
TECH_INSIGHT = 0.05


def load(path):
    return json.load(open(path, encoding="utf-8"))


def save(path, obj):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    json.dump(obj, open(path, "w", encoding="utf-8", newline="\n"), ensure_ascii=False, indent=1)


def upsert(lst, item):
    for i, x in enumerate(lst):
        if x["id"] == item["id"]:
            lst[i] = item
            return
    lst.append(item)


def flag(f, v=True):
    return {"type": "flag_is", "flag": f, "value": v}


vi, en = {}, {}


def tr(key, v, e):
    vi[key], en[key] = v, e


# ---------- resources / relations / technique ----------
res = load("resources/base.json")
upsert(res, {"id": "herb", "name_key": "resource.herb", "cap": 100, "initial": 0, "group": "materials"})
save("resources/base.json", res)
tr("resource.herb", "Thảo Dược", "Herb")

save("relations/base.json", [
    {"id": "ba_ly", "name_key": "relation.ba_ly", "min": -5, "max": 10},
    {"id": "truong_thon", "name_key": "relation.truong_thon", "min": -5, "max": 10},
    {"id": "dao_si", "name_key": "relation.dao_si", "min": -5, "max": 10},
])
tr("relation.ba_ly", "Bà Lý (hàng xóm)", "Granny Ly (neighbour)")
tr("relation.truong_thon", "Trưởng thôn", "Village elder")
tr("relation.dao_si", "Đạo sĩ lạ mặt", "Wandering taoist")

save("techniques/base.json", [{
    "id": "dan_khi_nhap_mon", "name_key": "technique.dan_khi_nhap_mon", "desc_key": "technique.dan_khi_nhap_mon.desc",
    "element": "none", "grade": "nhap_mon",
    "bonuses": [{"stat": "speed.absorb_qi", "value": TECH_SPEED_ABSORB}, {"stat": "speed.refine_qi", "value": TECH_SPEED_REFINE}],
    "insight_modifier": TECH_INSIGHT}])
tr("technique.dan_khi_nhap_mon", "Dẫn Khí Nhập Môn", "Introductory Qi Guiding")
tr("technique.dan_khi_nhap_mon.desc", "Công pháp nhập môn: hấp thu linh khí nhanh hơn, chuyển hóa tu vi nhanh hơn và dễ cảm ngộ hơn khi đột phá.",
   "Beginner method: absorb qi and refine cultivation faster, and gain insight for breakthroughs.")

# ---------- actions ----------
village = load("actions/village.json")
upsert(village, {
    "id": "gather_herbs", "type": "LOOP", "name_key": "action.gather_herbs", "duration": 6.0, "costs": {},
    "effects": [{"type": "add_resource", "resource": "herb", "amount": 1}],
    "requirements": {"any_of": [flag("herb_path"), {"type": "mastery_level_at_least", "action": "gather_wood", "level": 5}]},
    "age_cost_years": 0.003, "offline_allowed": True, "group": "village"})
upsert(village, {
    "id": "carry_water", "type": "LOOP", "name_key": "action.carry_water", "duration": 6.0, "costs": {},
    "effects": [{"type": "add_resource", "resource": "silver", "amount": 2}],
    "requirements": {"all_of": [flag("job_water")]},
    "age_cost_years": 0.003, "offline_allowed": True, "group": "village"})
save("actions/village.json", village)
tr("action.gather_herbs", "Hái thảo dược (+1 Thảo Dược)", "Gather herbs (+1 Herb)")
tr("action.carry_water", "Gánh nước thuê (+2 bạc)", "Carry water for hire (+2 silver)")

cult = load("actions/cultivation.json")
upsert(cult, {
    "id": "sense_qi", "type": "TIMED", "name_key": "action.sense_qi", "duration": 30.0, "costs": {"herb": 3},
    "effects": [{"type": "set_flag", "flag": "qi_sensed", "value": True}],
    "requirements": {"all_of": [{"type": "realm_at_least", "realm": "cam_khi"}, flag("knows_qi_method"), {"not": flag("qi_sensed")}]},
    "age_cost_years": 0.01, "offline_allowed": False, "group": "cultivation"})
upsert(cult, {
    "id": "learn_dan_khi", "type": "INSTANT", "name_key": "action.learn_dan_khi", "costs": {"herb": 2},
    "effects": [{"type": "learn_technique", "technique": "dan_khi_nhap_mon"}],
    "requirements": {"all_of": [{"type": "realm_at_least", "realm": "luyen_khi_1"}, flag("knows_qi_method"),
                               {"not": {"type": "technique_known", "technique": "dan_khi_nhap_mon"}}]},
    "age_cost_years": 0.0, "offline_allowed": False, "group": "cultivation"})
save("actions/cultivation.json", cult)
tr("action.sense_qi", "Cảm ứng linh khí (3 Thảo Dược)", "Sense spirit qi (3 Herb)")
tr("action.learn_dan_khi", "Học Dẫn Khí Nhập Môn (2 Thảo Dược)", "Learn Introductory Qi Guiding (2 Herb)")

# ---------- realms: Cảm Khí -> Luyện Khí 1 needs the sensation; ritual failure refunds part of the cultivation ----------
realms = load("realms/realms.json")
for r in realms:
    if r["id"] == "cam_khi":
        r["breakthrough"]["requirements"] = flag("qi_sensed")
    if r["id"] == "luyen_khi_9":
        r["breakthrough"]["on_fail_refund"] = {"cultivation": FAIL_REFUND_CULTIVATION}
save("realms/realms.json", realms)

# ---------- automation config ----------
cfg = load("config/progression.json")
cfg["automation"] = {"max_slots": 3, "requirements": {"type": "mastery_level_at_least", "action": "gather_wood", "level": 3},
                     "wait_requirements": {}}
save("config/progression.json", cfg)


# ---------- mastery ----------
def b(stat, v):
    return {"stat": stat, "value": v}


def mastery(action, vi_name, en_name, milestones):
    mid = "mastery." + action
    tr(mid, "Thuần thục: " + vi_name, "Mastery: " + en_name)
    out = {"id": mid.replace(".", "_"), "action": action, "name_key": mid, "xp_base": 20, "xp_growth": 1.35,
           "xp_per_completion": 1, "max_level": 20, "milestones": []}
    for lv, (kvi, ken), eff, bon in milestones:
        k = "%s.l%d" % (mid, lv)
        tr(k, kvi, ken)
        out["milestones"].append({"level": lv, "name_key": k, "effects": eff, "bonuses": bon})
    return out


M = [
    mastery("gather_wood", "Đốn củi", "Chop wood", [
        (5, ("Quen tay: +10% gỗ", "Handy: +10% wood"), [], [b("yield.wood", 0.10)]),
        (10, ("Tay búa lão luyện: +10% tốc độ, +20 bạc", "Skilled axe: +10% speed, +20 silver"),
         [{"type": "add_resource", "resource": "silver", "amount": 20}], [b("speed.gather_wood", 0.10)]),
        (20, ("Thợ rừng: +20% gỗ", "Woodsman: +20% wood"), [], [b("yield.wood", 0.20)])]),
    mastery("train_body", "Rèn thể", "Train body", [
        (5, ("Gân cốt dẻo dai: +10% Thể Phách", "Supple sinews: +10% Body"), [], [b("yield.body", 0.10)]),
        (10, ("Khí huyết thông suốt: +10% tốc độ", "Flowing blood: +10% speed"), [], [b("speed.train_body", 0.10)]),
        (20, ("Thân thể cường kiện: +20% Thể Phách", "Mighty frame: +20% Body"), [], [b("yield.body", 0.20)])]),
    mastery("absorb_qi", "Hấp thu linh khí", "Absorb qi", [
        (5, ("Hô hấp đều: +20% Linh Khí", "Even breathing: +20% Spirit Qi"), [], [b("yield.spirit_qi", 0.20)]),
        (10, ("Linh khí nhập thể: +20% tốc độ", "Qi flows in: +20% speed"), [], [b("speed.absorb_qi", 0.20)]),
        (20, ("Vạn khí quy nhất: +40% Linh Khí", "All qi as one: +40% Spirit Qi"), [], [b("yield.spirit_qi", 0.40)])]),
    mastery("refine_qi", "Chuyển hóa tu vi", "Refine cultivation", [
        (5, ("Luyện hóa thuần thục: +20% Tu Vi", "Practised refining: +20% Cultivation"), [], [b("yield.cultivation", 0.20)]),
        (10, ("Vận khí tự nhiên: +20% tốc độ", "Natural circulation: +20% speed"), [], [b("speed.refine_qi", 0.20)]),
        (20, ("Tu vi tinh thuần: +40% Tu Vi", "Pure cultivation: +40% Cultivation"), [], [b("yield.cultivation", 0.40)])]),
    mastery("gather_herbs", "Hái thảo dược", "Gather herbs", [
        (5, ("Mắt tinh nhận dược: +20% Thảo Dược", "Keen eye: +20% Herb"), [], [b("yield.herb", 0.20)]),
        (10, ("Thuộc đường rừng: +10% tốc độ", "Knows the paths: +10% speed"), [], [b("speed.gather_herbs", 0.10)])]),
    mastery("carry_water", "Gánh nước", "Carry water", [
        (5, ("Vai chai: +20% bạc", "Calloused shoulders: +20% silver"), [], [b("yield.silver", 0.20)]),
        (10, ("Được mối quen: +10% tốc độ", "Regular customers: +10% speed"), [], [b("speed.carry_water", 0.10)])]),
]
save("mastery/base.json", M)

# ---------- story: chapter 1 "Khói Bếp Phàm Trần" ----------
CH = "ch1"
nodes = []


def node(nid, trigger, title, text, choices, chain_only=False):
    tr("story.%s.title" % nid, *title)
    tr("story.%s.text" % nid, *text)
    d = {"id": nid, "chapter": CH, "title_key": "story.%s.title" % nid, "text_key": "story.%s.text" % nid, "choices": []}
    if chain_only:
        d["chain_only"] = True
    else:
        d["trigger"] = trigger
    for cid, ctext, cres, kw in choices:
        base = "story.%s.%s" % (nid, cid)
        tr(base, *ctext)
        tr(base + ".result", *cres)
        c = {"id": cid, "text_key": base, "result_key": base + ".result"}
        c.update(kw)
        d["choices"].append(c)
    nodes.append(d)


def done(n):
    return {"type": "story_done", "node": n}


def R(rid, a):
    return {"type": "add_relation", "relation": rid, "amount": a}


def RES(rid, a):
    return {"type": "add_resource", "resource": rid, "amount": a}


def SET(f, v=True):
    return {"type": "set_flag", "flag": f, "value": v}


tr("story.ch1.name", "Chương 1: Khói Bếp Phàm Trần", "Chapter 1: Mortal Hearth Smoke")

node("ch1_morning_smoke", {"type": "action_count_at_least", "action": "gather_wood", "count": 3},
     ("Khói bếp buổi sớm", "Morning hearth smoke"),
     ("Bà Lý hàng xóm đứng trước cửa bếp, khói bay mù mịt. Nhà bà hết củi từ hôm qua, mà trời thì trở lạnh.",
      "Granny Ly stands at her smoky hearth. Her firewood ran out yesterday and the weather is turning cold."),
     [("give_wood", ("Biếu bà 5 khúc củi", "Give her 5 logs"), ("Bà Lý cười móm mém, hứa nhớ ơn cháu.", "Granny Ly beams and promises to remember you."),
       {"costs": {"wood": 5}, "effects": [R("ba_ly", 2)]}),
      ("sell_wood", ("Bán cho bà 5 khúc lấy bạc", "Sell her 5 logs for silver"), ("Bà trả đủ bạc nhưng nét mặt hơi buồn.", "She pays fair, but looks a little sad."),
       {"costs": {"wood": 5}, "effects": [RES("silver", 4)]}),
      ("ignore", ("Lặng lẽ đi tiếp", "Walk on quietly"), ("Cháu cúi đầu bước qua. Khói bếp vẫn lặng lẽ bay.", "You nod and move on. The smoke drifts on."), {})])

node("ch1_village_elder", {"all_of": [done("ch1_morning_smoke"), {"type": "action_count_at_least", "action": "gather_wood", "count": 10}]},
     ("Lời trưởng thôn", "The elder's word"),
     ("Trưởng thôn gọi cháu lại: \"Thằng bé này chịu khó. Muốn kiếm thêm đồng bạc thì ra bến gánh nước, hay lên sân đình tập mấy bài cho gân cốt?\"",
      "The elder calls you over: \"You work hard. Want extra coin hauling water at the pier, or training at the shrine yard?\""),
     [("water_job", ("Nhận việc gánh nước", "Take the water-carrying job"), ("Từ nay bến nước có thêm một đôi vai quen.", "The pier has a new pair of shoulders."),
       {"effects": [SET("job_water"), R("truong_thon", 1)]}),
      ("training", ("Xin theo các bài tập ở sân đình", "Ask to join the shrine-yard drills"), ("Ông chỉ vài thế cơ bản, Thể Phách tăng lên thấy rõ.", "He shows a few basics; your Body grows visibly."),
       {"effects": [RES("body", 10), R("truong_thon", 1)]}),
      ("decline", ("Cảm ơn và từ chối", "Politely decline"), ("Ông gật gù: \"Thế cũng tốt.\"", "He nods: \"That is fine too.\""), {})])

node("ch1_forest_edge", {"type": "action_count_at_least", "action": "train_body", "count": 5},
     ("Bìa rừng", "The forest edge"),
     ("Sau buổi tập, cháu đứng ở bìa rừng. Xa hơn là lối mòn thợ săn, hai bên mọc đầy cây thuốc.",
      "After training you stand at the forest edge. Further in lies a hunters' path lined with medicinal plants."),
     [("go_deeper", ("Vào sâu theo lối mòn", "Follow the path inward"), ("Cháu nhận ra vài loại thảo dược và hái được hai nhánh.", "You spot some herbs and pick two sprigs."),
       {"effects": [SET("herb_path"), RES("herb", 2)]}),
      ("edge_wood", ("Chặt củi ngay bìa rừng", "Chop wood at the edge"), ("Củi khô gần đó đủ cho cả buổi.", "Dry wood nearby fills the afternoon."),
       {"effects": [RES("wood", 10)]}),
      ("turn_back", ("Quay về", "Turn back"), ("Cháu quay về, rừng sâu vẫn còn đó.", "You head home; the deep forest will wait."), {})])

node("ch1_wounded_taoist", {"all_of": [done("ch1_forest_edge"), {"type": "realm_at_least", "realm": "cuong_than"}]},
     ("Đạo sĩ bị thương", "The wounded taoist"),
     ("Dưới gốc cây, một đạo sĩ áo rách ngồi ôm vết thương. Ông thở dốc nhìn cháu: \"Tiểu huynh đệ... có thể giúp ta không?\"",
      "Under a tree a ragged taoist clutches his wound, gasping: \"Young friend... could you help me?\""),
     [("heal", ("Dùng 3 Thảo Dược băng bó cho ông", "Dress his wound with 3 herbs"), ("Vết thương ngừng chảy máu. Đạo sĩ cảm kích ra mặt.", "The bleeding stops. The taoist is deeply grateful."),
       {"costs": {"herb": 3}, "effects": [R("dao_si", 3), SET("taoist_grateful")], "next": "ch1_taoist_tale"}),
      ("loot", ("Lục túi ông lấy bạc", "Rifle his pouch for silver"), ("Cháu lấy được 30 bạc. Ánh mắt đạo sĩ buốt lạnh.", "You take 30 silver. The taoist's gaze turns cold."),
       {"effects": [RES("silver", 30), R("dao_si", -2), SET("taoist_robbed")], "next": "ch1_cave_rumor"}),
      ("ask_first", ("Hỏi han trước đã", "Ask what happened first"), ("Ông cười khổ rồi kể lại đầu đuôi.", "He smiles wryly and tells his story."),
       {"effects": [R("dao_si", 1)], "next": "ch1_taoist_tale"})])

node("ch1_taoist_tale", None, ("Lời kể của đạo sĩ", "The taoist's tale"),
     ("Đạo sĩ kể về \"khí\" trong trời đất, về cách người thường cảm nhận và dẫn khí vào thân. Từng lời như mở ra một cánh cửa.",
      "The taoist speaks of the qi of heaven and earth, and how an ordinary person can sense and guide it. Each word opens a door."),
     [("listen_closely", ("Chăm chú ghi nhớ từng lời", "Memorise every word"), ("Cháu nhớ rõ pháp môn cảm ứng linh khí. Đạo sĩ gật đầu hài lòng.", "You memorise the sensing method. The taoist nods."),
       {"effects": [SET("knows_qi_method"), SET("ch1_complete"), R("dao_si", 1)]}),
      ("hurry_off", ("Nghe qua loa rồi cáo từ", "Listen briefly and take your leave"), ("Cháu chỉ nhớ được đại ý, nhưng thế cũng đủ để bắt đầu.", "You only grasp the gist, but it is enough to begin."),
       {"effects": [SET("knows_qi_method"), SET("ch1_complete")]})], chain_only=True)

node("ch1_cave_rumor", None, ("Tin đồn hang đá", "A rumour of the cave"),
     ("Đạo sĩ bỏ đi, chỉ để lại một câu: \"Sau thác nước có hang đá, nơi người xưa từng ngồi thiền.\"",
      "The taoist leaves with a single line: \"Behind the waterfall is a stone cave where the ancients meditated.\""),
     [("explore", ("Tìm đến hang đá", "Seek out the cave"), ("Cháu leo qua dòng thác, thể phách được tôi luyện thêm.", "You climb past the falls; your body is tempered."),
       {"effects": [RES("body", 15)], "next": "ch1_qi_clue"}),
      ("skip", ("Bỏ qua, về làng", "Skip it and return"), ("Cháu quay lại với công việc thường ngày.", "You return to everyday work."), {"next": "ch1_qi_clue"})],
     chain_only=True)

node("ch1_qi_clue", {"all_of": [{"type": "realm_at_least", "realm": "cam_khi"}, {"not": flag("knows_qi_method")}]},
     ("Dấu vết của linh khí", "A trace of spirit qi"),
     ("Một đêm tĩnh lặng, cháu chợt thấy trong hơi thở có luồng ấm lạ. Cháu hiểu mình có thể cảm nhận thứ \"khí\" mà người ta đồn đại.",
      "In the quiet of night you notice a strange warmth within your breath. You realise you can sense the \"qi\" people whisper about."),
     [("realize", ("Ngồi xuống cảm nhận", "Sit and feel it"), ("Cháu tự lần ra cách cảm ứng linh khí.", "You work out how to sense spirit qi on your own."),
       {"effects": [SET("knows_qi_method"), SET("ch1_complete")]})])

node("ch1_neighbor_gift", {"type": "relation_at_least", "relation": "ba_ly", "value": 2},
     ("Quà của bà Lý", "Granny Ly's gift"),
     ("Bà Lý mang sang một gói nhỏ: ít bạc dành dụm và mấy nhánh thuốc hái ở vườn nhà.",
      "Granny Ly brings a small bundle: some saved silver and a few herbs from her garden."),
     [("accept", ("Cảm ơn và nhận", "Thank her and accept"), ("Bà cười vui, còn dặn cháu giữ sức khỏe.", "She smiles and tells you to keep well."),
       {"effects": [RES("silver", 10), RES("herb", 2)]}),
      ("refuse", ("Xin phép không nhận", "Politely refuse"), ("Bà thở dài: \"Cái thằng này...\" nhưng mắt vẫn long lanh.", "She sighs, \"This boy...\" but her eyes shine."),
       {"effects": [R("ba_ly", 1)]})])

save("story/chapter1.json", nodes)

# ---------- UI strings for the new screens ----------
UI = {
    "ui.tab.story": ("Cốt truyện", "Story"), "ui.tab.mastery": ("Thuần thục", "Mastery"),
    "ui.tab.automation": ("Tự động", "Automation"), "ui.tab.cultivation": ("Tu luyện", "Cultivation"),
    "ui.story.pending": ("Sự kiện đang chờ bạn chọn", "An event awaits your choice"),
    "ui.story.none": ("Chưa có sự kiện nào.", "No event right now."),
    "ui.story.history": ("Đã trải qua", "Past events"),
    "ui.story.locked_choice": ("Chưa đủ điều kiện", "Requirement not met"),
    "ui.story.relations": ("Quan hệ", "Relations"),
    "ui.mastery.level": ("Cấp %d / %d", "Level %d / %d"),
    "ui.mastery.xp": ("%s / %s kinh nghiệm", "%s / %s XP"),
    "ui.mastery.max": ("Đã đạt tối đa", "Maxed"),
    "ui.mastery.next_milestone": ("Mốc kế (cấp %d): %s", "Next milestone (level %d): %s"),
    "ui.mastery.claimed": ("Đã đạt: %s", "Reached: %s"),
    "ui.auto.locked": ("Mở khi Thuần thục Đốn củi đạt cấp 3.", "Unlocks at Chop wood mastery level 3."),
    "ui.auto.slot": ("Ô %d", "Slot %d"), "ui.auto.repeat": ("Lặp", "Repeat"), "ui.auto.repeat_inf": ("vô hạn", "unlimited"),
    "ui.auto.on_block": ("Khi bị chặn", "When blocked"),
    "ui.auto.on_block.skip": ("Bỏ qua", "Skip"), "ui.auto.on_block.wait": ("Chờ", "Wait"), "ui.auto.on_block.stop": ("Dừng", "Stop"),
    "ui.auto.loop": ("Lặp lại cả hàng đợi", "Loop the whole queue"),
    "ui.auto.start": ("Chạy hàng đợi", "Run queue"), "ui.auto.stop": ("Dừng hàng đợi", "Stop queue"),
    "ui.auto.none": ("(trống)", "(empty)"),
    "ui.auto.status": ("Trạng thái: %s", "Status: %s"),
    "ui.auto.status.idle": ("chưa chạy", "idle"), "ui.auto.status.running": ("đang chạy", "running"),
    "ui.auto.status.stopped": ("đã dừng", "stopped"), "ui.auto.status.finished": ("hoàn tất", "finished"),
    "ui.auto.status.deadlock": ("kẹt", "deadlock"),
    "ui.auto.reason.story_pending": ("Chờ bạn chọn sự kiện cốt truyện.", "Waiting for your story choice."),
    "ui.auto.reason.manual_override": ("Bạn tự chạy hành động nên hàng đợi dừng.", "You started an action yourself, so the queue stopped."),
    "ui.auto.reason.stopped_by_player": ("Bạn đã dừng.", "You stopped it."),
    "ui.auto.reason.instant_loop": ("Dừng vì hành động tức thì lặp quá nhiều.", "Stopped: too many instant actions in a row."),
    "ui.auto.reason.offline_not_allowed": ("Dừng khi vắng mặt: hành động không chạy được offline.", "Stopped while away: action is not allowed offline."),
    "ui.auto.reason.all_blocked": ("Mọi ô đều bị chặn.", "Every slot is blocked."),
    "ui.auto.reason.deceased": ("Nhân vật đã tọa hóa.", "The character has died."),
    "ui.auto.reason.waiting": ("Đang chờ tài nguyên mà không ô nào tạo ra được.", "Waiting for a resource no slot can produce."),
    "ui.auto.reason.blocked": ("Ô bị chặn và đặt là Dừng.", "A slot is blocked and set to Stop."),
    "ui.auto.warn.deadlock_risk": ("Có thể kẹt: ô Chờ nhưng không ô nào tạo tài nguyên còn thiếu.", "Deadlock risk: a Wait slot lacks a resource no slot produces."),
    "ui.auto.warn.blocked_now": ("Hiện chưa chạy được.", "Cannot run right now."),
    "ui.cult.stage": ("Giai đoạn hiện tại", "Current stage"),
    "ui.cult.chain": ("Rèn thể → Cảm ứng linh khí → Hấp thu → Chuyển hóa tu vi → Đột phá",
                      "Body training → Sense qi → Absorb → Refine cultivation → Breakthrough"),
    "ui.cult.technique": ("Công pháp", "Techniques"), "ui.cult.no_technique": ("Chưa học công pháp nào.", "No technique learned yet."),
    "ui.cult.chance": ("Tỉ lệ đột phá: %d%%", "Breakthrough chance: %d%%"),
    "ui.cult.need_method": ("Cần biết pháp môn dẫn khí (xem Cốt truyện).", "You need a qi-guiding method (see Story)."),
    "ui.cult.step.body": ("Rèn thể", "Train body"), "ui.cult.step.sense": ("Cảm ứng", "Sense qi"),
    "ui.cult.step.absorb": ("Hấp thu", "Absorb"), "ui.cult.step.refine": ("Chuyển hóa", "Refine"),
    "ui.cult.step.break": ("Đột phá", "Breakthrough"),
    "ui.log_mastery": ("%s đạt cấp %d.", "%s reached level %d."),
    "ui.log_story_pending": ("Một sự kiện mới đang chờ bạn: %s", "A new event awaits you: %s"),
}
for k, (v, e) in UI.items():
    tr(k, v, e)

for path, d in (("localization/vi.json", vi), ("localization/en.json", en)):
    loc = load(path)
    loc.update(d)
    save(path, loc)
print("phase2b data written:", len(vi), "keys;", len(nodes), "story nodes")
