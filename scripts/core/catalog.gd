extends RefCounted
## Every authored catalog, read once and validated at startup: clients,
## exercises, the shop and the text lines. Balance numbers are read through
## the toolkit Balance facade; `load_all` checks the paths the rules use, so a
## typo fails at startup instead of mid-session.
const JsonIO = preload("res://addons/hatchery/core/json_io.gd")
const DataRules = preload("res://addons/hatchery/core/data_rules.gd")
const Balance = preload("res://addons/hatchery/core/balance.gd")
const Encouragement = preload("res://scripts/core/encouragement.gd")

const ATTRIBUTES: Array[String] = ["endurance", "pace", "strength", "recovery", "knowledge"]
const MINIGAMES: Array[String] = ["pace", "technique", "encouragement", "effort"]
const EXERCISE_RULES: Array[String] = ["no_hard", "beginner_no_hard", "taper_no_hard", "base_caution"]
const SHOP_EFFECTS: Array[String] = ["show_energy", "weatherproof_runs", "precise_pace", "full_intervals", "capacity"]
const LOADS: Array[String] = ["easy", "moderate", "hard"]
const BLOCKS: Array[String] = ["base", "build", "peak", "taper"]
## Balance paths read by the rules; checked at startup.
const BALANCE_PATHS: Array[String] = [
	"campaign.weeks", "campaign.start_cash", "campaign.seed", "campaign.days", "campaign.blocks",
	"readiness.weights", "readiness.race_fatigue_penalty", "milestones",
	"event.cutoff_minutes", "event.time_at_full_readiness", "event.time_per_missing_readiness",
	"event.variation_low_knowledge", "event.variation_high_knowledge", "event.withdraw_below_readiness",
	"event.field_size", "event.field_mean_minutes", "event.field_spread_minutes", "event.moments",
	"event.projection_from_week",
	"bar.pass_seconds", "bar.max_speed_up", "bar.zone_width", "bar.perfect_width", "bar.rapport_widen",
	"bar.fatigue_narrow", "bar.mood_adjust", "bar.treadmill_perfect_bonus", "bar.score_perfect",
	"bar.score_good", "bar.score_miss", "bar.score_wrong_choice", "bar.min_presses", "bar.max_presses",
	"bar.peak_zone_width", "bar.choice_zone_width", "bar.technique_reveal_min", "bar.technique_reveal_max",
	"bar.technique_window_passes", "bar.pace_drift",
	"energy.green_above", "energy.red_below", "energy.drain_per_press", "energy.endurance_drain_relief",
	"energy.peak_on_cross",
	"peaks.correct_bonus", "peaks.correct_rapport", "peaks.green_hold_penalty", "peaks.amber_hold_penalty",
	"peaks.amber_push_fatigue", "peaks.red_push_fatigue", "peaks.red_push_injury_chance",
	"peaks.red_push_rapport", "peaks.missed_motivation", "peaks.effort_red_continue_fatigue",
	"check_in.correct_energy_share", "check_in.correct_mood", "check_in.correct_rapport",
	"check_in.wrong_mood", "check_in.miss_mood", "check_in.start_mood",
	"encouragement.right_rapport", "encouragement.wrong_rapport", "encouragement.right_motivation",
	"encouragement.usual_score", "encouragement.situation_weights", "encouragement.situation_trigger",
	"encouragement.situation_hint_share", "effort.stop_recovery",
	"progress.global_gain", "progress.load_value", "progress.load_fatigue", "progress.load_intensity",
	"progress.fatigue_modifier_floor", "progress.suitability_min", "progress.suitability_max",
	"progress.unsuitable_factor", "progress.weakness_ratio", "progress.weakness_bonus",
	"progress.met_ratio", "progress.met_factor", "progress.knowledge_per_pace_hit",
	"progress.weather_penalty", "progress.road_interval_factor", "progress.kg_easy_below",
	"progress.kg_hard_above", "progress.kg_unsuitable_above", "progress.kg_base", "progress.kg_per_strength",
	"background.value_share", "background.reference_performance", "background.fatigue_share",
	"background.motivation_full_at", "background.motivation_floor",
	"recovery.per_rest_day", "recovery.recovery_base", "recovery.recovery_scale",
	"recovery.rest_days_for_recovery_gain", "recovery.recovery_gain_per_week",
	"motivation.per_performance", "motivation.session_base", "motivation.skipped_week",
	"motivation.mini_pass", "motivation.mini_fail", "motivation.injury",
	"income.reputation_fee_step", "income.mini_bonus", "income.major_bonus", "income.rep_points_per_level",
	"income.rep_points_mini", "income.rep_points_major", "income.rep_points_injured_event", "income.max_reputation",
	"weather.kinds", "gym.base_capacity", "gym.base_slots",
]

