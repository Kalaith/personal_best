extends "res://addons/hatchery/testing/capture_runner.gd"
## Drives the real game through every screen and saves a PNG of each, with
## saving turned off. Needs a rendering window (not --headless):
##   godot --path . --script res://tools/capture.gd
## Shots go to docs/verification/ (the toolkit's capture runner). Audio is muted.
## Later weeks are reached by coaching automatically (as tools/season_sim.gd
## does) so the tour can show mini goals, race day and the finale.
const WeekRules = preload("res://scripts/core/week_rules.gd")
const RoutineRules = preload("res://scripts/core/routine_rules.gd")
const SessionSim = preload("res://scripts/core/session_sim.gd")
const SessionReport = preload("res://scripts/core/session_report.gd")

var main: Control
## Words on screen per shot, printed after each capture so a screen's text
## load can be compared before and after a change.
var word_counts: Dictionary = {}


## Saves the shot and counts the words a player would have to read in it.
func shot(name: String) -> String:
	var path: String = await super.shot(name)
	word_counts[name] = _count_words(root)
	print("WORDS %s: %d" % [name, word_counts[name]])
	return path


func tour() -> void:
	main = await open_scene("res://scenes/main.tscn")
	# Muted after the scene opens, because loading settings applies the saved volume to the bus.
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	main.save.store.enabled = false
	main.settings.store.save_enabled = false
	await shot("01_title")
	main.open_settings()
	await frames(10)
	await shot("01b_settings")
	main.settings_page.tabs.current_tab = 1
	await frames(5)
	await shot("01c_settings_controls")
	main.close_settings()
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
	await _inspect_routine_editor(main.screens.current)
	if OS.get_cmdline_user_args().has("--routine-only"):
		return
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
	await shot("06b_planner_booked")
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


## Exercise real editor controls, including a rebuild with keyboard focus.
func _inspect_routine_editor(screen: Control) -> void:
	var original: Array = screen.entries.duplicate(true)
	var increase: Button = _routine_control(screen, "2_sets_up") as Button
	increase.grab_focus()
	increase.pressed.emit()
	await frames(5)
	assert(screen.entries[2].sets == original[2].sets + 1)
	assert(root.gui_get_focus_owner() == _routine_control(screen, "2_sets_up"))
	var hard: Button = _routine_control(screen, "3_load_hard") as Button
	hard.grab_focus()
	hard.pressed.emit()
	await frames(5)
	assert(screen.entries[3].load == "hard")
	assert(root.gui_get_focus_owner() == _routine_control(screen, "3_load_hard"))
	await shot("05b_routine_warning")
	while not screen.entries.is_empty():
		var remove: Button = _routine_control(screen, "0_remove") as Button
		remove.grab_focus()
		remove.pressed.emit()
		await frames(3)
	assert(screen._confirm_button.disabled)
	assert(root.gui_get_focus_owner() == _routine_control(screen, "add"))
	await shot("05c_routine_empty")
	(_routine_control(screen, "add") as Button).pressed.emit()
	await frames(3)
	assert(screen.entries.size() == 1 and not screen._confirm_button.disabled)
	screen.entries = original
	screen._rebuild()
	await frames(5)
	print("Routine editor: edits, focus, removal, empty state and add verified")


func _routine_control(screen: Control, key: String) -> Control:
	for control in screen.find_children("*", "Control", true, false):
		if String(control.get_meta("routine_focus", "")) == key:
			return control as Control
	return null


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


## Words in every visible label, button and rich text that sits inside the window.
func _count_words(node: Node) -> int:
	var total: int = 0
	if node is Control and (node as Control).is_visible_in_tree():
		var control: Control = node
		var text: String = ""
		if control is RichTextLabel:
			text = (control as RichTextLabel).get_parsed_text()
		elif control is Label:
			text = (control as Label).text
		elif control is Button:
			text = (control as Button).text
		if not text.is_empty() and root.get_visible_rect().encloses(control.get_global_rect()):
			for word in text.split(" ", false):
				if word.strip_edges().length() > 0 and word != "·" and word != "→":
					total += 1
	for child in node.get_children():
		total += _count_words(child)
	return total
