extends Control
## The title: the shed at dusk, the game's promise in one line, and the way
## in. Explains coaching in a few lines so the first session is not a mystery.
const Style = preload("res://scripts/ui/style.gd")
const GymView = preload("res://scripts/ui/gym_view.gd")
const Display = preload("res://addons/hatchery/settings/display.gd")

signal continue_requested
signal new_requested
signal quit_requested

var has_save: bool = false
var notice: String = ""
var _confirm: HBoxContainer


func _ready() -> void:
	var column: VBoxContainer = Style.screen(self, 14, 40)
	var view := GymView.new()
	view.custom_minimum_size = Vector2(0, 300)
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.owned = ["dumbbells", "skipping_ropes", "floor_mats", "step_box"]
	view.look = {"skin": "f0c8a8", "hair": "c9c4c0", "hair_style": "bob", "top": "c0567a", "shorts": "3d3346", "build": 1.35, "height": 0.95}
	view.client_x = 0.5
	view.set_activity("shed", "squat", 0.45)
	column.add_child(view)
	var heading: Label = Style.ui.heading("Personal Best", 54)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)
	var tagline: Label = Style.ui.wrapped("You train people out of a backyard shed. Two of them want to run the same marathon in twelve weeks. They could hardly be more different.", 19, Style.PAPER)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(tagline)
	var how: Label = Style.ui.wrapped("Plan each client's routine, then coach them through sessions with one sliding bar: press Space, click or A to stop the marker in the right zone. At peak moments, read their face and signal colour, then push or hold back. Pushing harder is not always right.", 15)
	how.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(how)
	var buttons: HBoxContainer = Style.ui.hbox(16)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(buttons)
	if has_save:
		buttons.add_child(Style.ui.button("Continue season", func() -> void: continue_requested.emit(), true))
	buttons.add_child(Style.ui.button("New season", _ask_new, not has_save))
	var quit: Button = Style.ui.button("Quit", func() -> void: quit_requested.emit())
	quit.disabled = not Display.can_quit()
	buttons.add_child(quit)
	_confirm = Style.ui.hbox(12)
	_confirm.alignment = BoxContainer.ALIGNMENT_CENTER
	_confirm.add_child(Style.ui.label("Start over? The current season will be replaced.", 16, Style.AMBER))
	_confirm.add_child(Style.ui.button("Start over", func() -> void: new_requested.emit(), true))
	_confirm.add_child(Style.ui.button("Keep it", func() -> void: _confirm.hide()))
	_confirm.hide()
	column.add_child(_confirm)
	if not notice.is_empty():
		column.add_child(Style.ui.wrapped(notice, 14, Style.AMBER))
	var note: Label = Style.ui.wrapped("Exercise effects are simplified game values. This is not medical or training advice.", 13)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(note)


func _ask_new() -> void:
	if has_save:
		_confirm.show()
	else:
		new_requested.emit()
