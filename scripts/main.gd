extends Control
## Owns the catalog, the campaign and its save, and walks the season from
## screen to screen: title → each client's intake and first routine → the
## weekly planner → that week's coached sessions and their wrap-ups → the
## week's summary (with any mini goal) → … → race day → the season's end.
## Also owns the player's settings and the settings page over the title and
## the planner.
const Balance = preload("res://addons/hatchery/core/balance.gd")
const ScreenSwitcher = preload("res://addons/hatchery/ui/screen_switcher.gd")
const Display = preload("res://addons/hatchery/settings/display.gd")
const Catalog = preload("res://scripts/core/catalog.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const SaveGame = preload("res://scripts/core/save_game.gd")
const WeekRules = preload("res://scripts/core/week_rules.gd")
const ShopRules = preload("res://scripts/core/shop_rules.gd")
const SessionSim = preload("res://scripts/core/session_sim.gd")
const SessionReport = preload("res://scripts/core/session_report.gd")
const Style = preload("res://scripts/ui/style.gd")
const GameSettings = preload("res://scripts/ui/game_settings.gd")
const TitleScreen = preload("res://scripts/ui/title_screen.gd")
const IntakeScreen = preload("res://scripts/ui/intake_screen.gd")
const RoutineScreen = preload("res://scripts/ui/routine_screen.gd")
const PlannerScreen = preload("res://scripts/ui/planner_screen.gd")
const ShopScreen = preload("res://scripts/ui/shop_screen.gd")
const SessionScreen = preload("res://scripts/ui/session_screen.gd")
const WrapupScreen = preload("res://scripts/ui/wrapup_screen.gd")
const WeekScreen = preload("res://scripts/ui/week_screen.gd")
const RaceScreen = preload("res://scripts/ui/race_screen.gd")
const FinaleScreen = preload("res://scripts/ui/finale_screen.gd")

var catalog := Catalog.new()
var game: GameState
var save: SaveGame
var settings: GameSettings
## The settings page while it is open over the current screen.
var settings_page: Control
## What had focus when the settings page opened, to return to on close.
var _focus_before: Control
var screens: ScreenSwitcher = ScreenSwitcher.new(self) as ScreenSwitcher
## This week's booked clients, in day order, and which one is next.
var _week_sessions: Array = []
var _week_index: int = 0
## Deliveries that arrived when the current week began.
var _arrived: Array = []
var _notice: String = ""
var _fade: ColorRect


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Style.make_theme()
	settings = GameSettings.new(get_tree())
	settings.load_and_apply()
	if not catalog.load_all():
		var error: Label = Style.ui.wrapped("Personal Best could not load its data:\n" + "\n".join(catalog.errors), 16, Style.RED)
		error.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(error)
		push_error("\n".join(catalog.errors))
		return
	game = GameState.new(catalog)
	save = SaveGame.new(catalog)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.z_index = 100
	add_child(_fade)
	show_title()


func _unhandled_input(event: InputEvent) -> void:
	screens.handle_back(event)


func _show(next: Control, back: Callable = Callable()) -> void:
	close_settings()
	screens.show(next, back)
	if next.has_signal("settings_requested"):
		next.connect("settings_requested", open_settings)
	move_child(_fade, -1)


func open_settings() -> void:
	if is_instance_valid(settings_page):
		return
	_focus_before = get_viewport().gui_get_focus_owner()
	settings_page = settings.make_page()
	settings_page.close_requested.connect(close_settings)
	add_child(settings_page)
	move_child(_fade, -1)
	settings_page.close_button.grab_focus.call_deferred()


func close_settings() -> void:
	if not is_instance_valid(settings_page):
		return
	settings_page.queue_free()
	settings_page = null
	if is_instance_valid(_focus_before) and _focus_before.is_visible_in_tree():
		_focus_before.grab_focus.call_deferred()


## Fades to black, runs `between` (which swaps the screen) and fades back.
func fade_through(between: Callable, hold: float = 0.4) -> void:
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween: Tween = create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 0.6)
	tween.tween_callback(between)
	tween.tween_interval(hold)
	tween.tween_property(_fade, "color:a", 0.0, 0.6)
	tween.tween_callback(func() -> void: _fade.mouse_filter = Control.MOUSE_FILTER_IGNORE)


# --- Title -----------------------------------------------------------------


func show_title() -> void:
	var title := TitleScreen.new()
	var saved: Dictionary = save.load_data()
	title.has_save = not saved.is_empty() and saved.get("phase") != "done"
	title.notice = save.last_error()
	title.continue_requested.connect(_continue)
	title.new_requested.connect(_new_season)
	title.quit_requested.connect(func() -> void: get_tree().quit())
	_show(title)


