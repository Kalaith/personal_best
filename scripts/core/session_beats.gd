extends RefCounted
## Builds the sliding bar for each beat of a session. A beat is one press:
## a check-in question, a pace cue, spotting a form fault, choosing a cue,
## an encouragement approach, an effort decision or a peak moment. Zones are
## {id, label, from, to, perfect_from, perfect_to, color}, positions 0..1.
const Balance = preload("res://addons/hatchery/core/balance.gd")
const Det = preload("res://addons/hatchery/core/det.gd")

const PUSH_COLOR := "e2803a"
const HOLD_COLOR := "4f8fd0"
const ZONE_COLOR := "8fc36a"


## Seconds for one pass of the marker: faster with intensity and tiredness.
static func pass_seconds(intensity: float, energy: float) -> float:
	var effort: float = clampf((intensity - 0.2) / 1.8, 0.0, 1.0)
	var tired: float = 1.0 - clampf(energy / 100.0, 0.0, 1.0)
	var speed_up: float = Balance.number("bar.max_speed_up") * clampf(0.5 * effort + 0.5 * tired, 0.0, 1.0)
	return Balance.number("bar.pass_seconds") / (1.0 + speed_up)


## Target zone width: rapport and a good mood widen it, tiredness narrows it.
static func zone_width(rapport: float, energy: float, mood: float) -> float:
	var width: float = Balance.number("bar.zone_width")
	width += Balance.number("bar.rapport_widen") * clampf(rapport / 100.0, 0.0, 1.0)
	width -= Balance.number("bar.fatigue_narrow") * (1.0 - clampf(energy / 100.0, 0.0, 1.0))
	if mood > 60.0:
		width += Balance.number("bar.mood_adjust")
	elif mood < 40.0:
		width -= Balance.number("bar.mood_adjust")
	return width


static func zone(id: String, label: String, centre: float, width: float, perfect: float, color: String) -> Dictionary:
	var half: float = width * 0.5
	var from: float = clampf(centre - half, 0.0, 1.0 - width)
	var mid: float = from + half
	return {
		"id": id,
		"label": label,
		"from": from,
		"to": from + width,
		"perfect_from": mid - perfect * 0.5,
		"perfect_to": mid + perfect * 0.5,
		"color": color,
	}


## One target zone around `centre`, nudged by up to the pace drift.
static func target(rng: RandomNumberGenerator, centre: float, width: float, perfect: float, drift: float) -> Array:
	var shifted: float = clampf(centre + rng.randf_range(-drift, drift), width * 0.5, 1.0 - width * 0.5)
	return [zone("target", "", shifted, width, perfect, ZONE_COLOR)]


## Labelled choices spread evenly along the bar in a shuffled order.
## `options` are {id, label (or name), color}.
static func choices(rng: RandomNumberGenerator, options: Array, shuffle: bool = true) -> Array:
	var order: Array = options.duplicate()
	if shuffle:
		Det.shuffle(rng, order)
	var width: float = Balance.number("bar.choice_zone_width")
	var perfect: float = Balance.number("bar.perfect_width")
	var zones: Array = []
	for i in range(order.size()):
		var centre: float = (float(i) + 0.5) / float(order.size())
		zones.append(zone(order[i].id, order[i].get("label", order[i].get("name", "")), centre, width, perfect, order[i].get("color", "c9b48a")))
	return zones


## Hold back (blue, left) and Push (orange, right), with a dead gap between.
static func peak() -> Array:
	var width: float = Balance.number("bar.peak_zone_width")
	var perfect: float = Balance.number("bar.perfect_width")
	return [
		zone("hold", "Hold back", 0.04 + width * 0.5, width, perfect, HOLD_COLOR),
		zone("push", "Push", 0.96 - width * 0.5, width, perfect, PUSH_COLOR),
	]


## Stop, Ease off and Continue, always in that order (left to right).
static func effort() -> Array:
	var options: Array = [
		{"id": "stop", "label": "Stop", "color": HOLD_COLOR},
		{"id": "ease", "label": "Ease off", "color": "c9b48a"},
		{"id": "continue", "label": "Continue", "color": PUSH_COLOR},
	]
	var width: float = Balance.number("bar.peak_zone_width") * 0.8
	var perfect: float = Balance.number("bar.perfect_width")
	var zones: Array = []
	for i in range(options.size()):
		zones.append(zone(options[i].id, options[i].label, (float(i) + 0.5) / 3.0, width, perfect, options[i].color))
	return zones


## {zone_id, grade}: grade is "perfect" in a zone's core, "good" elsewhere in
## it, "miss" outside every zone.
static func hit(zones: Array, position: float) -> Dictionary:
	for entry in zones:
		if position >= float(entry.from) and position <= float(entry.to):
			var core: bool = position >= float(entry.perfect_from) and position <= float(entry.perfect_to)
			return {"zone_id": entry.id, "grade": "perfect" if core else "good"}
	return {"zone_id": "", "grade": "miss"}


static func grade_score(grade: String) -> float:
	match grade:
		"perfect":
			return Balance.number("bar.score_perfect")
		"good":
			return Balance.number("bar.score_good")
	return Balance.number("bar.score_miss")


static func signal_for(energy: float) -> String:
	if energy > Balance.number("energy.green_above"):
		return "green"
	if energy < Balance.number("energy.red_below"):
		return "red"
	return "amber"
