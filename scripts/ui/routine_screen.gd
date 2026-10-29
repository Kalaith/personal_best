extends Control
## Routine creation: up to four entries of exercise, sets and weight (Load
## for running). The suggested routine is a starting point; every entry
## carries the advisor's notes, and the preview shows what one good session
## would build, so the player sees why a choice helps before confirming it.
const Style = preload("res://scripts/ui/style.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
const RoutineRules = preload("res://scripts/core/routine_rules.gd")
const Catalog = preload("res://scripts/core/catalog.gd")
const Charts = preload("res://scripts/ui/charts.gd")
const Readiness = preload("res://scripts/core/readiness.gd")
const Balance = preload("res://addons/hatchery/core/balance.gd")

signal confirmed(routine: Array)

## Performance assumed by the preview ("a good session").
const PREVIEW_PERFORMANCE: float = 0.8

var game: RefCounted
var client: RefCounted
var first: bool = false
var entries: Array = []
var _body: HBoxContainer
var _confirm_button: Button
var _count: Label


func setup(owner: RefCounted, state: RefCounted, is_first: bool) -> void:
	game = owner
	client = state
	first = is_first
	var block: String = game.block().id
	if state.routine.is_empty() or state.routine_block != block:
		entries = RoutineRules.suggested(state, block, game)
	else:
		entries = state.routine.duplicate(true)


func _ready() -> void:
	var column: VBoxContainer = Style.screen(self, 10, 24)
	var block: Dictionary = game.block()
	var header: HBoxContainer = Style.ui.hbox(16)
	header.add_child(Style.ui.heading("%s's routine" % client.def.short, 30))
	header.add_child(Style.ui.label("%s block" % block.name, 16, Style.MUTED))
	column.add_child(header)
	var plan: HBoxContainer = Style.ui.hbox(24)
	column.add_child(plan)
	var strip: Control = Widgets.season_strip(game, 400.0, client)
	plan.add_child(strip)
	plan.add_child(Charts.signal_rule(bool(block.push_on_amber)))
	if client.routine_block != block.id and not client.routine.is_empty():
		column.add_child(Style.ui.wrapped("New block: routine redrafted.", 14, Style.AMBER))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_body = Style.ui.hbox(16)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_body)
	var buttons: HBoxContainer = Style.ui.hbox(12)
	column.add_child(buttons)
	_count = Style.ui.label("", 14, Style.MUTED)
	buttons.add_child(_count)
	buttons.add_child(Style.ui.spacer())
	buttons.add_child(Style.ui.button("Use suggested routine", _use_suggested))
	_confirm_button = Style.ui.button("Confirm routine", _confirm, true)
	buttons.add_child(_confirm_button)
	_rebuild()
	_confirm_button.grab_focus.call_deferred()


func _use_suggested() -> void:
	entries = RoutineRules.suggested(client, game.block().id, game)
	_rebuild()


func _confirm() -> void:
	if not entries.is_empty():
		confirmed.emit(entries.duplicate(true))


func _rebuild() -> void:
	var focused: Control = get_viewport().gui_get_focus_owner()
	var focus_key: String = String(focused.get_meta("routine_focus", "")) if focused != null else ""
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_confirm_button.disabled = entries.is_empty()
	_confirm_button.tooltip_text = "Add an exercise before confirming." if entries.is_empty() else "Use this routine for coached and solo training."
	_count.text = "%d / %d exercises" % [entries.size(), RoutineRules.MAX_ENTRIES]
	var left: VBoxContainer = Style.ui.vbox(8)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.6
	_body.add_child(left)
	left.add_child(Widgets.section_label("Training routine"))
	if entries.is_empty():
		left.add_child(Style.ui.wrapped("Add an exercise or use the suggested routine.", 16, Style.MUTED))
	for i in range(entries.size()):
		left.add_child(_entry_row(i))
	if entries.size() < RoutineRules.MAX_ENTRIES:
		left.add_child(_add_row())
	_body.add_child(_preview())
	if not focus_key.is_empty():
		_restore_focus.call_deferred(focus_key)


## Rebuilding the preview must not strand keyboard users after every edit.
func _restore_focus(key: String) -> void:
	await get_tree().process_frame
	if not is_inside_tree():
		return
	for control in _body.find_children("*", "Control", true, false):
		if String(control.get_meta("routine_focus", "")) == key:
			if control is BaseButton and control.disabled:
				continue
			control.grab_focus()
			var card: Node = control.get_parent()
			while card != _body and not card is PanelContainer:
				card = card.get_parent()
			if card is PanelContainer:
				(_body.get_parent() as ScrollContainer).ensure_control_visible(card as Control)
			return
	var pickers: Array[Node] = _body.find_children("*", "OptionButton", true, false)
	if not pickers.is_empty():
		(pickers[0] as Control).grab_focus()
	else:
		var buttons: Array[Node] = _body.find_children("*", "Button", true, false)
		if not buttons.is_empty():
			(buttons[0] as Control).grab_focus()


