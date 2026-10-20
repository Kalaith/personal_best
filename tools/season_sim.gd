extends SceneTree
## Plays whole seasons headlessly with scripted coaching and prints each
## client's readiness at every mini goal and the marathon result. Use it after
## a balance change:
##
##     godot --headless --path . --script res://tools/season_sim.gd
##
## Coaches: "good" reads every signal and hits most zones, "average" is right
## most of the time, "careless" pushes every peak and misses often.
const Catalog = preload("res://scripts/core/catalog.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const SessionSim = preload("res://scripts/core/session_sim.gd")
const SessionReport = preload("res://scripts/core/session_report.gd")
const WeekRules = preload("res://scripts/core/week_rules.gd")
const RoutineRules = preload("res://scripts/core/routine_rules.gd")
const Readiness = preload("res://scripts/core/readiness.gd")
const ShopRules = preload("res://scripts/core/shop_rules.gd")

const COACHES: Dictionary = {
	"good": {"perfect": 0.45, "good": 0.45, "right": 0.95, "push_always": false, "buys": ["foam_rollers", "rowing_machine"]},
	"average": {"perfect": 0.2, "good": 0.55, "right": 0.75, "push_always": false, "buys": ["foam_rollers"]},
	"careless": {"perfect": 0.1, "good": 0.45, "right": 0.5, "push_always": true, "buys": []},
}
const SEEDS: Array[int] = [11, 22, 33, 44, 55, 66, 77, 88]
## Pass `-- trace` after the script to print every week of the first good season.
var trace: bool = OS.get_cmdline_user_args().has("trace")


func _init() -> void:
	var catalog := Catalog.new()
	if not catalog.load_all():
		print("DATA ERRORS:\n" + "\n".join(catalog.errors))
		quit(1)
		return
	for coach in COACHES:
		var totals: Dictionary = {}
		print("== %s coach ==" % coach)
		for seed_value in SEEDS:
			var line: String = _season(catalog, COACHES[coach], seed_value, totals)
			print(line)
			trace = false
		for id in totals:
			print("  %s: %s" % [id, totals[id]])
	quit(0)


func _season(catalog: Catalog, coach: Dictionary, seed_value: int, totals: Dictionary) -> String:
	var game := GameState.new(catalog)
	game.new_game(seed_value)
	game.phase = "planner"
	var policy := RandomNumberGenerator.new()
	policy.seed = seed_value * 7 + 1
	var parts: Array = []
	var summary: Dictionary = {}
	while game.phase == "planner":
		WeekRules.begin_week(game)
		for id in coach.buys:
			ShopRules.buy(game, id)
		for state in game.clients:
			var block: String = game.block().id
			if state.routine_block != block or state.routine.size() < RoutineRules.suggested(state, block, game).size():
				state.routine = RoutineRules.suggested(state, block, game)
				state.routine_block = block
			for day in state.def.available_days:
				if WeekRules.book(game, state, day):
					break
		for state in WeekRules.sessions(game):
			var sim := SessionSim.new(game, state, state.booked_day)
			while not sim.done:
				var answer: Array = _answer(sim, coach, policy)
				sim.press(answer[0], answer[1])
			SessionReport.apply(sim)
		summary = WeekRules.end_week(game)
		if trace:
			_trace(game, summary)
		for result in summary.milestone_results:
			parts.append("%s wk%d %d%s" % [result.client_name, result.week, int(round(result.readiness)), "✓" if result.passed else "✗"])
	for result in summary.marathon:
		parts.append("%s %s %s" % [result.client_name, result.time, "GOAL" if result.achieved else ("DNF" if result.withdrew else "miss")])
		var key: String = result.client_name
		var tally: Dictionary = totals.get(key, {"goals": 0, "runs": 0, "readiness": 0.0})
		tally.goals += 1 if result.achieved else 0
		tally.runs += 1
		tally.readiness += result.readiness / SEEDS.size()
		totals[key] = tally
	parts.append("$%d" % game.cash)
	return "  seed %d: %s" % [seed_value, " | ".join(parts)]


func _trace(game: GameState, summary: Dictionary) -> void:
	for entry in summary.clients:
		var state: RefCounted = game.client(entry.id)
		var values: Array = Catalog.ATTRIBUTES.map(func(key: String) -> String: return "%s %d/%d" % [key.left(3), int(state.attributes[key]), int(state.def.requirements[key])])
		print("    wk%d %s ready %d fatigue %d->%d mot %d rap %d | %s" % [summary.week, entry.name, int(entry.readiness_after), int(entry.fatigue_before), int(entry.fatigue_after), int(state.motivation), int(state.rapport), ", ".join(values)])


## [position, visible] for the current beat.
func _answer(sim: SessionSim, coach: Dictionary, policy: RandomNumberGenerator) -> Array:
	var beat: Dictionary = sim.prompt()
	var want: String = _correct_zone(sim, beat)
	if coach.push_always and beat.kind == "peak":
		want = "push"
	elif policy.randf() > coach.right and beat.kind != "pace" and beat.kind != "spot":
		var others: Array = beat.zones.filter(func(zone: Dictionary) -> bool: return zone.id != want)
		if not others.is_empty():
			want = others[policy.randi_range(0, others.size() - 1)].id
	var zone: Dictionary = {}
	for entry in beat.zones:
		if entry.id == want:
			zone = entry
	var roll: float = policy.randf()
	if zone.is_empty() or roll > coach.perfect + coach.good:
		return [0.999 if zone.is_empty() or float(zone.from) < 0.5 else 0.001, true]
	if roll < coach.perfect:
		return [(float(zone.perfect_from) + float(zone.perfect_to)) * 0.5, true]
	return [float(zone.from) + 0.001, true]


func _correct_zone(sim: SessionSim, beat: Dictionary) -> String:
	match beat.kind:
		"check_in":
			return sim.condition.question
		"pace":
			return "target"
		"spot":
			return "fault"
		"cue":
			return beat.fault.cue
		"encouragement":
			return sim.catalog.personalities[sim.client.def.personality].approach
		"effort":
			return {"green": "continue", "amber": "continue" if sim.block().push_on_amber else "ease", "red": "stop"}[beat.signal]
		"peak":
			var push: bool = beat.signal == "green" or (beat.signal == "amber" and sim.block().push_on_amber)
			return "push" if push else "hold"
	return ""
