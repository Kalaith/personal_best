extends RefCounted
## Small composite widgets several screens share: the attribute table
## (value against what the goal needs), the readiness bar, condition meters
## and advisor notes.
const Style = preload("res://scripts/ui/style.gd")
const Readiness = preload("res://scripts/core/readiness.gd")
const Catalog = preload("res://scripts/core/catalog.gd")
const Charts = preload("res://scripts/ui/charts.gd")
const Balance = preload("res://addons/hatchery/core/balance.gd")


## One row per attribute: name, a bar filled to value with the goal's need
## marked, and "value / need".
static func attribute_table(state: RefCounted, catalog: RefCounted, width: float = 220.0) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 6)
	for attribute in Catalog.ATTRIBUTES:
		var value: float = float(state.attributes[attribute])
		var need: float = float(state.def.requirements[attribute])
		var name: Label = Style.ui.label(catalog.attribute_name(attribute), 15)
		name.tooltip_text = _about(catalog, attribute)
		name.mouse_filter = Control.MOUSE_FILTER_PASS
		grid.add_child(name)
		grid.add_child(need_bar(value, need, width))
		var share: float = Readiness.ratio(state, attribute)
		grid.add_child(Style.ui.utility("%d / %d" % [int(round(value)), int(need)], 15, Style.GREEN if share >= 1.0 else Style.PAPER))
	return grid


static func _about(catalog: RefCounted, attribute: String) -> String:
	for entry in catalog.attributes:
		if entry.id == attribute:
			return entry.about
	return ""


## A bar filled to `value` with a tick where `need` sits (both 0..100).
static func need_bar(value: float, need: float, width: float) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(width, 16)
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill: Color = Style.GREEN if value >= need else Style.ACCENT
	holder.draw.connect(func() -> void:
		var w: float = holder.size.x
		holder.draw_rect(Rect2(0, 2, w, 12), Color("1c1612"))
		holder.draw_rect(Rect2(0, 2, w * clampf(value / 100.0, 0.0, 1.0), 12), fill)
		var x: float = w * clampf(need / 100.0, 0.0, 1.0)
		holder.draw_line(Vector2(x, -1), Vector2(x, 17), Style.PAPER, 2.0))
	return holder


## Readiness 0..100 with an optional threshold tick (the next mini goal).
static func readiness_bar(value: float, threshold: float, width: float) -> HBoxContainer:
	var row: HBoxContainer = Style.ui.hbox(10)
	row.add_child(Style.ui.label("Readiness", 15))
	var bar: Control = need_bar(value, threshold if threshold > 0.0 else 100.0, width)
	row.add_child(bar)
	var text: String = "%d%%" % int(round(value))
	if threshold > 0.0:
		text += "  (next test needs %d%%)" % int(threshold)
	row.add_child(Style.ui.utility(text, 15, Style.GREEN if threshold > 0.0 and value >= threshold else Style.PAPER))
	return row


## A small labelled meter for fatigue, motivation or rapport.
static func condition(label: String, value: float, colour: Color, tip: String = "") -> HBoxContainer:
	var row: HBoxContainer = Style.ui.hbox(6)
	var name: Label = Style.ui.label(label, 14, Style.MUTED)
	name.custom_minimum_size.x = 82
	if not tip.is_empty():
		name.tooltip_text = tip
		name.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(name)
	row.add_child(Style.ui.meter(value, 100.0, 110.0, colour))
	row.add_child(Style.ui.utility("%d" % int(round(value)), 14))
	return row


## Advisor notes ({tone, text}) as marked, coloured lines.
static func notes(list: Array, size: int = 14) -> VBoxContainer:
	var column: VBoxContainer = Style.ui.vbox(3)
	for note in list:
		var line: Label = Style.ui.wrapped("%s %s" % [Style.tone_mark(note.tone), note.text], size, Style.tone_color(note.tone))
		column.add_child(line)
	return column


## A panel with a heading and a column for content.
static func card(title: String, alpha: float = 0.95) -> Array:
	var panel: PanelContainer = Style.ui.panel(alpha)
	var column: VBoxContainer = Style.ui.vbox(8)
	panel.add_child(column)
	if not title.is_empty():
		column.add_child(Style.ui.heading(title, 22))
	return [panel, column]


## A quiet section divider shared by planning and shopping.
static func section_label(title: String) -> HBoxContainer:
	var row: HBoxContainer = Style.ui.hbox(12)
	row.add_child(Style.ui.label(title, 14, Style.MUTED))
	var line := HSeparator.new()
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(line)
	return row


## A compact labelled value; the same resource reads alike on every page.
static func resource_value(title: String, value: String, colour: Color = Style.PAPER) -> HBoxContainer:
	var row: HBoxContainer = Style.ui.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(Style.ui.label(title, 14, Style.MUTED))
	row.add_child(Style.ui.utility(value, 22, colour))
	return row


## The readiness ring with a notch at the next test; its tooltip says how
## readiness is counted.
static func readiness_ring(value: float, threshold: float, diameter: float, ghost: float = -1.0) -> Control:
	var weights: Dictionary = Balance.dict("readiness.weights")
	var parts: PackedStringArray = []
	for attribute in Catalog.ATTRIBUTES:
		parts.append("%d%% %s" % [int(round(float(weights[attribute]) * 100.0)), attribute.capitalize()])
	var tip: String = "Readiness: each attribute counts up to the goal line (%s)." % ", ".join(parts)
	return Charts.ring(value, threshold, diameter, "%d%%" % int(round(value)), tip, ghost)


## Fatigue, motivation and rapport as icon meters with no numbers.
static func condition_icons(state: RefCounted, width: float = 90.0) -> HBoxContainer:
	var row: HBoxContainer = Style.ui.hbox(14)
	row.add_child(Charts.meter("fatigue", state.fatigue, Style.RED if state.fatigue >= 50.0 else Style.AMBER, "Fatigue %d: carried into the next session (lower energy, less progress)." % int(round(state.fatigue)), width))
	row.add_child(Charts.meter("motivation", state.motivation, Style.GREEN, "Motivation %d: how much they get from training alone." % int(round(state.motivation)), width))
	row.add_child(Charts.meter("rapport", state.rapport, Color("9cc4e4"), "Rapport %d: widens the target zones in sessions." % int(round(state.rapport)), width))
	return row


## The season strip for this game; with `only` set, mini goals are coloured
## by that client's results, otherwise by every client's (red if any missed).
static func season_strip(game: RefCounted, width: float, only: RefCounted = null) -> Control:
	var results: Dictionary = {}
	for state in game.clients if only == null else [only]:
		for milestone in state.milestones:
			var week: int = int(milestone.week)
			results[week] = bool(milestone.passed) and bool(results.get(week, true))
	var strip: Control = Charts.season_strip(Balance.list("campaign.blocks"), game.week, Balance.list("milestones"), results, width)
	strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return strip
