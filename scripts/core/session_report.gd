extends RefCounted
## Turns a finished session into progress and pay, following the design's
## formula: routine value × suitability × session performance × fatigue
## modifier × peak-moment bonuses. Returns everything the wrap-up screen
## explains, so each number on it can be traced to a choice.
const Balance = preload("res://addons/hatchery/core/balance.gd")
const Readiness = preload("res://scripts/core/readiness.gd")
const RoutineRules = preload("res://scripts/core/routine_rules.gd")
const Catalog = preload("res://scripts/core/catalog.gd")


## 0..1: the average of every exercise minigame's score.
static func performance(sim: RefCounted) -> float:
	if sim.records.is_empty():
		return 0.0
	var total: float = 0.0
	for rec in sim.records:
		total += exercise_score(rec)
	return total / float(sim.records.size())


static func exercise_score(rec: Dictionary) -> float:
	if rec.scores.is_empty():
		return 0.0
	var total: float = 0.0
	for score in rec.scores:
		total += float(score)
	return total / float(rec.scores.size())


## Tired clients get less from the same work (1.0 fresh, the floor at 100 fatigue).
static func fatigue_modifier(fatigue: float) -> float:
	var floor_value: float = Balance.number("progress.fatigue_modifier_floor")
	return 1.0 - (1.0 - floor_value) * clampf(fatigue / 100.0, 0.0, 1.0)


static func apply(sim: RefCounted) -> Dictionary:
	var game: RefCounted = sim.game
	var client: RefCounted = sim.client
	var before: Dictionary = client.attributes.duplicate()
	var readiness_before: float = Readiness.readiness(client)
	var perf: float = performance(sim)
	var fatigue_mod: float = fatigue_modifier(sim.start_fatigue)
	var exercises: Array = []
	var added_fatigue: float = sim.extra_fatigue
	for rec in sim.records:
		var assessed: Dictionary = RoutineRules.assess(rec.entry, client, game)
		var conditions: Dictionary = RoutineRules.conditions(rec.entry, game)
		var bonus: float = maxf(1.0 + float(rec.peak_bonus), 0.5)
		var gains: Dictionary = RoutineRules.gains(rec.entry, client, game)
		var applied: Dictionary = {}
		for key in gains:
			applied[key] = float(gains[key]) * perf * fatigue_mod * bonus
		if rec.def.minigame == "pace" or rec.def.minigame == "effort":
			var knowledge: float = Balance.number("progress.knowledge_per_pace_hit") * Balance.number("progress.global_gain") * float(rec.knowledge_hits)
			applied["knowledge"] = float(applied.get("knowledge", 0.0)) + knowledge
		for key in applied:
			client.attributes[key] = clampf(float(client.attributes[key]) + float(applied[key]), 0.0, 100.0)
		added_fatigue += RoutineRules.fatigue(rec.entry, client, rec.def)
		var notes: Array = []
		for note in assessed.notes + conditions.notes:
			if note.tone == "bad" or note.tone == "warn":
				notes.append(note)
		exercises.append({
			"name": rec.def.name,
			"score": exercise_score(rec),
			"peaks": rec.peaks,
			"peak_bonus": float(rec.peak_bonus),
			"gains": applied,
			"unsuitable": assessed.unsuitable,
			"notes": notes,
		})
	var fatigue_before: float = client.fatigue
	client.fatigue = clampf(client.fatigue + added_fatigue, 0.0, 100.0)
	var motivation_before: float = client.motivation
	var motivation: float = Balance.number("motivation.per_performance") * perf + Balance.number("motivation.session_base") + sim.motivation_change
	if sim.injured:
		motivation += Balance.number("motivation.injury")
		client.new_injury = true
	client.motivation = clampf(client.motivation + motivation, 0.0, 100.0)
	var fee: int = game.session_fee(client)
	game.cash += fee
	client.fees_paid += fee
	client.sessions_done += 1
	client.trained_this_week = true
	var changes: Array = []
	for attribute in Catalog.ATTRIBUTES:
		changes.append({"attribute": attribute, "before": float(before[attribute]), "after": float(client.attributes[attribute]), "need": float(client.def.requirements[attribute])})
	return {
		"client": client.id,
		"performance": perf,
		"fatigue_modifier": fatigue_mod,
		"check_in": sim.check_in,
		"exercises": exercises,
		"changes": changes,
		"readiness_before": readiness_before,
		"readiness_after": Readiness.readiness(client),
		"fatigue_before": fatigue_before,
		"fatigue_after": client.fatigue,
		"motivation_before": motivation_before,
		"motivation_after": client.motivation,
		"rapport_before": sim.start_rapport,
		"rapport_after": client.rapport,
		"fee": fee,
		"injured": sim.injured,
	}
