extends Control
## A coached session. The gym view shows the client working; their face,
## signal and body language sit beside it; the sliding bar runs underneath.
## Each exercise opens with a card saying what it is for and how to coach
## it, then its beats play out. Space, a left click or gamepad A stops the
## marker (and starts or skips a card).
const Style = preload("res://scripts/ui/style.gd")
const GameSettings = preload("res://scripts/ui/game_settings.gd")
const GymView = preload("res://scripts/ui/gym_view.gd")
const Portrait = preload("res://scripts/ui/portrait.gd")
const SlideBar = preload("res://scripts/ui/slide_bar.gd")
const BodyLanguage = preload("res://scripts/ui/body_language.gd")

signal finished

## Seconds an outcome stays up before the next beat (peaks read longer).
const RESULT_SECONDS: float = 1.1
const PEAK_RESULT_SECONDS: float = 2.2
## How much larger people are drawn at the check-in, where their body
## language is the thing to read; and where the client walks in from and to.
const CHECK_IN_SCALE: float = 1.3
const DOOR_X: float = 0.93
const CHECK_IN_X: float = 0.56
const POSES: Dictionary = {
	"goblet_squat": "squat", "barbell_squat": "back_squat", "lunges": "lunge", "step_ups": "step",
	"skipping": "skip", "core_circuit": "plank", "foam_rolling": "roll", "rowing": "row",
}
const MINIGAME_NAMES: Dictionary = {
	"pace": "Pace coaching", "technique": "Technique observation", "encouragement": "Encouragement", "effort": "Effort management",
}
const MINIGAME_HOWTO: Dictionary = {
	"pace": "The bar is an effort scale from Easy to Hard. Stop the marker in the green zone: the effort they should hold right now.",
	"technique": "Watch the rep. When the form fault flashes up on the bar, stop the marker inside it, then choose the cue that fixes it.",
	"encouragement": "Each zone is a way of encouraging them. Their personality says what usually works, but read the cue line first: someone exhausted, frustrated or flying may need something else.",
	"effort": "Every repeat is a call: Stop, Ease off or Continue. Read their signal colour, face and body language first. Stop ends the repeats there and lets them recover: right on red, wasted on green.",
}

var game: RefCounted
var sim: RefCounted
## "intro", "running", "result" or "done".
var state: String = "intro"
var _view: GymView
var _portrait: Portrait
var _bar: SlideBar
var _title: Label
var _progress: Label
var _instruction: Label
var _cue: Label
var _signal_name: Label
var _energy: ProgressBar
var _energy_value: Label
var _feedback: VBoxContainer
var _card: Control
var _card_text: VBoxContainer
var _peak_banner: Label
var _shown_index: int = -2
var _wait: float = 0.0
var _bands: Array = []
## How the client carries themselves today (body_language.gd stance ids).
var _stance: Array = []


func setup(owner: RefCounted, session: RefCounted) -> void:
	game = owner
	sim = session


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	for i in range(game.catalog.efforts.size()):
		var band: Dictionary = (game.catalog.efforts[i] as Dictionary).duplicate()
		band["index"] = i
		_bands.append(band)
	var column: VBoxContainer = Style.screen(self, 8, 18)
	column.add_child(_top_row())
	var middle: HBoxContainer = Style.ui.hbox(12)
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(middle)
	_view = GymView.new()
	_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_view.owned = game.owned
	_view.rain = game.bad_weather()
	_view.look = sim.client.def.look
	middle.add_child(_view)
	middle.add_child(_side_panel())
	_instruction = Style.ui.wrapped("", 16, Style.PAPER)
	column.add_child(_instruction)
	_bar = SlideBar.new()
	_bar.stopped.connect(_on_stopped)
	column.add_child(_bar)
	_feedback = Style.ui.vbox(2)
	_feedback.custom_minimum_size.y = 64
	column.add_child(_feedback)
	_build_card()
	_peak_banner = Style.ui.heading("PEAK MOMENT", 40, Style.PUSH)
	_peak_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_peak_banner.position.y = 90
	_peak_banner.hide()
	add_child(_peak_banner)
	_show_current()


