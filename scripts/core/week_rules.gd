extends RefCounted
## The calendar: starting a week (deliveries arrive, the forecast is drawn),
## booking sessions, and ending a week (training clients do on their own,
## recovery, injuries, the mini goal and, after week 12, the marathon).
const Balance = preload("res://addons/hatchery/core/balance.gd")
const Det = preload("res://addons/hatchery/core/det.gd")
const Readiness = preload("res://scripts/core/readiness.gd")
const RoutineRules = preload("res://scripts/core/routine_rules.gd")
const SessionReport = preload("res://scripts/core/session_report.gd")
const EventRules = preload("res://scripts/core/event_rules.gd")


## Called once when the planner opens on a new week. Returns the names of
## deliveries that arrived.
static func begin_week(game: RefCounted) -> Array:
	var arrived: Array = []
	for id in game.pending:
		game.owned.append(id)
		arrived.append(game.catalog.equipment_name(id))
	game.pending = []
	var kinds: Array = Balance.list("weather.kinds")
	var weights: Array = kinds.map(func(kind: Dictionary) -> float: return float(kind.weight))
	var index: int = Det.weighted_index(game.rng_for("weather"), weights)
	game.weather = kinds[maxi(index, 0)].id
	for state in game.clients:
		state.booked_day = ""
		state.trained_this_week = false
	return arrived


## Whether `state` may be booked on `day` this week; "" when allowed,
## otherwise the reason.
static func booking_problem(game: RefCounted, state: RefCounted, day: String) -> String:
	if not state.is_available(game.week):
		return "%s is %s this week." % [state.def.short, state.unavailable_reason(game.week)]
	if not (state.def.available_days as Array).has(day):
		return "%s can't make %s." % [state.def.short, day]
	if state.routine.is_empty():
		return "%s needs a routine first." % state.def.short
	return ""


static func book(game: RefCounted, state: RefCounted, day: String) -> bool:
	if day.is_empty():
		state.booked_day = ""
		return true
	if not booking_problem(game, state, day).is_empty():
		return false
	state.booked_day = day
	return true


## Booked clients in day order for this week's sessions.
static func sessions(game: RefCounted) -> Array:
	var days: Array = Balance.list("campaign.days")
	var booked: Array = game.clients.filter(func(state: RefCounted) -> bool: return not state.booked_day.is_empty())
	Det.sort_by(booked, func(state: RefCounted) -> int: return days.find(state.booked_day), func(state: RefCounted) -> String: return state.id)
	return booked


## Resolves the rest of the week and advances the calendar. Returns
## {week, clients: [...], milestone: {...} or {}, marathon: [...]}.
static func end_week(game: RefCounted) -> Dictionary:
	var week: int = game.week
	var summary: Dictionary = {"week": week, "weather": game.weather_kind().name, "clients": [], "milestone": {}, "milestone_results": [], "marathon": []}
	for state in game.clients:
		summary.clients.append(_client_week(game, state))
	var milestone: Dictionary = game.milestone_for(week)
	if not milestone.is_empty():
		summary.milestone = milestone
		for state in game.clients:
			summary.milestone_results.append(_test(game, state, milestone))
	if week >= Balance.integer("campaign.weeks"):
		for state in game.clients:
			summary.marathon.append(EventRules.run(game, state))
		game.phase = "done"
	else:
		game.week += 1
	game.notes.append("Week %d: %s" % [week, ", ".join(summary.clients.map(func(entry: Dictionary) -> String: return "%s %d%%" % [entry.name, int(round(entry.readiness_after))]))])
	return summary