func _field(title: String, control: Control, width: float = 0.0) -> VBoxContainer:
	var column: VBoxContainer = Style.ui.vbox(4)
	column.custom_minimum_size.x = width
	column.add_child(Style.ui.label(title, 13, Style.MUTED))
	column.add_child(control)
	return column


func _entry_row(index: int) -> PanelContainer:
	var entry: Dictionary = entries[index]
	var def: Dictionary = game.catalog.exercise(entry.exercise)
	var panel: PanelContainer = Style.ui.panel(0.95, 8)
	var column: VBoxContainer = Style.ui.vbox(4)
	panel.add_child(column)
	var row: HBoxContainer = Style.ui.hbox(8)
	column.add_child(row)
	var picker: OptionButton = _exercise_picker(index)
	picker.tooltip_text = "%s  (%s)" % [def.why, _minigame_name(def.minigame)]
	var exercise_field: VBoxContainer = _field("Exercise %d" % (index + 1), picker)
	exercise_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(exercise_field)
	var change_sets := func(step: int) -> void:
		entry.sets = clampi(int(entry.sets) + step, int(def.sets.min), int(def.sets.max))
		_rebuild()
	row.add_child(_field("Sets", _stepper("%d" % int(entry.sets), change_sets, int(entry.sets) > int(def.sets.min), int(entry.sets) < int(def.sets.max), "%d_sets" % index)))
	if def.load_kind == "kg":
		var change_kg := func(step: int) -> void:
			entry.kg = clampi(int(entry.kg) + step * int(def.kg.step), int(def.kg.min), int(def.kg.max))
			_rebuild()
		row.add_child(_field("Weight", _stepper("%d kg" % int(entry.kg), change_kg, int(entry.kg) > int(def.kg.min), int(entry.kg) < int(def.kg.max), "%d_weight" % index), 280))
	else:
		row.add_child(_field("Effort", _load_picker(entry, index), 280))
	var remove: Button = Style.ui.button("✕", func() -> void:
		entries.remove_at(index)
		_rebuild())
	remove.tooltip_text = "Remove %s from the routine" % def.name
	remove.set_meta("routine_focus", "%d_remove" % index)
	remove.custom_minimum_size = Vector2(50, 50)
	remove.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(remove)
	var assessed: Dictionary = RoutineRules.assess(entry, client, game)
	var notes: Array = assessed.notes + RoutineRules.conditions(entry, game).notes
	column.add_child(_built_chips(entry, assessed, notes))
	var problems: Array = notes.filter(func(note: Dictionary) -> bool: return note.tone == "bad" or note.tone == "warn")
	if not problems.is_empty():
		column.add_child(Widgets.notes(problems, 13))
	return panel


## What this entry builds, as attribute chips: green for a weak area (it
## pays extra), dim for one already met (it does little). The advisor's
## notes sit in the tooltip.
func _built_chips(entry: Dictionary, assessed: Dictionary, notes: Array) -> HFlowContainer:
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 8)
	var tip: PackedStringArray = []
	for note in notes:
		tip.append("%s %s" % [Style.tone_mark(note.tone), note.text])
	chips.tooltip_text = "\n".join(tip)
	var gains: Dictionary = RoutineRules.gains(entry, client, game)
	var order: Array = gains.keys().filter(func(key: String) -> bool: return float(gains[key]) >= 0.05)
	order.sort_custom(func(a: String, b: String) -> bool: return float(gains[a]) > float(gains[b]))
	for key in order.slice(0, 3):
		var share: float = Readiness.ratio(client, key)
		var colour: Color = Style.ACCENT
		if share < Balance.number("progress.weakness_ratio"):
			colour = Style.GREEN
		elif share >= Balance.number("progress.met_ratio"):
			colour = Style.MUTED
		chips.add_child(Charts.chip(game.catalog.attribute_name(key), colour))
	if assessed.unsuitable:
		chips.add_child(Charts.chip("½ value", Style.RED))
	return chips


func _minigame_name(id: String) -> String:
	return {"pace": "Pace coaching", "technique": "Technique observation", "encouragement": "Encouragement", "effort": "Effort management"}.get(id, id)


func _exercise_picker(index: int) -> OptionButton:
	var picker := OptionButton.new()
	picker.set_meta("routine_focus", "%d_exercise" % index)
	picker.custom_minimum_size = Vector2(215, 50)
	picker.fit_to_longest_item = false
	picker.clip_text = true
	var available: Array = RoutineRules.available_exercises(game)
	var ids: Array = []
	for id in game.catalog.exercise_order:
		var def: Dictionary = game.catalog.exercise(id)
		var used: bool = entries.any(func(e: Dictionary) -> bool: return e.exercise == id) and entries[index].exercise != id
		var label: String = def.name
		if not available.has(id):
			var missing: Array = (def.requires as Array).filter(func(need: String) -> bool: return not game.owns(need))
			label += "  (needs %s)" % game.catalog.equipment_name(missing[0])
		elif used:
			label += "  (in routine)"
		picker.add_item(label)
		picker.set_item_disabled(picker.item_count - 1, not available.has(id) or used)
		ids.append(id)
	picker.select(ids.find(entries[index].exercise))
	picker.item_selected.connect(func(item: int) -> void:
		entries[index] = RoutineRules.default_entry(ids[item], client, game.catalog)
		_rebuild())
	return picker


