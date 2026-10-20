extends RefCounted
## Small composite widgets several screens share: the attribute table
## (value against what the goal needs), the readiness bar, condition meters
## and advisor notes.
const Style = preload("res://scripts/ui/style.gd")
const Readiness = preload("res://scripts/core/readiness.gd")
const Catalog = preload("res://scripts/core/catalog.gd")


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
