import json, os
os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "godot", "data"))


def q(level):  # GDD 6.3: Q(L) = round(100 * 1.8^(L-1))
    return int(round(100 * 1.8 ** (level - 1)))


stages = [
    ("vo", "Vô", 80, 0, {"body": 30}, {}),
    ("cuong_than", "Đoán Thể", 80, 0, {"body": 100}, {}),
    ("cam_khi", "Cảm Khí", 80, 0, {"body": 200, "silver": 50}, {}),
]
for lvl in range(1, 10):
    nxt_cost = {"cultivation": q(lvl)}
    stages.append(("luyen_khi_%d" % lvl, "Luyện Khí tầng %d" % lvl, 120, 2 * q(lvl), nxt_cost, {}))

realms = []
for i, (rid, name, life, cap, cost, req) in enumerate(stages):
    d = {"id": rid, "name_key": "realm." + rid, "lifespan_years": life, "cultivation_cap": cap}
    d["breakthrough"] = {"costs": cost, "requirements": req}
    realms.append(d)

# Luyen Khi 9 -> Truc Co: the ritual (GDD 6.5). Terms (Dao Co / Dao Tam / Linh Luc) arrive with their systems.
realms[-1]["breakthrough"] = {
    "costs": {"cultivation": q(9), "silver": 500},
    "requirements": {"all_of": [{"type": "flag_is", "flag": "meridian_damaged", "value": False}]},
    "chance": {"base": 0.45, "min": 0.30, "max": 0.95, "pity_failures": 3, "terms": []},
    "on_fail_flag": "meridian_damaged",
}
realms.append({"id": "truc_co_so", "name_key": "realm.truc_co_so", "lifespan_years": 200, "cultivation_cap": 2 * q(9)})

os.makedirs("realms", exist_ok=True)
json.dump(realms, open("realms/realms.json", "w", encoding="utf-8", newline="\n"), ensure_ascii=False, indent=1)

os.makedirs("config", exist_ok=True)
json.dump({"lifespan_warning_years": 5.0}, open("config/progression.json", "w", encoding="utf-8", newline="\n"), indent=1)
os.makedirs("migrations", exist_ok=True)
json.dump({"content_version": 1, "migrations": []}, open("migrations/content.json", "w", encoding="utf-8", newline="\n"), indent=1)

res = json.load(open("resources/base.json", encoding="utf-8"))
res += [
    {"id": "body", "name_key": "resource.body", "cap": 1000, "initial": 0},
    {"id": "spirit_qi", "name_key": "resource.spirit_qi", "cap": 100, "initial": 0},
    {"id": "cultivation", "name_key": "resource.cultivation", "cap_from": "cultivation_cap", "initial": 0},
]
json.dump(res, open("resources/base.json", "w", encoding="utf-8", newline="\n"), ensure_ascii=False, indent=1)

acts = [
    {"id": "train_body", "type": "LOOP", "name_key": "action.train_body", "duration": 4.0, "costs": {},
     "effects": [{"type": "add_resource", "resource": "body", "amount": 2}],
     "requirements": {"all_of": [{"type": "flag_is", "flag": "tutorial_started", "value": True}]},
     "age_cost_years": 0.002, "offline_allowed": True},
    {"id": "absorb_qi", "type": "LOOP", "name_key": "action.absorb_qi", "duration": 4.0, "costs": {},
     "effects": [{"type": "add_resource", "resource": "spirit_qi", "amount": 8}],
     "requirements": {"all_of": [{"type": "realm_at_least", "realm": "luyen_khi_1"}]},
     "age_cost_years": 0.004, "offline_allowed": True},
    {"id": "refine_qi", "type": "LOOP", "name_key": "action.refine_qi", "duration": 4.0, "costs": {"spirit_qi": 8},
     "effects": [{"type": "add_resource", "resource": "cultivation", "amount": 8}],
     "requirements": {"all_of": [{"type": "realm_at_least", "realm": "luyen_khi_1"}]},
     "age_cost_years": 0.004, "offline_allowed": True},
    {"id": "breakthrough", "type": "INSTANT", "name_key": "action.breakthrough", "breakthrough": True,
     "effects": [{"type": "advance_realm"}], "requirements": {}, "age_cost_years": 0.0, "offline_allowed": False},
    {"id": "treat_meridian", "type": "TIMED", "name_key": "action.treat_meridian", "duration": 20.0,
     "costs": {"silver": 50}, "effects": [{"type": "set_flag", "flag": "meridian_damaged", "value": False}],
     "requirements": {"all_of": [{"type": "flag_is", "flag": "meridian_damaged", "value": True}]},
     "age_cost_years": 0.05, "offline_allowed": False},
]
json.dump(acts, open("actions/cultivation.json", "w", encoding="utf-8", newline="\n"), ensure_ascii=False, indent=1)

loc = json.load(open("localization/vi.json", encoding="utf-8"))
loc.update({
    "resource.body": "Thể Phách", "resource.spirit_qi": "Linh Khí", "resource.cultivation": "Tu Vi",
    "action.train_body": "Rèn thể (+2 Thể Phách)", "action.absorb_qi": "Hấp thu linh khí (+8 Linh Khí)",
    "action.refine_qi": "Chuyển hóa tu vi (8 Linh Khí → 8 Tu Vi)", "action.breakthrough": "Đột phá",
    "action.treat_meridian": "Chữa trị kinh mạch (50 bạc)",
})
for rid, name, *_ in stages:
    loc["realm." + rid] = name
loc["realm.truc_co_so"] = "Trúc Cơ Sơ Kỳ"
json.dump(loc, open("localization/vi.json", "w", encoding="utf-8", newline="\n"), ensure_ascii=False, indent=1)
print(len(realms), [q(i) for i in range(1, 10)])