func _top_row() -> HBoxContainer:
	var row: HBoxContainer = Style.ui.hbox(16)
	row.add_child(Style.ui.heading("%s · %s" % [sim.client.def.short, sim.day], 26))
	_title = Style.ui.label("", 20, Style.PAPER)
	row.add_child(_title)
	row.add_child(Style.ui.spacer())
	var block: Dictionary = game.block()
	var rule: String = "push at amber" if block.push_on_amber else "hold back at amber"
	row.add_child(Style.ui.label("%s block: %s" % [block.name, rule], 15, Style.ACCENT))
	_progress = Style.ui.utility("", 15, Style.MUTED)
	row.add_child(_progress)
	return row


func _side_panel() -> PanelContainer:
	var panel: PanelContainer = Style.ui.panel(0.9, 10)
	panel.custom_minimum_size.x = 290
	var column: VBoxContainer = Style.ui.vbox(6)
	panel.add_child(column)
	_portrait = Portrait.new()
	_portrait.look = sim.client.def.look
	_portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_portrait)
	_signal_name = Style.ui.label("", 20)
	_signal_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_signal_name)
	var heart: bool = game.has_effect("show_energy")
	var energy_row: HBoxContainer = Style.ui.hbox(6)
	energy_row.add_child(Style.ui.label("Energy", 14, Style.MUTED))
	_energy = Style.ui.meter(100, 100, 150)
	energy_row.add_child(_energy)
	_energy_value = Style.ui.utility("", 14)
	energy_row.add_child(_energy_value)
	energy_row.visible = heart
	column.add_child(energy_row)
	if not heart:
		column.add_child(Style.ui.wrapped("A heart-rate monitor would show their exact energy.", 12))
	_cue = Style.ui.wrapped("", 15, Style.PAPER)
	column.add_child(_cue)
	return panel


## The exercise card: a shaded layer with a fixed-width panel in its centre,
## so wrapped text has a real width to wrap to.
func _build_card() -> void:
	_card = Control.new()
	_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card)
	var shade: ColorRect = Style.ui.shade(0.55)
	shade.gui_input.connect(_gui_input)
	_card.add_child(shade)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(centre)
	var panel: PanelContainer = Style.ui.panel(0.97, 22)
	panel.custom_minimum_size = Vector2(680, 0)
	centre.add_child(panel)
	_card_text = Style.ui.vbox(12)
	panel.add_child(_card_text)


func _show_card(title: String, lines: Array) -> void:
	for child in _card_text.get_children():
		child.queue_free()
	_card_text.add_child(Style.ui.heading(title, 26))
	for line in lines:
		var text: Label = Style.ui.wrapped(line, 16, Style.PAPER)
		text.custom_minimum_size.x = 636
		_card_text.add_child(text)
	var begin: Button = Style.ui.button("Begin  (%s)" % GameSettings.coach_key(), _begin, true)
	begin.size_flags_horizontal = Control.SIZE_SHRINK_END
	_card_text.add_child(begin)
	_card.show()
	begin.grab_focus.call_deferred()
	state = "intro"


## Shows the card for a new exercise, or starts the next beat of this one.
func _show_current() -> void:
	var beat: Dictionary = sim.prompt()
	if beat.kind == "done":
		state = "done"
		finished.emit()
		return
	_refresh_client()
	if sim.index != _shown_index:
		_shown_index = sim.index
		_set_activity()
		if beat.kind == "check_in":
			_show_card("Check-in", ["%s arrives for their session." % sim.client.def.short, "Read how they walk in, then ask the question that fits. The right question tells you how they really are, so you can adapt the session."])
		else:
			var rec: Dictionary = sim.record()
			_show_card("%d/%d  %s  ·  %s" % [beat.exercise, beat.exercises, rec.def.name, MINIGAME_NAMES[rec.def.minigame]], [rec.def.why, MINIGAME_HOWTO[rec.def.minigame], "Peak moments: push (orange, right) or hold back (blue, left). Green: push. Red: hold back. Amber: it depends on the block."])
		return
	_run_beat(beat)


func _begin() -> void:
	if state != "intro":
		return
	_card.hide()
	var beat: Dictionary = sim.prompt()
	if beat.kind == "check_in":
		_view.walk(DOOR_X, CHECK_IN_X, BodyLanguage.walk_seconds(_stance))
	_run_beat(beat)