static func _client_week(game: RefCounted, state: RefCounted) -> Dictionary:
	var week: int = game.week
	var sat_out: bool = state.injured_weeks > 0
	var readiness_before: float = Readiness.readiness(state)
	var own: int = 0 if sat_out else int(state.def.own_sessions_per_week)
	var background: Dictionary = {}
	var motivation_factor: float = clampf(state.motivation / Balance.number("background.motivation_full_at"), Balance.number("background.motivation_floor"), 1.0)
	var share: float = Balance.number("background.value_share") * Balance.number("background.reference_performance") * motivation_factor
	var fatigue_mod: float = SessionReport.fatigue_modifier(state.fatigue)
	for entry in state.routine:
		var gains: Dictionary = RoutineRules.gains(entry, state, game)
		for key in gains:
			background[key] = float(background.get(key, 0.0)) + float(gains[key]) * share * fatigue_mod * own
	for key in background:
		state.attributes[key] = clampf(float(state.attributes[key]) + float(background[key]), 0.0, 100.0)
	var own_fatigue: float = RoutineRules.routine_fatigue(state.routine, state, game.catalog) * Balance.number("background.fatigue_share") * own
	var rest_days: int = 7 - own - (1 if state.trained_this_week else 0)
	var recovery_rate: float = Balance.number("recovery.recovery_base") + Balance.number("recovery.recovery_scale") * float(state.attributes.recovery) / 100.0
	var recovered: float = float(rest_days) * Balance.number("recovery.per_rest_day") * recovery_rate
	var fatigue_before: float = state.fatigue
	state.fatigue = clampf(state.fatigue + own_fatigue - recovered, 0.0, 100.0)
	if rest_days >= Balance.integer("recovery.rest_days_for_recovery_gain"):
		state.attributes.recovery = minf(float(state.attributes.recovery) + Balance.number("recovery.recovery_gain_per_week"), 100.0)
	var skipped: bool = not state.trained_this_week and state.is_available(week)
	if skipped:
		state.motivation = clampf(state.motivation + Balance.number("motivation.skipped_week"), 0.0, 100.0)
	if sat_out:
		state.injured_weeks -= 1
	if state.new_injury:
		state.injured_weeks = 1
		state.new_injury = false
	var readiness_after: float = Readiness.readiness(state)
	state.readiness_history.append(readiness_after)
	return {
		"id": state.id,
		"name": state.def.short,
		"trained": state.trained_this_week,
		"skipped": skipped,
		"sat_out": sat_out,
		"own_sessions": own,
		"motivation_factor": motivation_factor,
		"background": background,
		"fatigue_before": fatigue_before,
		"fatigue_after": state.fatigue,
		"rest_days": rest_days,
		"readiness_before": readiness_before,
		"readiness_after": readiness_after,
		"injured_next_week": state.injured_weeks > 0 and game.week < Balance.integer("campaign.weeks"),
	}


## A mini goal test: readiness against the milestone's threshold.
static func _test(game: RefCounted, state: RefCounted, milestone: Dictionary) -> Dictionary:
	var readiness: float = Readiness.readiness(state)
	var passed: bool = readiness >= float(milestone.threshold)
	var bonus: int = 0
	if passed:
		bonus = Balance.integer("income.mini_bonus")
		game.cash += bonus
		state.bonuses_paid += bonus
		game.rep_points += Balance.integer("income.rep_points_mini")
		state.motivation = clampf(state.motivation + Balance.number("motivation.mini_pass"), 0.0, 100.0)
	else:
		state.motivation = clampf(state.motivation + Balance.number("motivation.mini_fail"), 0.0, 100.0)
	var lagging: Array = Readiness.weakest(state).slice(0, 2)
	var guidance: Array = lagging.map(func(attribute: String) -> String: return game.catalog.lines.guidance[attribute])
	var result: Dictionary = {
		"week": milestone.week,
		"name": milestone.name,
		"threshold": float(milestone.threshold),
		"readiness": readiness,
		"passed": passed,
	}
	state.milestones.append(result)
	var shown: Dictionary = result.duplicate()
	shown["client"] = state.id
	shown["client_name"] = state.def.short
	shown["bonus"] = bonus
	shown["guidance"] = guidance
	shown["lagging"] = lagging
	return shown
