class_name SimRng
extends RefCounted
## Seeded xorshift32 whose state lives in GameState.rng_state, so a save
## resumes the exact random sequence. Not for cryptography.


static func seed_to_state(seed_value: int) -> int:
	var x: int = (seed_value * 2654435761 + 12345) & 0xFFFFFFFF
	return 1 if x == 0 else x


## Advances state.rng_state and returns a float in [0, 1).
static func next_float(state: GameState) -> float:
	var x: int = state.rng_state & 0xFFFFFFFF
	if x == 0:
		x = 1
	x = (x ^ (x << 13)) & 0xFFFFFFFF
	x = x ^ (x >> 17)
	x = (x ^ (x << 5)) & 0xFFFFFFFF
	state.rng_state = x
	return float(x) / 4294967296.0