func _load_picker(entry: Dictionary, index: int) -> HBoxContainer:
	var row: HBoxContainer = Style.ui.hbox(4)
	for load_id in Catalog.LOADS:
		var choose := func() -> void:
			entry.load = load_id
			_rebuild()
		var selected: bool = entry.load == load_id
		var button: Button = Style.ui.button(("✓ " if selected else "") + load_id.capitalize(), choose, selected, 14)
		button.set_meta("routine_focus", "%d_load_%s" % [index, load_id])
		button.tooltip_text = "%s effort%s" % [load_id.capitalize(), " (selected)" if selected else ""]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 50
		row.add_child(button)
	return row


func _stepper(value: String, change: Callable, can_down: bool, can_up: bool, key: String) -> HBoxContainer:
	var row: HBoxContainer = Style.ui.hbox(4)
	var down: Button = Style.ui.button("−", func() -> void: change.call(-1), false, 22)
	down.disabled = not can_down
	down.set_meta("routine_focus", key + "_down")
	down.tooltip_text = "Decrease %s" % key.get_slice("_", 1)
	down.custom_minimum_size = Vector2(50, 50)
	row.add_child(down)
	var shown: Label = Style.ui.utility(value, 16)
	shown.custom_minimum_size.x = 42
	shown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(shown)
	var up: Button = Style.ui.button("+", func() -> void: change.call(1), false, 22)
	up.disabled = not can_up
	up.set_meta("routine_focus", key + "_up")
	up.tooltip_text = "Increase %s" % key.get_slice("_", 1)
	up.custom_minimum_size = Vector2(50, 50)
	row.add_child(up)
	return row


func _add_row() -> Button:
	var button: Button = Style.ui.button("+ Add an exercise", func() -> void:
		for id in RoutineRules.available_exercises(game):
			if not entries.any(func(e: Dictionary) -> bool: return e.exercise == id):
				entries.append(RoutineRules.default_entry(id, client, game.catalog))
				break
		_rebuild())
	button.set_meta("routine_focus", "add")
	return button


## What one good coached session of this routine would build, and its cost,
## as bars: the attribute's value, the gain on top, the goal's need as a notch.
func _preview() -> PanelContainer:
	var parts: Array = Widgets.card("Session preview")
	var panel: PanelContainer = parts[0]
	panel.custom_minimum_size.x = 300
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.tooltip_text = "Expected gains at %d%% performance, before peak-moment bonuses. %s also trains alone %d times a week from this routine at half value." % [int(PREVIEW_PERFORMANCE * 100.0), client.def.short, int(client.def.own_sessions_per_week)]
	var column: VBoxContainer = parts[1]
	column.add_child(Style.ui.label("At %d%% coaching performance" % int(PREVIEW_PERFORMANCE * 100.0), 13, Style.MUTED))
	column.add_child(Widgets.section_label("Attribute gains"))
	var totals: Dictionary = {}
	for entry in entries:
		var gains: Dictionary = RoutineRules.gains(entry, client, game)
		for key in gains:
			totals[key] = float(totals.get(key, 0.0)) + float(gains[key]) * PREVIEW_PERFORMANCE
	var rows: Array = []
	for attribute in Catalog.ATTRIBUTES:
		var value: float = float(client.attributes[attribute])
		var gain: float = float(totals.get(attribute, 0.0))
		rows.append({"label": Charts.short_name(game.catalog, attribute), "before": value, "after": value + gain, "mark": float(client.def.requirements[attribute]), "fine": true, "tip": "%s +%.1f" % [game.catalog.attribute_name(attribute), gain]})
	column.add_child(Charts.change_rows(game.catalog, rows, 270.0))
	var legend: HBoxContainer = Style.ui.hbox(12)
	legend.add_child(Style.ui.label("━ Now", 13, Style.ACCENT))
	legend.add_child(Style.ui.label("━ Gain", 13, Style.GREEN))
	legend.add_child(Style.ui.label("│ Goal", 13, Style.PAPER))
	column.add_child(legend)
	column.add_child(Widgets.section_label("Session fatigue"))
	var fatigue: float = RoutineRules.routine_fatigue(entries, client, game.catalog)
	var tired: Array = [{"icon": "fatigue", "before": 0.0, "after": minf(fatigue, 100.0), "lower_is_better": true, "tip": "Fatigue per session: +%d" % int(round(fatigue))}]
	column.add_child(Charts.change_rows(game.catalog, tired, 270.0))
	var notes: Array = [] if entries.is_empty() else RoutineRules.routine_notes(entries, client, game)
	if entries.is_empty():
		notes.append({"tone": "bad", "text": "An empty routine can't be coached."})
	column.add_child(Widgets.notes(notes, 14))
	return panel
