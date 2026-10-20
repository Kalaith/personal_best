extends RefCounted
## Race day. There is no playable race: readiness on the start line becomes a
## predicted time, race-day variation (narrowed by Pacing Knowledge) moves
## it, and the client's weakest and strongest attributes become the moments
## that explain the result.
const Balance = preload("res://addons/hatchery/core/balance.gd")
const Readiness = preload("res://scripts/core/readiness.gd")



static func run(game: RefCounted, state: RefCounted) -> Dictionary:
	var rng: RandomNumberGenerator = game.rng_for("marathon-" + state.id)
	var catalog: RefCounted = game.catalog
	var niggle: bool = state.injured_weeks > 0
	var readiness: float = Readiness.readiness(state)
	var race_ready: float = Readiness.race_readiness(state)
	var goal: float = float(state.def.target.minutes)
	var cutoff: float = Balance.number("event.cutoff_minutes")
	var spread: float = Readiness.variation(state)
	var predicted: float = Readiness.predicted_minutes(state, race_ready)
	var swing: float = rng.randf_range(-spread, spread)
	var minutes: float = predicted * (1.0 + swing)
	var withdrew: bool = race_ready < Balance.number("event.withdraw_below_readiness")
	var finished: bool = not withdrew and minutes <= cutoff
	var achieved: bool = finished and minutes <= goal
	var moments: Array = _moments(state, rng, catalog, withdrew)
	if niggle:
		moments.push_front("Started with a niggle from a training injury and nursed it all the way.")
	var bonus: int = 0
	var rep_change: int = 0
	if achieved:
		bonus = Balance.integer("income.major_bonus")
		rep_change = Balance.integer("income.rep_points_major")
	elif niggle or withdrew:
		rep_change = Balance.integer("income.rep_points_injured_event")
	game.cash += bonus
	state.bonuses_paid += bonus
	game.rep_points = maxi(game.rep_points + rep_change, 0)
	var result: Dictionary = {
		"client": state.id,
		"client_name": state.def.short,
		"goal": _goal_text(state, catalog),
		"achieved": achieved,
		"finished": finished,
		"withdrew": withdrew,
		"withdrew_km": rng.randi_range(24, 34),
		"minutes": minutes,
		"time": Readiness.format_minutes(minutes),
		"position": Readiness.position(minutes) if finished else 0,
		"field": Balance.integer("event.field_size"),
		"readiness": readiness,
		"race_readiness": race_ready,
		"race_fatigue": state.fatigue,
		"niggle": niggle,
		"predicted": Readiness.format_minutes(predicted),
		"spread": spread,
		"swing": swing,
		"moments": moments,
		"explain": _explain(state, readiness, race_ready, spread, niggle),
		"advice": _advice(state, catalog),
		"bonus": bonus,
		"rep_change": rep_change,
		"fees": state.fees_paid,
		"bonuses": state.bonuses_paid,
	}
	state.event_result = result
	return result


static func _goal_text(state: RefCounted, catalog: RefCounted) -> String:
	var target: Dictionary = catalog.targets[state.def.target.type]
	var words: Dictionary = {"cutoff": Readiness.format_minutes(Balance.number("event.cutoff_minutes")), "time": Readiness.format_minutes(float(state.def.target.minutes))}
	return String(target.describe).format(words)


## Weakest attributes (below 90 % of the goal's need) become the low points;
## the strongest becomes the high point.
static func _moments(state: RefCounted, rng: RandomNumberGenerator, catalog: RefCounted, withdrew: bool) -> Array:
	var order: Array = Readiness.weakest(state)
	var count: int = Balance.integer("event.moments")
	var result: Array = []
	for attribute in order:
		if result.size() >= count - 1:
			break
		if Readiness.ratio(state, attribute) < 0.9:
			result.append(String(catalog.lines.moments[attribute].weak).format({"km": rng.randi_range(28, 36)}))
	var best: String = order.back()
	result.append(String(catalog.lines.moments[best].strong).format({"km": rng.randi_range(30, 38)}))
	if withdrew:
		result.append("Stepped off the course; the body had nothing left.")
	return result


static func _explain(state: RefCounted, readiness: float, race_ready: float, spread: float, niggle: bool) -> Array:
	var lines: Array = []
	lines.append("Readiness for the goal on race morning: %d%%. Around 90%% puts the goal time in reach; 100%% makes it likely." % int(round(readiness)))
	if race_ready < readiness - 0.5:
		var why: String = "a training injury" if niggle else "fatigue carried into race day (%d)" % int(round(state.fatigue))
		lines.append("Start-line readiness dropped to %d%% because of %s. A proper taper protects this." % [int(round(race_ready)), why])
	else:
		lines.append("Arrived fresh: the taper did its job.")
	lines.append("Race-day luck could swing the time by ±%.0f%%. Better Pacing Knowledge narrows this (±2%% at best)." % (spread * 100.0))
	return lines


static func _advice(state: RefCounted, catalog: RefCounted) -> String:
	var weakest: String = Readiness.weakest(state)[0]
	var target: String = catalog.targets[state.def.target.type].name.to_lower()
	return "For future %s clients like %s: %s" % [target, state.def.short, catalog.lines.guidance[weakest]]
