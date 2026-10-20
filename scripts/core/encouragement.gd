extends RefCounted
## What encouragement helps right now. Personality sets the client's usual
## preference, but the moment can change it: an exhausted, frustrated or
## flying client needs different support, and the cue line says which one
## they are. Situations live in `lines.json → encouragement_situations`;
## "steady" means the usual preference applies.
const Balance = preload("res://addons/hatchery/core/balance.gd")
const Det = preload("res://addons/hatchery/core/det.gd")

const SITUATIONS: Array[String] = ["steady", "exhausted", "frustrated", "confident"]


## Draws today's situation. Each one has a base weight; the client's
## signal, mood and how the last press went make the matching one likely.
## `last_score` is -1 before any press.
static func draw(rng: RandomNumberGenerator, signal_colour: String, mood: float, last_score: float) -> String:
	var weights: Dictionary = Balance.dict("encouragement.situation_weights").duplicate()
	var trigger: float = Balance.number("encouragement.situation_trigger")
	var hint: float = trigger * Balance.number("encouragement.situation_hint_share")
	if signal_colour == "red":
		weights.exhausted = float(weights.exhausted) + trigger
	elif signal_colour == "amber":
		weights.exhausted = float(weights.exhausted) + hint
	if last_score >= 0.0 and last_score < 0.5:
		weights.frustrated = float(weights.frustrated) + trigger
	elif mood < 45.0:
		weights.frustrated = float(weights.frustrated) + hint
	if signal_colour == "green":
		if last_score >= 0.99:
			weights.confident = float(weights.confident) + hint
		if mood >= 65.0:
			weights.confident = float(weights.confident) + hint
	return String(Det.weighted_key(rng, weights, "steady"))


static func find(catalog: RefCounted, id: String) -> Dictionary:
	for entry in catalog.lines.encouragement_situations:
		if entry.id == id:
			return entry
	return {}


## The approach that helps `client` most in `situation`.
static func best(catalog: RefCounted, client: RefCounted, situation: String) -> String:
	var personality: String = client.def.personality
	var usual: String = catalog.personalities[personality].approach
	var entry: Dictionary = find(catalog, situation)
	if entry.is_empty() or String(entry.approach).is_empty():
		return usual
	return String((entry.get("overrides", {}) as Dictionary).get(personality, entry.approach))


static func approach_name(catalog: RefCounted, id: String) -> String:
	for entry in catalog.lines.approaches:
		if entry.id == id:
			return entry.name
	return id.capitalize()