func _run_beat(beat: Dictionary) -> void:
	get_viewport().gui_release_focus()
	_title.text = beat.get("title", "")
	_progress.text = "" if beat.kind == "check_in" else "press %d/%d" % [int(beat.press), int(beat.presses)]
	_instruction.text = beat.instruction
	if beat.kind == "check_in":
		_cue.text = beat.cue
	elif beat.has("cue"):
		_cue.text = beat.cue
	_peak_banner.visible = beat.kind == "peak"
	_bar.start(beat, _bands)
	state = "running"


func _on_stopped(position: float, visible: bool) -> void:
	if state != "running":
		return
	var kind: String = sim.prompt().kind
	var outcome: Dictionary = sim.press(position, visible)
	if kind == "check_in":
		_view.react(BodyLanguage.reaction(String(sim.check_in.question), _stance))
	_bar.flash(Style.tone_color(outcome.tone))
	_add_feedback(outcome)
	_refresh_client()
	_wait = PEAK_RESULT_SECONDS if kind == "peak" or kind == "check_in" else RESULT_SECONDS
	state = "result"


func _add_feedback(outcome: Dictionary) -> void:
	while _feedback.get_child_count() >= 3:
		var oldest: Node = _feedback.get_child(0)
		_feedback.remove_child(oldest)
		oldest.queue_free()
	for child in _feedback.get_children():
		(child as Label).modulate.a = 0.55
	_feedback.add_child(Style.ui.wrapped("%s %s" % [Style.tone_mark(outcome.tone), outcome.text], 16, Style.tone_color(outcome.tone)))


func _refresh_client() -> void:
	var colour: String = sim.current_signal()
	_portrait.set_signal(colour)
	_signal_name.text = game.catalog.lines.signals[colour].name
	_signal_name.add_theme_color_override("font_color", Style.signal_color(colour))
	_energy.value = sim.energy
	_energy.add_theme_stylebox_override("fill", Style.ui.box(Style.signal_color(colour), Color(0, 0, 0, 0), 4, 0))
	_energy_value.text = "%d  ·  %d bpm" % [int(round(sim.energy)), int(round(70.0 + (100.0 - sim.energy) * 1.1))]
	_view.expression = {"green": "smile", "amber": "focus", "red": "grimace"}[colour]


func _set_activity() -> void:
	var rec: Dictionary = sim.record()
	if rec.is_empty():
		# The check-in: the client waits at the door, larger than usual, and
		# shows how they are before a word is said.
		_stance = BodyLanguage.stance(String(sim.condition.id), sim.client.fatigue, sim.client.injured_weeks > 0)
		_view.figure_scale = CHECK_IN_SCALE
		_view.client_x = DOOR_X
		_view.facing = -1.0
		_view.set_body_language(_stance, BodyLanguage.idle_gestures(_stance))
		_view.set_activity("shed", "stand", 0.0)
		return
	_view.figure_scale = 1.0
	_view.facing = 1.0
	_view.set_body_language([], [])
	var def: Dictionary = rec.def
	if def.kind == "run":
		var indoors: bool = game.bad_weather() and game.has_effect("weatherproof_runs")
		var place: String = "shed" if indoors else ("track" if def.minigame == "effort" and game.has_effect("full_intervals") else "road")
		_view.client_x = 0.68 if indoors else 0.5
		_view.set_activity(place, "run", 0.9 + float(def.effort) * 0.9)
		return
	_view.client_x = 0.68 if def.id == "rowing" else 0.5
	_view.set_activity("shed", POSES.get(def.id, "stand"), 0.5 if def.kind == "strength" else 0.8)


## The client shows the form fault while it is up on the bar and until a
## cue fixes it.
func _update_fault() -> void:
	var beat: Dictionary = sim.prompt()
	var shown: Dictionary = {}
	if beat.kind == "cue" or (beat.kind == "spot" and state == "running" and _bar.zones_visible()):
		shown = beat.fault
	_view.show_fault(String(shown.get("show", "")))


func _process(delta: float) -> void:
	if state != "done":
		_update_fault()
	if state == "result":
		_wait -= delta
		if _wait <= 0.0:
			_show_current()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("coach"):
		_press()
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_press()
		accept_event()


func _press() -> void:
	match state:
		"running":
			_bar.stop()
		"intro":
			_begin()
		"result":
			_wait = 0.0