var errors: Array[String] = []
var clients: Array = []
var targets: Dictionary = {}
var personalities: Dictionary = {}
var attributes: Array = []
var efforts: Array = []
var exercises: Dictionary = {}
## Exercise ids in catalog order, for stable menus.
var exercise_order: Array[String] = []
var starting_equipment: Array = []
var shop_items: Dictionary = {}
var shop_order: Array[String] = []
var lines: Dictionary = {}


func load_all() -> bool:
	errors.clear()
	_check_balance()
	_load_exercises(JsonIO.read_object("res://data/exercises.json", errors, 1))
	_load_shop(JsonIO.read_object("res://data/shop.json", errors, 1))
	_load_clients(JsonIO.read_object("res://data/clients.json", errors, 1))
	_load_lines(JsonIO.read_object("res://data/lines.json", errors, 1))
	return errors.is_empty()


func client(id: String) -> Dictionary:
	for entry in clients:
		if entry.id == id:
			return entry
	return {}


func exercise(id: String) -> Dictionary:
	return exercises.get(id, {})


func attribute_name(id: String) -> String:
	for entry in attributes:
		if entry.id == id:
			return entry.name
	return id.capitalize()


func equipment_name(id: String) -> String:
	for entry in starting_equipment:
		if entry.id == id:
			return entry.name
	return shop_items[id].name if shop_items.has(id) else id


func line_list(key: String) -> Array:
	return lines.get(key, [])


func _check_balance() -> void:
	var data: Dictionary = JsonIO.read_object(Balance.path, errors, 1)
	if data.is_empty():
		return
	for path in BALANCE_PATHS:
		if not Balance.has(path):
			errors.append("balance.json is missing " + path)
	if not errors.is_empty():
		return
	var weights: Dictionary = Balance.dict("readiness.weights")
	var rules := DataRules.new(errors, "balance.readiness.weights")
	var total: float = 0.0
	for key in ATTRIBUTES:
		if rules.number_between(weights, key, 0.0, 1.0):
			total += float(weights[key])
	if absf(total - 1.0) > 0.001:
		rules.fail("weights must add up to 1")
	var block_ids: Array = []
	for block in Balance.list("campaign.blocks"):
		var check := DataRules.new(errors, "balance.campaign.blocks")
		if check.one_of(block, "id", BLOCKS):
			block_ids.append(block.id)
		check.integer_between(block, "first_week", 1, 12)
		check.integer_between(block, "last_week", 1, 12)
		check.boolean(block, "push_on_amber")
	if block_ids != BLOCKS:
		errors.append("balance.campaign.blocks must be base, build, peak and taper in order")
	for milestone in Balance.list("milestones"):
		var check := DataRules.new(errors, "balance.milestones")
		check.integer_between(milestone, "week", 1, 12)
		check.text(milestone, "name")
		check.number_between(milestone, "threshold", 0, 100)