func _new_season() -> void:
	# The only place a seed is chosen; the rules never read the clock.
	game.new_game(hash([Balance.integer("campaign.seed"), Time.get_ticks_usec(), Time.get_unix_time_from_system()]))
	_save_now()
	show_intake()


func _continue() -> void:
	var saved: Dictionary = save.load_data()
	if saved.is_empty():
		_new_season()
		return
	game.restore(saved)
	if game.phase == "intake":
		show_intake()
	else:
		show_planner()


func _save_now() -> bool:
	if save.save(game.to_dict()):
		return true
	_notice = "Could not save: " + save.last_error()
	return false


# --- Intake ----------------------------------------------------------------


func show_intake() -> void:
	if game.intake_done >= game.clients.size():
		game.phase = "planner"
		_arrived = WeekRules.begin_week(game)
		_save_now()
		show_planner()
		return
	var state: RefCounted = game.clients[game.intake_done]
	var intake := IntakeScreen.new()
	intake.setup(game, state, game.intake_done)
	intake.accepted.connect(func() -> void: show_routine(state, true))
	_show(intake, show_title)


# --- Routines and planner -------------------------------------------------


func show_routine(state: RefCounted, first: bool) -> void:
	var editor := RoutineScreen.new()
	editor.setup(game, state, first)
	editor.confirmed.connect(func(routine: Array) -> void: _routine_confirmed(state, routine, first))
	_show(editor, Callable() if first else show_planner)


func _routine_confirmed(state: RefCounted, routine: Array, first: bool) -> void:
	state.routine = routine
	state.routine_block = game.block().id
	if first:
		game.intake_done += 1
		_save_now()
		show_intake()
	else:
		_save_now()
		show_planner()


func show_planner() -> void:
	var planner := PlannerScreen.new()
	planner.setup(game, _arrived, _notice)
	_notice = ""
	planner.edit_routine.connect(func(state: RefCounted) -> void: show_routine(state, false))
	planner.open_shop.connect(show_shop)
	planner.book.connect(func(state: RefCounted, day: String) -> void:
		WeekRules.book(game, state, day)
		show_planner())
	planner.start_week.connect(_start_week)
	planner.quit_to_title.connect(show_title)
	_show(planner, show_title)


func show_shop() -> void:
	var shop := ShopScreen.new()
	shop.setup(game)
	shop.buy.connect(_buy)
	shop.closed.connect(show_planner)
	_show(shop, show_planner)


func _buy(id: String) -> void:
	if not ShopRules.buy(game, id):
		return
	if not _save_now():
		# A purchase that cannot be saved is not made.
		ShopRules.refund(game, id)
	show_shop()


# --- The week ----------------------------------------------------------------


func _start_week() -> void:
	_save_now()
	_week_sessions = WeekRules.sessions(game)
	_week_index = 0
	_next_session()


func _next_session() -> void:
	if _week_index >= _week_sessions.size():
		_end_week()
		return
	var state: RefCounted = _week_sessions[_week_index]
	_week_index += 1
	var sim := SessionSim.new(game, state, state.booked_day)
	var screen := SessionScreen.new()
	screen.setup(game, sim)
	screen.finished.connect(func() -> void: _session_finished(sim))
	fade_through(func() -> void: _show(screen), 0.2)


func _session_finished(sim: SessionSim) -> void:
	var report: Dictionary = SessionReport.apply(sim)
	var wrapup := WrapupScreen.new()
	wrapup.setup(game, report)
	wrapup.continued.connect(_next_session)
	_show(wrapup)


func _end_week() -> void:
	var summary: Dictionary = WeekRules.end_week(game)
	var screen := WeekScreen.new()
	screen.setup(game, summary)
	screen.continued.connect(func() -> void: _after_week(summary))
	var hold: float = 1.0 if not summary.milestone.is_empty() else 0.3
	fade_through(func() -> void: _show(screen), hold)


func _after_week(summary: Dictionary) -> void:
	if not summary.marathon.is_empty():
		_save_now()
		_show_race(summary.marathon, 0)
		return
	_arrived = WeekRules.begin_week(game)
	_save_now()
	show_planner()


# --- Race day ---------------------------------------------------------------


func _show_race(results: Array, index: int) -> void:
	if index >= results.size():
		var finale := FinaleScreen.new()
		finale.setup(game, results)
		finale.new_requested.connect(_new_season)
		finale.title_requested.connect(show_title)
		fade_through(func() -> void: _show(finale))
		return
	var race := RaceScreen.new()
	race.setup(game, results[index])
	race.continued.connect(func() -> void: _show_race(results, index + 1))
	fade_through(func() -> void: _show(race), 1.4)


func can_quit() -> bool:
	return Display.can_quit()
