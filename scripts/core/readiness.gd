extends RefCounted
## Marathon readiness and race-day results. Readiness is measured against the
## client's own goal: each attribute counts as a share of what that goal
## needs (capped at 100 %), weighted as in the design (45 % Endurance, 20 %
## Pace, 15 % Strength, 10 % Recovery, 10 % Pacing Knowledge).
const Balance = preload("res://addons/hatchery/core/balance.gd")
const Catalog = preload("res://scripts/core/catalog.gd")


## 0..1: how much of the goal's requirement `attribute` meets.
static func ratio(state: RefCounted, attribute: String) -> float:
	var need: float = float(state.def.requirements[attribute])
	return clampf(float(state.attributes[attribute]) / need, 0.0, 1.0)


## 0..100.
static func readiness(state: RefCounted) -> float:
	var weights: Dictionary = Balance.dict("readiness.weights")
	var total: float = 0.0
	for attribute in Catalog.ATTRIBUTES:
		total += float(weights[attribute]) * ratio(state, attribute)
	return total * 100.0


## Readiness points each attribute contributes now and could contribute at most.
static func breakdown(state: RefCounted) -> Array:
	var weights: Dictionary = Balance.dict("readiness.weights")
	var result: Array = []
	for attribute in Catalog.ATTRIBUTES:
		result.append({
			"attribute": attribute,
			"value": float(state.attributes[attribute]),
			"need": float(state.def.requirements[attribute]),
			"points": float(weights[attribute]) * ratio(state, attribute) * 100.0,
			"max_points": float(weights[attribute]) * 100.0,
		})
	return result


## Attributes ordered weakest first by share of the goal met; ties keep catalog order.
static func weakest(state: RefCounted) -> Array:
	var order: Array = Catalog.ATTRIBUTES.duplicate()
	var shares: Dictionary = {}
	for attribute in order:
		shares[attribute] = ratio(state, attribute)
	var ranked: Array = []
	for attribute in order:
		var at: int = 0
		while at < ranked.size() and shares[ranked[at]] <= shares[attribute]:
			at += 1
		ranked.insert(at, attribute)
	return ranked


## Readiness on the start line: fatigue carried into race day takes some off.
static func race_readiness(state: RefCounted) -> float:
	var penalty: float = Balance.number("readiness.race_fatigue_penalty") * clampf(state.fatigue / 100.0, 0.0, 1.0)
	return readiness(state) * (1.0 - penalty)


## Predicted finishing time in minutes before race-day variation.
static func predicted_minutes(state: RefCounted, race_ready: float) -> float:
	var goal: float = float(state.def.target.minutes)
	var missing: float = 1.0 - clampf(race_ready / 100.0, 0.0, 1.0)
	return goal * (Balance.number("event.time_at_full_readiness") + Balance.number("event.time_per_missing_readiness") * missing)


## The finishing range if the race were run today, with today's fatigue:
## {low, high, goal} in minutes and `verdict` ("on_track", "in_reach",
## "not_yet" or "withdraw").
static func projection(state: RefCounted) -> Dictionary:
	var race_ready: float = race_readiness(state)
	var predicted: float = predicted_minutes(state, race_ready)
	var spread: float = variation(state)
	var goal: float = float(state.def.target.minutes)
	var low: float = predicted * (1.0 - spread)
	var high: float = predicted * (1.0 + spread)
	var verdict: String = "not_yet"
	if race_ready < Balance.number("event.withdraw_below_readiness"):
		verdict = "withdraw"
	elif high <= goal:
		verdict = "on_track"
	elif low <= goal:
		verdict = "in_reach"
	return {"low": low, "high": high, "goal": goal, "verdict": verdict}


## How far race day can swing the time either way (a fraction): Pacing
## Knowledge narrows it from the low-knowledge to the high-knowledge spread.
static func variation(state: RefCounted) -> float:
	return lerpf(Balance.number("event.variation_low_knowledge"), Balance.number("event.variation_high_knowledge"), ratio(state, "knowledge"))


## Finishing position in the field for a time, from a logistic curve fitted
## to the field's mean and spread.
static func position(minutes: float) -> int:
	var z: float = (minutes - Balance.number("event.field_mean_minutes")) / Balance.number("event.field_spread_minutes")
	var share: float = 1.0 / (1.0 + exp(-1.702 * z))
	return clampi(int(round(share * Balance.number("event.field_size"))), 1, Balance.integer("event.field_size"))


static func format_minutes(minutes: float) -> String:
	var total: int = int(round(minutes))
	return "%d:%02d" % [total / 60, total % 60]