func _load_exercises(data: Dictionary) -> void:
	if data.is_empty():
		return
	var rules := DataRules.new(errors, "exercises.json")
	if rules.list(data, "attributes", false):
		attributes = data.attributes
		var ids: Array = rules.unique_ids(attributes)
		if ids != Array(ATTRIBUTES):
			rules.fail("attributes must be " + ", ".join(ATTRIBUTES))
	if rules.list(data, "efforts", false):
		efforts = data.efforts
	if not rules.list(data, "exercises", false):
		return
	rules.unique_ids(data.exercises)
	for entry in data.exercises:
		var check := DataRules.new(errors, "exercises[%s]" % entry.get("id", "?"))
		check.text(entry, "name")
		check.one_of(entry, "kind", ["run", "strength", "cardio", "mobility"])
		check.one_of(entry, "minigame", MINIGAMES)
		check.boolean(entry, "outdoor")
		check.one_of(entry, "load_kind", ["level", "kg"])
		check.number(entry, "fatigue")
		check.number_between(entry, "intensity", 0.0, 3.0)
		check.number_between(entry, "effort", 0.0, 1.0)
		check.text(entry, "why")
		if check.object(entry, "sets"):
			DataRules.new(errors, "%s.sets" % entry.get("id", "?")).integer_between(entry.sets, "min", 1, 8)
			DataRules.new(errors, "%s.sets" % entry.get("id", "?")).integer_between(entry.sets, "max", 1, 8)
			DataRules.new(errors, "%s.sets" % entry.get("id", "?")).integer_between(entry.sets, "default", 1, 8)
		if check.object(entry, "gains"):
			for key in entry.gains:
				if not ATTRIBUTES.has(key) or not DataRules.finite(entry.gains[key]):
					check.fail("gains has an unknown attribute or a non-number: " + str(key))
		if check.object(entry, "goal_fit"):
			check.number_between(entry.goal_fit, "finish", 0.5, 1.2)
			check.number_between(entry.goal_fit, "time", 0.5, 1.2)
		if check.list(entry, "rules"):
			for rule in entry.rules:
				if not EXERCISE_RULES.has(rule):
					check.fail("unknown rule " + str(rule))
		check.list(entry, "requires", false)
		if entry.get("load_kind") == "kg" and check.object(entry, "kg"):
			check.integer(entry.kg, "min")
			check.integer(entry.kg, "max")
			check.integer(entry.kg, "step")
		if entry.get("minigame") == "technique" and check.list(entry, "faults", false):
			for fault in entry.faults:
				check.text(fault, "fault")
				check.text(fault, "cue")
				check.text(fault, "show")
		if entry.get("minigame") != "technique":
			check.text(entry, "cue")
		exercises[entry.id] = entry
		exercise_order.append(entry.id)


func _load_shop(data: Dictionary) -> void:
	if data.is_empty():
		return
	var rules := DataRules.new(errors, "shop.json")
	if rules.list(data, "starting", false):
		rules.unique_ids(data.starting)
		starting_equipment = data.starting
		for entry in data.starting:
			DataRules.new(errors, "starting[%s]" % entry.get("id", "?")).integer_between(entry, "slots", 0, 1)
	if not rules.list(data, "items", false):
		return
	rules.unique_ids(data.items)
	for entry in data.items:
		var check := DataRules.new(errors, "items[%s]" % entry.get("id", "?"))
		check.text(entry, "name")
		check.text(entry, "about")
		check.integer_between(entry, "cost", 1, 100000)
		check.integer_between(entry, "reputation", 1, 5)
		check.integer_between(entry, "slots", 0, 1)
		if check.list(entry, "effects"):
			for effect in entry.effects:
				if not SHOP_EFFECTS.has(effect):
					check.fail("unknown effect " + str(effect))
			if entry.effects.has("capacity"):
				check.integer(entry, "clients")
				check.integer(entry, "extra_slots")
		if entry.has("future"):
			check.boolean(entry, "future")
		shop_items[entry.id] = entry
		shop_order.append(entry.id)
	var owned: Array = starting_equipment.map(func(item: Dictionary) -> String: return item.id)
	for id in exercise_order:
		for need in exercises[id].requires:
			if not owned.has(need) and not shop_items.has(need):
				errors.append("exercises[%s] requires unknown equipment %s" % [id, need])


