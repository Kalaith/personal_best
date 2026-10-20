extends RefCounted
## One active client's changing state: attributes, condition, routine and
## results. Static facts (name, goal, requirements) stay in the catalog entry;
## `def` is that entry, kept beside the state for the rules to read.

var id: String = ""
var def: Dictionary = {}
var attributes: Dictionary = {}
var fatigue: float = 0.0
var motivation: float = 0.0
var rapport: float = 0.0
## Routine entries: {exercise, sets, load} or {exercise, sets, kg}.
var routine: Array = []
## The block the routine was last confirmed for, so a new block prompts a review.
var routine_block: String = ""
## Weeks still to sit out with a minor injury.
var injured_weeks: int = 0
## The day booked this week, or "" for none.
var booked_day: String = ""
## Whether a coached session was played this week.
var trained_this_week: bool = false
## A minor injury picked up this week; it costs next week's session.
var new_injury: bool = false
var sessions_done: int = 0
var fees_paid: int = 0
var bonuses_paid: int = 0
## {week, name, threshold, readiness, passed}
var milestones: Array = []
## Readiness at the end of each week, starting with intake (week 0).
var readiness_history: Array = []
## The marathon result once run; empty before.
var event_result: Dictionary = {}


## A client as they walk in: their intake attributes and starting mood.
func setup(entry: Dictionary) -> void:
	id = entry.id
	def = entry
	attributes = {}
	for key in entry.attributes:
		attributes[key] = float(entry.attributes[key])
	motivation = float(entry.motivation)
	rapport = float(entry.rapport)


func short_name() -> String:
	return def.short


func is_available(week: int) -> bool:
	for entry in def.unavailable_weeks:
		if int(entry.week) == week:
			return false
	return injured_weeks <= 0


func unavailable_reason(week: int) -> String:
	if injured_weeks > 0:
		return "resting a minor injury"
	for entry in def.unavailable_weeks:
		if int(entry.week) == week:
			return entry.reason
	return ""


func milestone(week: int) -> Dictionary:
	for entry in milestones:
		if int(entry.week) == week:
			return entry
	return {}


func to_dict() -> Dictionary:
	return {
		"id": id,
		"attributes": attributes.duplicate(),
		"fatigue": fatigue,
		"motivation": motivation,
		"rapport": rapport,
		"routine": routine.duplicate(true),
		"routine_block": routine_block,
		"injured_weeks": injured_weeks,
		"booked_day": booked_day,
		"trained_this_week": trained_this_week,
		"new_injury": new_injury,
		"sessions_done": sessions_done,
		"fees_paid": fees_paid,
		"bonuses_paid": bonuses_paid,
		"milestones": milestones.duplicate(true),
		"readiness_history": readiness_history.duplicate(),
		"event_result": event_result.duplicate(true),
	}


func restore(data: Dictionary, entry: Dictionary) -> void:
	id = data.id
	def = entry
	attributes = {}
	for key in data.attributes:
		attributes[key] = float(data.attributes[key])
	fatigue = float(data.fatigue)
	motivation = float(data.motivation)
	rapport = float(data.rapport)
	routine = (data.routine as Array).duplicate(true)
	for item in routine:
		item.sets = int(item.sets)
		if item.has("kg"):
			item.kg = int(item.kg)
	routine_block = data.routine_block
	injured_weeks = int(data.injured_weeks)
	booked_day = data.booked_day
	trained_this_week = bool(data.trained_this_week)
	new_injury = bool(data.new_injury)
	sessions_done = int(data.sessions_done)
	fees_paid = int(data.fees_paid)
	bonuses_paid = int(data.bonuses_paid)
	milestones = (data.milestones as Array).duplicate(true)
	readiness_history = (data.readiness_history as Array).duplicate()
	event_result = (data.event_result as Dictionary).duplicate(true)
