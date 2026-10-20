extends RefCounted
## What a routine entry is worth to a particular client: its load tier, its
## suitability (0.5..1.2, or the flat unsuitable factor), the attribute gains
## and fatigue it brings, and the advisor's notes explaining all of it.
## An entry is {exercise, sets, load} for levelled exercises and
## {exercise, sets, kg} for weighted ones.
const Balance = preload("res://addons/hatchery/core/balance.gd")
const Readiness = preload("res://scripts/core/readiness.gd")

## A routine holds at most this many exercises (one minigame each).
const MAX_ENTRIES: int = 4


## The dumbbell weight that suits a client's current Strength.
static func fitting_kg(state: RefCounted) -> float:
	return Balance.number("progress.kg_base") + Balance.number("progress.kg_per_strength") * float(state.attributes.strength)


## "easy", "moderate" or "hard". Weighted exercises take their tier from the
## weight relative to what suits the client.
static func tier(entry: Dictionary, state: RefCounted, def: Dictionary) -> String:
	if def.load_kind != "kg":
		return entry.load
	var share: float = kg_share(entry, state, def)
	if share < Balance.number("progress.kg_easy_below"):
		return "easy"
	if share > Balance.number("progress.kg_hard_above"):
		return "hard"
	return "moderate"


## Weight relative to what suits the client; barbell weights are compared
## against a barbell-scaled fit (the bar adds 20 kg and loads roughly 3×).
static func kg_share(entry: Dictionary, state: RefCounted, def: Dictionary) -> float:
	var fit: float = fitting_kg(state)
	if int(def.kg.min) >= 20:
		fit = 20.0 + fit * 3.0
	return float(entry.kg) / fit


static func shown_fit_kg(state: RefCounted, def: Dictionary) -> int:
	var fit: float = fitting_kg(state)
	if int(def.kg.min) >= 20:
		fit = 20.0 + fit * 3.0
	return int(round(fit))


## The attribute an exercise mostly trains.
static func main_attribute(def: Dictionary) -> String:
	var best: String = ""
	for key in def.gains:
		if best.is_empty() or float(def.gains[key]) > float(def.gains[best]):
			best = key
	return best


## {factor, unsuitable, tier, notes: [{tone, text}]} for one entry.
static func assess(entry: Dictionary, state: RefCounted, game: RefCounted) -> Dictionary:
	var catalog: RefCounted = game.catalog
	var def: Dictionary = catalog.exercise(entry.exercise)
	var load_tier: String = tier(entry, state, def)
	var notes: Array = []
	var words: Dictionary = {"exercise": def.name, "name": state.def.short, "target": catalog.targets[state.def.target.type].name.to_lower()}
	var advice: Dictionary = catalog.lines.advice
	var factor: float = float(def.goal_fit[state.def.target.type])
	if factor <= 0.85:
		notes.append({"tone": "tip", "text": advice.goal_fit_low.format(words)})
	elif factor >= 1.1:
		notes.append({"tone": "good", "text": advice.goal_fit_high.format(words)})
	var main: String = main_attribute(def)
	words["attribute"] = catalog.attribute_name(main)
	var share: float = Readiness.ratio(state, main)
	if share >= Balance.number("progress.met_ratio"):
		factor *= Balance.number("progress.met_factor")
		notes.append({"tone": "warn", "text": advice.met.format(words)})
	elif share < Balance.number("progress.weakness_ratio"):
		factor *= Balance.number("progress.weakness_bonus")
		notes.append({"tone": "good", "text": advice.weakness.format(words)})
	var unsuitable: bool = false
	var block: String = game.block().id
	var beginner: bool = state.def.experience == "none"
	for rule in def.rules:
		match rule:
			"no_hard":
				if load_tier == "hard":
					unsuitable = true
					notes.append({"tone": "bad", "text": advice.no_hard.format(words)})
			"beginner_no_hard":
				if load_tier == "hard" and beginner:
					unsuitable = true
					notes.append({"tone": "bad", "text": advice.beginner_no_hard.format(words)})
			"taper_no_hard":
				if load_tier == "hard" and block == "taper":
					unsuitable = true
					notes.append({"tone": "bad", "text": advice.taper_no_hard.format(words)})
			"base_caution":
				if block == "base" and beginner:
					unsuitable = true
					notes.append({"tone": "bad", "text": advice.base_caution_new.format(words)})
				elif block == "base":
					factor *= 0.85
					notes.append({"tone": "tip", "text": advice.base_caution.format(words)})
	if def.load_kind == "kg":
		words["kg"] = entry.kg
		words["fit"] = shown_fit_kg(state, def)
		var kg: float = kg_share(entry, state, def)
		if kg > Balance.number("progress.kg_unsuitable_above"):
			unsuitable = true
			notes.append({"tone": "bad", "text": advice.kg_heavy.format(words)})
		elif kg < Balance.number("progress.kg_easy_below"):
			notes.append({"tone": "tip", "text": advice.kg_light.format(words)})
	factor = clampf(factor, Balance.number("progress.suitability_min"), Balance.number("progress.suitability_max"))
	if unsuitable:
		factor = Balance.number("progress.unsuitable_factor")
	return {"factor": factor, "unsuitable": unsuitable, "tier": load_tier, "notes": notes}


