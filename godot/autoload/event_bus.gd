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
