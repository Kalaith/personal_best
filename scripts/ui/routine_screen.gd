extends Control
## Routine creation: up to four entries of exercise, sets and weight (Load
## for running). The suggested routine is a starting point; every entry
## carries the advisor's notes, and the preview shows what one good session
## would build, so the player sees why a choice helps before confirming it.
const Style = preload("res://scripts/ui/style.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
const RoutineRules = preload("res://scripts/core/routine_rules.gd")
const Catalog = preload("res://scripts/core/catalog.gd")

signal confirmed(routine: Array)

## Performance assumed by the preview ("a good session").
const PREVIEW_PERFORMANCE: float = 0.8

var game: RefCounted
var client: RefCounted
var first: bool = false
var entries: Array = []
var _body: HBoxContainer


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
	column.add_child(Style.ui.heading("%s's routine · %s block (weeks %d–%d)" % [client.def.short, block.name, int(block.first_week), int(block.last_week)], 28))
	column.add_child(Style.ui.wrapped(game.catalog.lines.blocks[block.id], 15, Style.PAPER))
	if client.routine_block != block.id and not client.routine.is_empty():
		column.add_child(Style.ui.wrapped("A new block has started. The advisor has drafted a routine for it; keep it, tweak it, or rebuild it.", 14, Style.AMBER))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_body = Style.ui.hbox(16)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_body)
	var buttons: HBoxContainer = Style.ui.hbox(12)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(buttons)
	buttons.add_child(Style.ui.button("Use suggested routine", _use_suggested))
	var confirm: Button = Style.ui.button("Confirm routine", _confirm, true)
	buttons.add_child(confirm)
	_rebuild()
	confirm.grab_focus.call_deferred()


func _use_suggested() -> void:
	entries = RoutineRules.suggested(client, game.block().id, game)
	_rebuild()


func _confirm() -> void:
	if not entries.is_empty():
		confirmed.emit(entries.duplicate(true))


func _rebuild() -> void:
	for child in _body.get_children():
		child.queue_free()
	var left: VBoxContainer = Style.ui.vbox(10)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.6
	_body.add_child(left)
	for i in range(entries.size()):
		left.add_child(_entry_row(i))
	if entries.size() < RoutineRules.MAX_ENTRIES:
		left.add_child(_add_row())
	_body.add_child(_preview())


func _entry_row(index: int) -> PanelContainer:
	var entry: Dictionary = entries[index]
	var def: Dictionary = game.catalog.exercise(entry.exercise)
	var panel: PanelContainer = Style.ui.panel(0.95, 10)
	var column: VBoxContainer = Style.ui.vbox(4)
	panel.add_child(column)
	var row: HBoxContainer = Style.ui.hbox(8)
	column.add_child(row)
	row.add_child(_exercise_picker(index))
	var sets_label: String = "Repeats" if def.minigame == "effort" else "Sets"
	var change_sets := func(step: int) -> void:
		entry.sets = clampi(int(entry.sets) + step, int(def.sets.min), int(def.sets.max))
		_rebuild()
	row.add_child(_stepper(sets_label, str(entry.sets), change_sets, int(entry.sets) > int(def.sets.min), int(entry.sets) < int(def.sets.max)))
	if def.load_kind == "kg":
		var change_kg := func(step: int) -> void:
			entry.kg = clampi(int(entry.kg) + step * int(def.kg.step), int(def.kg.min), int(def.kg.max))
			_rebuild()
		row.add_child(_stepper("Weight", "%d kg" % int(entry.kg), change_kg, int(entry.kg) > int(def.kg.min), int(entry.kg) < int(def.kg.max)))
	else:
		row.add_child(_load_picker(entry, def))
	var remove: Button = Style.ui.button("✕", func() -> void:
		entries.remove_at(index)
		_rebuild())
	remove.tooltip_text = "Remove from the routine"
	row.add_child(remove)
	var tier: String = RoutineRules.tier(entry, client, def)
	column.add_child(Style.ui.wrapped("%s  ·  %s intensity  ·  %s" % [def.why, tier.capitalize(), _minigame_name(def.minigame)], 13))
	var assessed: Dictionary = RoutineRules.assess(entry, client, game)
	var notes: Array = assessed.notes + RoutineRules.conditions(entry, game).notes
	if assessed.unsuitable:
		notes.push_front({"tone": "bad", "text": "Unsuitable: this entry gives half value."})
	column.add_child(Widgets.notes(notes, 13))
	return panel


