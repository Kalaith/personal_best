extends RefCounted
## Promoter capture hook (declared as `promotion/setup_script`). The shared
## driver calls `action` for a plan's `hook` actions with the main scene. It
## only takes the player's own routes: a new season from a chosen seed, the
## buttons each screen offers, and coaching that stops the marker where a
## skilled coach would. Weeks played off screen run the real rules with the
## same coaching, as tools/season_sim.gd does. It never grants cash, kit or
## fitness, or edits a client.
const Balance = preload("res://addons/hatchery/core/balance.gd")
const WeekRules = preload("res://scripts/core/week_rules.gd")
const RoutineRules = preload("res://scripts/core/routine_rules.gd")
const SessionSim = preload("res://scripts/core/session_sim.gd")
const SessionReport = preload("res://scripts/core/session_report.gd")
const SessionScreen = preload("res://scripts/ui/session_screen.gd")

const COACH_NAME: String = "PromoCoach"


## Plans start on the title screen and need no setup.
static func prepare(setup: Dictionary) -> String:
	if not setup.is_empty():
		return "Personal Best takes no setup; start from the title and use hook actions"
	return ""


## Hook actions, by `name`:
## - `new_season` {seed}: New season, with the seed the title would draw.
## - `intake_next`: the intake's "Go on" button (once the client has walked in).
## - `intake_accept`: "Take them on: plan the first routine".
## - `confirm_routine`: "Confirm routine" (the advisor's suggestion on a first routine).
## - `book_all`: books each client on their first free day, as the planner's day buttons do.
## - `show` {screen: "planner" | "shop"}: the planner's Shop button, or Back.
## - `start_week`: "Start the week".
## - `continue`: the Continue button on a wrap-up, week or race screen.
## - `coach` {on, cardSeconds, wrapupSeconds}: plays coached sessions as a skilled coach.
## - `play_weeks` {through}: coaches off screen until week `through` has ended, then shows its summary.
static func action(scene: Node, action: Dictionary) -> String:
	if not scene.has_method("show_planner"):
		return "the current scene is not Personal Best's main scene"
	var current: Control = scene.screens.current
	match str(action.get("name", "")):
		"new_season":
			scene.game.new_game(maxi(int(action.get("seed", 1)), 1))
			scene.show_intake()
		"intake_next":
			if current.get("_next") == null or current._next.disabled:
				return "the intake has nothing to go on with yet"
			current._advance()
		"intake_accept":
			if not current.has_signal("accepted"):
				return "the intake assessment is not showing"
			current.accepted.emit()
		"confirm_routine":
			if not current.has_signal("confirmed"):
				return "the routine screen is not showing"
			current._confirm()
		"book_all":
			if scene.game.phase != "planner":
				return "sessions are booked from the planner"
			for state in scene.game.clients:
				for day in state.def.available_days:
					if WeekRules.book(scene.game, state, day):
						break
			scene.show_planner()
		"show":
			match str(action.get("screen", "")):
				"shop":
					scene.show_shop()
				"planner":
					scene.show_planner()
				_:
					return "show takes screen \"planner\" or \"shop\""
		"start_week":
			if scene.game.phase != "planner":
				return "the week starts from the planner"
			scene._start_week()
		"continue":
			if not current.has_signal("continued"):
				return "the current screen has no Continue"
			current.continued.emit()
		"coach":
			return _coach(scene, action)
		"play_weeks":
			return _play_weeks(scene, int(action.get("through", 0)))
		_:
			return "unknown hook '%s'" % str(action.get("name", ""))
	return ""


static func _coach(scene: Node, action: Dictionary) -> String:
	var coach: Node = scene.get_node_or_null(COACH_NAME)
	if not bool(action.get("on", true)):
		if coach != null:
			coach.queue_free()
		return ""
	if coach == null:
		coach = Coach.new()
		coach.name = COACH_NAME
		scene.add_child(coach)
	coach.card_seconds = float(action.get("cardSeconds", 2.5))
	coach.wrapup_seconds = float(action.get("wrapupSeconds", -1.0))
	return ""


