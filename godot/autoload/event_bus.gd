extends Node
## Decoupled notifications from the simulation to the UI. Carries no state.

signal action_completed(action_id: String)
signal action_stopped(action_id: String, reason: String)
signal lifespan_warning(remaining_years: float)
signal life_ended(age_years: float)
signal breakthrough_resolved(success: bool, from_id: String, to_id: String)
signal game_loaded(offline_report: Dictionary)
signal game_saved(ok: bool)
signal log_message(text: String)
signal mastery_level_up(action_id: String, level: int)
signal story_pending(node_id: String)
signal story_resolved(node_id: String, choice_id: String)
signal automation_changed(status: String, reason: String)
signal dungeon_enemy_defeated(dungeon_id: String, enemy_id: String)
signal dungeon_tier_cleared(dungeon_id: String, tier: int)
signal dungeon_run_ended(dungeon_id: String, result: String)
