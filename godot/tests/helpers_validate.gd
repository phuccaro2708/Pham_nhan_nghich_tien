class_name SaveManagerValidate
extends RefCounted
## Test-only bridge to SaveManager.validate_state (SaveManager is an autoload Node without class_name).


static func errors_for(state: GameState, registry: ContentRegistry) -> Array:
	var sm: Node = load("res://autoload/save_manager.gd").new()
	var errs: Array = sm.validate_state(state.to_dict(), registry)
	sm.free()
	return errs