## Value lost to the facilities and weather this week: {factor, notes}.
static func conditions(entry: Dictionary, game: RefCounted) -> Dictionary:
	var def: Dictionary = game.catalog.exercise(entry.exercise)
	var advice: Dictionary = game.catalog.lines.advice
	var factor: float = 1.0
	var notes: Array = []
	if def.outdoor and game.bad_weather() and not game.has_effect("weatherproof_runs"):
		factor *= Balance.number("progress.weather_penalty")
		notes.append({"tone": "warn", "text": advice.weather})
	if def.minigame == "effort" and not game.has_effect("full_intervals"):
		factor *= Balance.number("progress.road_interval_factor")
		notes.append({"tone": "tip", "text": advice.road_intervals})
	return {"factor": factor, "notes": notes}


static func sets_scale(entry: Dictionary, def: Dictionary) -> float:
	return float(entry.sets) / float(def.sets.default)


## Attribute gains for a full-value session of this entry (performance 1.0),
## before peak-moment bonuses and the fatigue modifier.
static func gains(entry: Dictionary, state: RefCounted, game: RefCounted) -> Dictionary:
	var def: Dictionary = game.catalog.exercise(entry.exercise)
	var assessed: Dictionary = assess(entry, state, game)
	var scale: float = Balance.number("progress.global_gain") * float(Balance.dict("progress.load_value")[assessed.tier])
	scale *= sets_scale(entry, def) * float(assessed.factor) * float(conditions(entry, game).factor)
	var result: Dictionary = {}
	for key in def.gains:
		result[key] = float(def.gains[key]) * scale
	return result


static func fatigue(entry: Dictionary, state: RefCounted, def: Dictionary) -> float:
	return float(def.fatigue) * float(Balance.dict("progress.load_fatigue")[tier(entry, state, def)]) * sets_scale(entry, def)


## How quickly this entry drains energy per press.
static func intensity(entry: Dictionary, state: RefCounted, def: Dictionary) -> float:
	return float(def.intensity) * float(Balance.dict("progress.load_intensity")[tier(entry, state, def)])


static func routine_fatigue(routine: Array, state: RefCounted, catalog: RefCounted) -> float:
	var total: float = 0.0
	for entry in routine:
		total += fatigue(entry, state, catalog.exercise(entry.exercise))
	return total


## Advisor notes for the routine as a whole, shown before confirming.
static func routine_notes(routine: Array, state: RefCounted, game: RefCounted) -> Array:
	var advice: Dictionary = game.catalog.lines.advice
	var words: Dictionary = {"name": state.def.short}
	var notes: Array = []
	var has_long: bool = routine.any(func(entry: Dictionary) -> bool: return entry.exercise == "long_run")
	if not has_long and game.block().id != "taper":
		notes.append({"tone": "warn", "text": advice.no_long_run.format(words)})
	var total: float = routine_fatigue(routine, state, game.catalog)
	if total >= 55.0:
		words["fatigue"] = int(round(total))
		notes.append({"tone": "warn", "text": advice.too_tiring.format(words)})
	return notes


static func available_exercises(game: RefCounted) -> Array:
	var result: Array = []
	for id in game.catalog.exercise_order:
		var def: Dictionary = game.catalog.exercise(id)
		if (def.requires as Array).all(func(need: String) -> bool: return game.owns(need)):
			result.append(id)
	return result


## The suggested routine for a block: the client's suggestions are listed in
## priority order, and the first ones the gym can run are used, so buying
## equipment changes what the advisor suggests.
static func suggested(state: RefCounted, block_id: String, game: RefCounted) -> Array:
	var allowed: Array = available_exercises(game)
	var result: Array = []
	for entry in state.def.suggested[block_id]:
		if allowed.has(entry.exercise) and result.size() < MAX_ENTRIES:
			result.append((entry as Dictionary).duplicate())
	return result


## A new entry for `exercise_id` at its default sets and a middling load.
static func default_entry(exercise_id: String, state: RefCounted, catalog: RefCounted) -> Dictionary:
	var def: Dictionary = catalog.exercise(exercise_id)
	var entry: Dictionary = {"exercise": exercise_id, "sets": int(def.sets.default)}
	if def.load_kind == "kg":
		var fit: int = shown_fit_kg(state, def)
		var step: int = int(def.kg.step)
		entry["kg"] = clampi(int(round(float(fit) / step)) * step, int(def.kg.min), int(def.kg.max))
	else:
		entry["load"] = "easy" if state.def.experience == "none" else "moderate"
	return entry


static func describe(entry: Dictionary, catalog: RefCounted) -> String:
	var def: Dictionary = catalog.exercise(entry.exercise)
	var amount: String = "%d kg" % int(entry.kg) if def.load_kind == "kg" else String(entry.load).capitalize()
	if def.kind == "run" and def.load_kind != "kg":
		amount = "Load " + amount
	var sets: String = "%d set%s" % [entry.sets, "" if int(entry.sets) == 1 else "s"]
	if def.minigame == "effort":
		sets = "%d repeats" % entry.sets
	return "%s · %s · %s" % [def.name, sets, amount]