func _load_clients(data: Dictionary) -> void:
	if data.is_empty():
		return
	var rules := DataRules.new(errors, "clients.json")
	if rules.object(data, "targets"):
		targets = data.targets
	if rules.list(data, "personalities", false):
		for entry in data.personalities:
			personalities[entry.id] = entry
	if not rules.list(data, "clients", false):
		return
	rules.unique_ids(data.clients)
	var days: Array = Balance.list("campaign.days") if errors.is_empty() else []
	for entry in data.clients:
		var check := DataRules.new(errors, "clients[%s]" % entry.get("id", "?"))
		for key in ["name", "short", "pronoun", "life", "intake"]:
			check.text(entry, key)
		check.one_of(entry, "experience", ["none", "some", "experienced"])
		check.one_of(entry, "personality", personalities.keys())
		check.integer_between(entry, "motivation", 0, 100)
		check.integer_between(entry, "rapport", 0, 100)
		check.integer_between(entry, "fee", 1, 1000)
		check.integer_between(entry, "sessions_per_week", 1, 2)
		check.integer_between(entry, "own_sessions_per_week", 0, 5)
		if check.object(entry, "target"):
			check.one_of(entry.target, "type", targets.keys())
			check.integer(entry.target, "minutes")
		for key in ["attributes", "requirements"]:
			if check.object(entry, key):
				for attribute in ATTRIBUTES:
					DataRules.new(errors, "%s.%s" % [entry.get("id", "?"), key]).number_between(entry[key], attribute, 1 if key == "requirements" else 0, 100)
		if check.list(entry, "available_days", false):
			for day in entry.available_days:
				if not days.has(day):
					check.fail("unknown day " + str(day))
		check.list(entry, "unavailable_weeks")
		check.list(entry, "intro", false)
		check.object(entry, "check_in_weights")
		check.object(entry, "look")
		if check.object(entry, "suggested"):
			for block in BLOCKS:
				if DataRules.new(errors, "%s.suggested" % entry.get("id", "?")).list(entry.suggested, block, false):
					for item in entry.suggested[block]:
						_check_routine_entry(check, item)
		clients.append(entry)


func _check_routine_entry(check: DataRules, item: Dictionary) -> void:
	if not exercises.has(item.get("exercise")):
		check.fail("suggested routine uses unknown exercise " + str(item.get("exercise")))
		return
	var def: Dictionary = exercises[item.exercise]
	check.integer_between(item, "sets", int(def.sets.min), int(def.sets.max))
	if def.load_kind == "kg":
		check.integer_between(item, "kg", int(def.kg.min), int(def.kg.max))
	else:
		check.one_of(item, "load", LOADS)


func _load_lines(data: Dictionary) -> void:
	if data.is_empty():
		return
	var rules := DataRules.new(errors, "lines.json")
	for key in ["questions", "check_in_states", "approaches", "encouragement_situations"]:
		rules.list(data, key, false)
	for key in ["approach_right", "approach_wrong", "signals", "peak_feedback", "moments", "guidance", "advice", "blocks", "minigame_advice"]:
		rules.object(data, key)
	rules.text(data, "encouragement_usual")
	if not errors.is_empty():
		return
	var questions: Array = data.questions.map(func(q: Dictionary) -> String: return q.id)
	for state in data.check_in_states:
		var check := DataRules.new(errors, "check_in_states[%s]" % state.get("id", "?"))
		check.one_of(state, "question", questions)
		check.number(state, "energy")
		check.number(state, "mood")
	for attribute in ATTRIBUTES:
		if not data.moments.has(attribute) or not data.guidance.has(attribute):
			rules.fail("moments and guidance need an entry for " + attribute)
	for block in BLOCKS:
		if not data.blocks.has(block):
			rules.fail("blocks needs " + block)
	_check_situations(rules, data)
	for colour in ["green", "amber", "red"]:
		if not data.signals.has(colour):
			rules.fail("signals needs " + colour)
	lines = data


## Every encouragement situation once, each naming approaches that exist.
func _check_situations(rules: DataRules, data: Dictionary) -> void:
	var approaches: Array = data.approaches.map(func(a: Dictionary) -> String: return a.id)
	var seen: Array = rules.unique_ids(data.encouragement_situations)
	if seen != Array(Encouragement.SITUATIONS):
		rules.fail("encouragement_situations must be " + ", ".join(Encouragement.SITUATIONS))
	var weights: Dictionary = Balance.dict("encouragement.situation_weights") if Balance.has("encouragement.situation_weights") else {}
	for situation in data.encouragement_situations:
		var check := DataRules.new(errors, "encouragement_situations[%s]" % situation.get("id", "?"))
		check.text(situation, "state")
		if not weights.has(situation.get("id")):
			check.fail("needs a weight in balance encouragement.situation_weights")
		if situation.get("id") == "steady":
			continue
		check.one_of(situation, "approach", approaches)
		for key in ["cue", "right", "wrong"]:
			check.text(situation, key)
		for personality in (situation.get("overrides", {}) as Dictionary):
			if not personalities.has(personality) or not approaches.has(situation.overrides[personality]):
				check.fail("override %s names an unknown personality or approach" % personality)
