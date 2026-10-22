class_name SimulationClock
extends RefCounted
## Converts real frame time into whole fixed simulation ticks (GDD §13.5).
## The simulation itself never reads real time; it only receives tick counts.

const TICKS_PER_SECOND: int = 10
const TICK_SECONDS: float = 0.1
## Offline cap: 8 hours (GDD §9.3).
const MAX_OFFLINE_SECONDS: float = 8.0 * 3600.0

var speed: float = 1.0
var paused: bool = false
## Guards against a spiral of death after a long frame.
var max_ticks_per_feed: int = 50

var _accum: float = 0.0


## Returns how many ticks to run for this frame's `delta` (real seconds).
func feed(delta: float) -> int:
	if paused or delta <= 0.0:
		return 0
	_accum += delta * speed
	var n: int = int(_accum / TICK_SECONDS + 1e-9)
	if n > max_ticks_per_feed:
		n = max_ticks_per_feed
		_accum = 0.0
	else:
		_accum -= n * TICK_SECONDS
	return n


func reset() -> void:
	_accum = 0.0


## Seconds -> ticks, rounded up, never below 1 tick.
static func seconds_to_ticks(seconds: float) -> int:
	return maxi(1, int(ceil(seconds * TICKS_PER_SECOND - 1e-6)))


static func ticks_to_seconds(ticks: int) -> float:
	return float(ticks) * TICK_SECONDS
