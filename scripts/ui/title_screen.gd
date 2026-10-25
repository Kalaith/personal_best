extends Control
## The title: the shed at dusk, the game's promise in one line, and the way
## in. Explains coaching in a few lines so the first session is not a mystery.
const Style = preload("res://scripts/ui/style.gd")
const TitleBackdrop = preload("res://scripts/ui/title_backdrop.gd")
const Display = preload("res://addons/hatchery/settings/display.gd")
const GameSettings = preload("res://scripts/ui/game_settings.gd")

signal continue_requested
signal new_requested
signal quit_requested
signal settings_requested

var has_save: bool = false
var notice: String = ""
var _scroll: ScrollContainer
var _confirm: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	TitleBackdrop.mount(self)
	var frame := MarginContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.anchor_right = 0.46
	for side in ["left", "right", "top", "bottom"]:
		frame.add_theme_constant_override("margin_" + side, 28)
	add_child(frame)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(_scroll)
	var column: VBoxContainer = Style.ui.vbox(14)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	_scroll.add_child(column)
	var heading: Label = Style.ui.heading("Personal Best", 54)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)
	var tagline: Label = Style.ui.wrapped("You train people out of a backyard shed. Two of them want to run the same marathon in twelve weeks. They could hardly be more different.", 19, Style.PAPER)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(tagline)
	var how: Label = Style.ui.wrapped("Plan each client's routine, then coach them through sessions with one sliding bar: press %s, click or A to stop the marker in the right zone. At peak moments, read their face and signal colour, then push or hold back. Pushing harder is not always right." % GameSettings.coach_key(), 15)
	how.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(how)
	var buttons: VBoxContainer = Style.ui.vbox(10)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(buttons)
	if has_save:
		buttons.add_child(Style.ui.button("Continue season", func() -> void: continue_requested.emit(), true))
	buttons.add_child(Style.ui.button("New season", _ask_new, not has_save))
	buttons.add_child(Style.ui.button("Settings", func() -> void: settings_requested.emit()))
	var quit: Button = Style.ui.button("Quit", func() -> void: quit_requested.emit())
	quit.disabled = not Display.can_quit()
	buttons.add_child(quit)
	_confirm = Style.ui.vbox(8)
	_confirm.alignment = BoxContainer.ALIGNMENT_CENTER
	_confirm.add_child(Style.ui.wrapped("Start over? The current season will be replaced.", 16, Style.AMBER))
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
		await get_tree().process_frame
		_scroll.ensure_control_visible(_confirm)
	else:
		new_requested.emit()