func _minigame_name(id: String) -> String:
	return {"pace": "Pace coaching", "technique": "Technique observation", "encouragement": "Encouragement", "effort": "Effort management"}.get(id, id)


func _exercise_picker(index: int) -> OptionButton:
	var picker := OptionButton.new()
	picker.custom_minimum_size = Vector2(215, 40)
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


func _load_picker(entry: Dictionary, def: Dictionary) -> HBoxContainer:
	var row: HBoxContainer = Style.ui.hbox(4)
	row.add_child(Style.ui.label("Load" if def.kind == "run" else "Level", 14, Style.MUTED))
	for load_id in Catalog.LOADS:
		var choose := func() -> void:
			entry.load = load_id
			_rebuild()
		var button: Button = Style.ui.button(load_id.capitalize(), choose, entry.load == load_id, 14)
		button.custom_minimum_size = Vector2(66, 38)
		row.add_child(button)
	return row


func _stepper(label: String, value: String, change: Callable, can_down: bool, can_up: bool) -> HBoxContainer:
	var row: HBoxContainer = Style.ui.hbox(4)
	row.add_child(Style.ui.label(label, 14, Style.MUTED))
	var down: Button = Style.ui.button("−", func() -> void: change.call(-1), false, 16)
	down.disabled = not can_down
	down.custom_minimum_size = Vector2(36, 38)
	row.add_child(down)
	var shown: Label = Style.ui.utility(value, 16)
	shown.custom_minimum_size.x = 48
	shown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(shown)
	var up: Button = Style.ui.button("+", func() -> void: change.call(1), false, 16)
	up.disabled = not can_up
	up.custom_minimum_size = Vector2(36, 38)
	row.add_child(up)
	return row


func _add_row() -> Button:
	var button: Button = Style.ui.button("+ Add an exercise", func() -> void:
		for id in RoutineRules.available_exercises(game):
			if not entries.any(func(e: Dictionary) -> bool: return e.exercise == id):
				entries.append(RoutineRules.default_entry(id, client, game.catalog))
				break
		_rebuild())
	return button


## What one good coached session of this routine would build, and its cost.
func _preview() -> PanelContainer:
	var parts: Array = Widgets.card("One good session")
	var panel: PanelContainer = parts[0]
	panel.custom_minimum_size.x = 300
	var column: VBoxContainer = parts[1]
	var totals: Dictionary = {}
	for entry in entries:
		var gains: Dictionary = RoutineRules.gains(entry, client, game)
		for key in gains:
			totals[key] = float(totals.get(key, 0.0)) + float(gains[key]) * PREVIEW_PERFORMANCE
	column.add_child(Style.ui.wrapped("Expected gains at 80% performance, before peak-moment bonuses:", 13))
	for attribute in Catalog.ATTRIBUTES:
		var gain: float = float(totals.get(attribute, 0.0))
		var row: HBoxContainer = Style.ui.hbox(8)
		var name: Label = Style.ui.label(game.catalog.attribute_name(attribute), 15)
		name.custom_minimum_size.x = 140
		row.add_child(name)
		row.add_child(Style.ui.utility("+%.1f" % gain if gain >= 0.05 else "—", 15, Style.GREEN if gain >= 0.05 else Style.MUTED))
		row.add_child(Style.ui.utility("(%d / %d)" % [int(round(float(client.attributes[attribute]))), int(client.def.requirements[attribute])], 13, Style.MUTED))
		column.add_child(row)
	var fatigue: float = RoutineRules.routine_fatigue(entries, client, game.catalog)
	column.add_child(Style.ui.utility("Fatigue per session: %+d" % int(round(fatigue)), 15, Style.AMBER if fatigue >= 45.0 else Style.PAPER))
	column.add_child(Style.ui.wrapped("%s also trains alone %d times a week from this routine at half value." % [client.def.short, int(client.def.own_sessions_per_week)], 13))
	var notes: Array = RoutineRules.routine_notes(entries, client, game)
	if entries.is_empty():
		notes.append({"tone": "bad", "text": "An empty routine can't be coached."})
	column.add_child(Widgets.notes(notes, 14))
	return panel