## Coaches the rest of this week (the session on screen and any still to
## come) and further weeks in the rules, then ends week `through` the way the
## game does, with its summary screen.
static func _play_weeks(scene: Node, through: int) -> String:
	var game: RefCounted = scene.game
	if through < game.week or through > Balance.integer("campaign.weeks"):
		return "play_weeks needs a week from %d to the race week" % game.week
	var current: Control = scene.screens.current
	if current is SessionScreen or current.get("report") != null:
		if current is SessionScreen and current.state != "done":
			_coach_sim(current.sim)
			SessionReport.apply(current.sim)
		for i in range(scene._week_index, scene._week_sessions.size()):
			var state: RefCounted = scene._week_sessions[i]
			_coach_sim_and_apply(game, state)
		if game.week == through:
			_show_week_end(scene)
			return ""
		WeekRules.end_week(game)
		WeekRules.begin_week(game)
	elif game.phase != "planner":
		return "play_weeks starts from the planner or a coached session"
	while game.week <= through:
		for state in game.clients:
			var block: String = game.block().id
			if state.routine_block != block:
				state.routine = RoutineRules.suggested(state, block, game)
				state.routine_block = block
			for day in state.def.available_days:
				if WeekRules.book(game, state, day):
					break
		for state in WeekRules.sessions(game):
			_coach_sim_and_apply(game, state)
		if game.week == through:
			_show_week_end(scene)
			return ""
		WeekRules.end_week(game)
		WeekRules.begin_week(game)
	return ""


static func _show_week_end(scene: Node) -> void:
	scene._week_sessions = []
	scene._week_index = 0
	scene._end_week()


static func _coach_sim_and_apply(game: RefCounted, state: RefCounted) -> void:
	var sim := SessionSim.new(game, state, state.booked_day)
	_coach_sim(sim)
	SessionReport.apply(sim)


static func _coach_sim(sim: RefCounted) -> void:
	while not sim.done:
		var zone: Dictionary = Coach.best_zone(sim, sim.prompt())
		sim.press((float(zone.perfect_from) + float(zone.perfect_to)) * 0.5 if not zone.is_empty() else 0.0, true)


## Plays the on-screen sessions in real time: reads each exercise card for a
## moment, then presses when the sweeping marker crosses the right zone's
## centre, exactly as a player would press the coach key.
class Coach extends Node:
	## Minimum time on a beat before pressing, like a person's reaction.
	const REACTION_SECONDS: float = 0.45

	var card_seconds: float = 2.5
	## Seconds a wrap-up stays before Continue; negative leaves it up.
	var wrapup_seconds: float = -1.0
	var _screen: Control
	var _held: float = 0.0
	var _last_state: String = ""

	## The zone a coach who reads the client correctly aims for (as in tools/capture.gd).
	static func best_zone(sim: RefCounted, beat: Dictionary) -> Dictionary:
		var want: String = ""
		match beat.kind:
			"check_in":
				want = sim.condition.question
			"pace":
				want = "target"
			"spot":
				want = "fault"
			"cue":
				want = beat.fault.cue
			"encouragement":
				want = beat.best
			"effort":
				want = {"green": "continue", "amber": "continue" if sim.block().push_on_amber else "ease", "red": "stop"}[beat.signal]
			"peak":
				want = "push" if beat.signal == "green" or (beat.signal == "amber" and sim.block().push_on_amber) else "hold"
		for zone in beat.zones:
			if zone.id == want:
				return zone
		return {}

	func _process(delta: float) -> void:
		var current: Control = get_parent().screens.current
		if current != _screen:
			_screen = current
			_held = 0.0
			_last_state = ""
		if current is SessionScreen:
			_coach_screen(current, delta)
		elif current.get("report") != null and wrapup_seconds >= 0.0:
			_held += delta
			if _held >= wrapup_seconds:
				_held = -INF
				current.continued.emit()

	func _coach_screen(screen: Control, delta: float) -> void:
		if screen.state != _last_state:
			_last_state = screen.state
			_held = 0.0
		_held += delta
		if screen.state == "intro" and _held >= card_seconds:
			screen._press()
		elif screen.state == "running" and _held >= REACTION_SECONDS:
			var bar: Control = screen._bar
			if not bar.zones_visible():
				return
			var zone: Dictionary = best_zone(screen.sim, screen.sim.prompt())
			var from: float = float(zone.get("perfect_from", 0.0))
			var to: float = float(zone.get("perfect_to", 0.0))
			if zone.is_empty() or (bar.marker >= from and bar.marker <= to):
				screen._press()
