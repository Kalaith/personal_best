extends "res://addons/hatchery/testing/capture_runner.gd"
## Drives the real game through every screen and saves a PNG of each, with
## saving turned off. Needs a rendering window (not --headless):
##   godot --path . --script res://tools/capture.gd -- <output dir>
## Later weeks are reached by coaching automatically (as tools/season_sim.gd
## does) so the tour can show mini goals, race day and the finale.
const WeekRules = preload("res://scripts/core/week_rules.gd")
const RoutineRules = preload("res://scripts/core/routine_rules.gd")
const SessionSim = preload("res://scripts/core/session_sim.gd")
const SessionReport = preload("res://scripts/core/session_report.gd")

var main: Control


func tour() -> void:
	main = await open_scene("res://scenes/main.tscn")
	main.save.store.enabled = false
	await shot("01_title")
	main._new_season()
	await seconds(1.4)
	await shot("02_intake_walk")
	await seconds(2.0)
	await shot("03_intake_talk")
	for i in range(3):
		main.screens.current._advance()
	await frames(10)
	await shot("04_intake_assessment")
	main.screens.current.accepted.emit()
	await frames(10)
	await shot("05_routine")
	main.screens.current._confirm()
	await frames(5)
	main.screens.current._show_assessment()
	await frames(5)
	main.screens.current.accepted.emit()
	await frames(5)
	main.screens.current._confirm()
	await frames(10)
	await shot("06_planner")
	for state in main.game.clients:
		WeekRules.book(main.game, state, state.def.available_days[0])
	main.show_planner()
	await frames(5)
	main.show_shop()
	await frames(5)
	await shot("07_shop")
	main._start_week()
	await seconds(1.6)
	await shot("08_session_checkin_card")
	var screen: Control = main.screens.current
	screen._begin()
	await seconds(0.7)
	await shot("09_session_checkin_bar")
	await _play_session(screen, 3)
	await shot("10_session_exercise")
	await _play_session(screen, 40)
	await frames(10)
	await shot("11_wrapup")
	main.screens.current.continued.emit()
	await seconds(1.6)
	await _finish_sessions()
	await seconds(1.2)
	await shot("12_week_summary")
	await _auto_weeks(4)
	await shot("13_mini_goal")
	await _auto_weeks(11)
	main.screens.current.continued.emit()
	await seconds(1.2)
	await shot("13b_race_week_planner")
	await _auto_weeks(12)
	await shot("14_race_week_summary")
	main.screens.current.continued.emit()
	await seconds(2.4)
	await shot("15_race_jordan")
	main.screens.current.continued.emit()
	await seconds(2.4)
	await shot("16_race_peg")
	main.screens.current.continued.emit()
	await seconds(1.6)
	await shot("17_finale")


## Plays up to `presses` beats of the session on screen, aiming well.
func _play_session(screen: Control, presses: int) -> void:
	for i in range(presses):
		if not is_instance_valid(screen) or screen.state == "done":
			return
		if screen.state == "intro":
			screen._begin()
			await seconds(0.5)
		if screen.state == "running":
			var beat: Dictionary = screen.sim.prompt()
			var zone: Dictionary = _best_zone(screen.sim, beat)
			if beat.kind == "spot":
				await seconds(float(beat.reveal_delay) + 0.05)
			if not zone.is_empty():
				screen._bar.marker = (float(zone.perfect_from) + float(zone.perfect_to)) * 0.5
			screen._bar.stop()
			await seconds(0.3)
			screen._wait = 0.0
			await frames(3)


func _best_zone(sim: RefCounted, beat: Dictionary) -> Dictionary:
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


## Plays out the rest of this week's booked sessions on screen.
func _finish_sessions() -> void:
	for i in range(6):
		var current: Control = main.screens.current
		if current.get("sim") != null:
			await _play_session(current, 60)
			await frames(5)
		elif current.get("report") != null:
			current.continued.emit()
			await seconds(1.8)
		else:
			return


## Coaches in the rules (no screens) until `last_week` has ended, then shows
## that week's summary the way the game does.
func _auto_weeks(last_week: int) -> void:
	var game: RefCounted = main.game
	if main.screens.current.has_signal("continued"):
		main.screens.current.continued.emit()
		await frames(5)
	while game.week <= last_week and game.phase == "planner":
		for state in game.clients:
			var block: String = game.block().id
			if state.routine_block != block:
				state.routine = RoutineRules.suggested(state, block, game)
				state.routine_block = block
			for day in state.def.available_days:
				if WeekRules.book(game, state, day):
					break
		for state in WeekRules.sessions(game):
			var sim := SessionSim.new(game, state, state.booked_day)
			while not sim.done:
				var zone: Dictionary = _best_zone(sim, sim.prompt())
				sim.press((float(zone.perfect_from) + float(zone.perfect_to)) * 0.5 if not zone.is_empty() else 0.0, true)
			SessionReport.apply(sim)
		if game.week == last_week:
			main._week_sessions = []
			main._week_index = 0
			main._end_week()
			await seconds(2.2)
			return
		WeekRules.end_week(game)
		WeekRules.begin_week(game)
