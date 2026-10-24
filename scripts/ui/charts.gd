extends RefCounted
## Drawn widgets that say with a shape what used to take a sentence: the
## readiness ring, the attribute radar, before/after bars, the season strip,
## the race-day time chart and the small icons that stand in for words.
## Every widget keeps its numbers in a tooltip, so nothing is lost, only moved
## out of the way of the player's eyes.
const Style = preload("res://scripts/ui/style.gd")
const Catalog = preload("res://scripts/core/catalog.gd")

const TRACK := Color("1c1612")
const RING_START: float = -PI * 0.5


## A Control of `size` that paints itself with `painter(holder)`.
static func canvas(size: Vector2, painter: Callable, tip: String = "") -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = size
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.tooltip_text = tip
	holder.mouse_filter = Control.MOUSE_FILTER_PASS if not tip.is_empty() else Control.MOUSE_FILTER_IGNORE
	holder.draw.connect(painter.bind(holder))
	return holder


static func font_of(holder: Control) -> Font:
	return holder.get_theme_default_font()


## Colour of a readiness-like share against a mark: green once met.
static func level_colour(value: float, mark: float) -> Color:
	if mark > 0.0 and value >= mark:
		return Style.GREEN
	return Style.ACCENT


# ---- Ring -------------------------------------------------------------

## A donut gauge filled to `value` (0..100) with a notch at `mark`. A pale arc
## from `ghost` to `value` shows what was lost or gained. `centre` is the one
## figure in the middle.
static func ring(value: float, mark: float, diameter: float, centre: String, tip: String = "", ghost: float = -1.0, colour: Variant = null) -> Control:
	var fill: Color = colour if colour != null else level_colour(value, mark)
	var painter := func(holder: Control) -> void:
		var middle: Vector2 = holder.size * 0.5
		var width: float = diameter * 0.15
		var radius: float = diameter * 0.5 - width * 0.5
		holder.draw_arc(middle, radius, 0.0, TAU, 48, TRACK, width, true)
		if ghost >= 0.0:
			holder.draw_arc(middle, radius, RING_START, RING_START + TAU * clampf(maxf(ghost, value) / 100.0, 0.0, 1.0), 48, Color(Style.PAPER, 0.28), width, true)
		if value > 0.0:
			holder.draw_arc(middle, radius, RING_START, RING_START + TAU * clampf(value / 100.0, 0.0, 1.0), 48, fill, width, true)
		if mark > 0.0:
			var angle: float = RING_START + TAU * clampf(mark / 100.0, 0.0, 1.0)
			var direction := Vector2(cos(angle), sin(angle))
			holder.draw_line(middle + direction * (radius - width * 0.75), middle + direction * (radius + width * 0.75), Style.PAPER, 3.0)
		var font: Font = font_of(holder)
		var size: int = int(diameter * 0.24)
		holder.draw_string(font, middle + Vector2(-diameter * 0.5, size * 0.36), centre, HORIZONTAL_ALIGNMENT_CENTER, diameter, size, Style.PAPER)
	return canvas(Vector2(diameter, diameter), painter, tip)


# ---- Radar ------------------------------------------------------------

## The five attributes as a pentagon: the filled shape is where they stand,
## the pale outline is what the goal needs. A green dot marks a met need.
static func radar(catalog: RefCounted, values: Dictionary, needs: Dictionary, diameter: float, tip: String = "") -> Control:
	var painter := func(holder: Control) -> void:
		var middle: Vector2 = holder.size * 0.5
		var radius: float = diameter * 0.5 - 26.0
		var font: Font = font_of(holder)
		var count: int = Catalog.ATTRIBUTES.size()
		for scale in [0.5, 1.0]:
			holder.draw_polyline(_ring_points(middle, radius * scale, count, true), Color(Style.PAPER, 0.14), 1.0, true)
		var shape := PackedVector2Array()
		var goal := PackedVector2Array()
		for i in range(count):
			var attribute: String = Catalog.ATTRIBUTES[i]
			var angle: float = RING_START + TAU * float(i) / float(count)
			var direction := Vector2(cos(angle), sin(angle))
			holder.draw_line(middle, middle + direction * radius, Color(Style.PAPER, 0.1), 1.0)
			shape.append(middle + direction * radius * clampf(float(values[attribute]) / 100.0, 0.0, 1.0))
			goal.append(middle + direction * radius * clampf(float(needs[attribute]) / 100.0, 0.0, 1.0))
			var label: String = short_name(catalog, attribute)
			var at: Vector2 = middle + direction * (radius + 16.0)
			holder.draw_string(font, at + Vector2(-30.0, 6.0), label, HORIZONTAL_ALIGNMENT_CENTER, 60.0, 15, Style.MUTED)
		holder.draw_colored_polygon(shape, Color(Style.ACCENT, 0.38))
		holder.draw_polyline(_closed(shape), Style.ACCENT, 2.5, true)
		holder.draw_polyline(_closed(goal), Style.PAPER, 2.0, true)
		for i in range(count):
			var attribute: String = Catalog.ATTRIBUTES[i]
			var met: bool = float(values[attribute]) >= float(needs[attribute])
			holder.draw_circle(shape[i], 5.0, Style.GREEN if met else Style.ACCENT)
	return canvas(Vector2(diameter, diameter), painter, tip)


static func short_name(catalog: RefCounted, attribute: String) -> String:
	for entry in catalog.attributes:
		if entry.id == attribute:
			return String(entry.short)
	return attribute.substr(0, 3).to_upper()


static func _ring_points(middle: Vector2, radius: float, count: int, closed: bool) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(count):
		var angle: float = RING_START + TAU * float(i) / float(count)
		points.append(middle + Vector2(cos(angle), sin(angle)) * radius)
	if closed:
		points.append(points[0])
	return points


static func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array(points)
	result.append(points[0])
	return result


# ---- Before / after bars ---------------------------------------------

## One row per entry of {label | icon, before, after, mark, lower_is_better,
## tip}. The bar holds the old value, the change is painted on top in green
## (or red), and a notch shows what the goal needs. The change is the only
## number.
static func change_rows(catalog: RefCounted, rows: Array, width: float) -> Control:
	var row_height: float = 30.0
	var painter := func(holder: Control) -> void:
		var font: Font = font_of(holder)
		var bar_left: float = 62.0
		var bar_width: float = holder.size.x - bar_left - 62.0
		for i in range(rows.size()):
			var row: Dictionary = rows[i]
			var top: float = float(i) * row_height
			var before: float = float(row.before)
			var after: float = float(row.after)
			var good: bool = (after >= before) != bool(row.get("lower_is_better", false))
			if row.has("icon"):
				icon(holder, String(row.icon), Rect2(2.0, top + 3.0, 22.0, 22.0), Style.PAPER)
			else:
				holder.draw_string(font, Vector2(0.0, top + 21.0), String(row.label), HORIZONTAL_ALIGNMENT_LEFT, bar_left, 17, Style.PAPER)
			holder.draw_rect(Rect2(bar_left, top + 7.0, bar_width, 14.0), TRACK)
			var low: float = minf(before, after)
			var high: float = maxf(before, after)
			holder.draw_rect(Rect2(bar_left, top + 7.0, bar_width * clampf(low / 100.0, 0.0, 1.0), 14.0), Style.ACCENT if not row.has("colour") else row.colour)
			if high - low >= 0.05:
				holder.draw_rect(Rect2(bar_left + bar_width * clampf(low / 100.0, 0.0, 1.0), top + 7.0, bar_width * clampf((high - low) / 100.0, 0.0, 1.0), 14.0), Style.GREEN if good else Style.RED)
			if row.has("mark"):
				var x: float = bar_left + bar_width * clampf(float(row.mark) / 100.0, 0.0, 1.0)
				holder.draw_line(Vector2(x, top + 3.0), Vector2(x, top + 25.0), Style.PAPER, 2.0)
			var delta: float = after - before
			if absf(delta) >= (0.05 if bool(row.get("fine", false)) else 0.5):
				var shown: String = "%+.1f" % delta if bool(row.get("fine", false)) and absf(delta) < 10.0 else "%+d" % int(round(delta))
				holder.draw_string(font, Vector2(bar_left + bar_width + 8.0, top + 21.0), shown, HORIZONTAL_ALIGNMENT_LEFT, 54.0, 17, Style.GREEN if good else Style.RED)
	var tips: PackedStringArray = []
	for row in rows:
		if row.has("tip"):
			tips.append(String(row.tip))
	var chart: Control = canvas(Vector2(width, row_height * float(rows.size())), painter, "\n".join(tips))
	chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return chart


# ---- Pips and chips ---------------------------------------------------

## `filled` of `total` dots.
static func pips(filled: int, total: int, colour: Color, tip: String = "") -> Control:
	var painter := func(holder: Control) -> void:
		for i in range(total):
			var middle := Vector2(9.0 + 20.0 * float(i), holder.size.y * 0.5)
			if i < filled:
				holder.draw_circle(middle, 7.0, colour)
			else:
				holder.draw_arc(middle, 6.0, 0.0, TAU, 16, Color(colour, 0.5), 2.0, true)
	return canvas(Vector2(20.0 * float(total), 24.0), painter, tip)


## A small rounded label: an attribute, a personality, a day.
static func chip(text: String, colour: Color, tip: String = "") -> PanelContainer:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(colour, 0.22)
	box.border_color = colour
	box.set_border_width_all(2)
	box.set_corner_radius_all(12)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	panel.add_theme_stylebox_override("panel", box)
	panel.tooltip_text = tip
	panel.mouse_filter = Control.MOUSE_FILTER_PASS if not tip.is_empty() else Control.MOUSE_FILTER_IGNORE
	var label: Label = Style.ui.label(text, 15, Style.PAPER)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	return panel


## A condition meter led by its icon: fatigue, motivation or rapport.
static func meter(kind: String, value: float, colour: Color, tip: String, width: float = 110.0) -> HBoxContainer:
	var row: HBoxContainer = Style.ui.hbox(6)
	row.add_child(icon_control(kind, 22.0, colour, tip))
	var bar: ProgressBar = Style.ui.meter(value, 100.0, width, colour)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	return row


# ---- Icons ------------------------------------------------------------

static func icon_control(kind: String, size: float, colour: Color, tip: String = "") -> Control:
	var painter := func(holder: Control) -> void:
		icon(holder, kind, Rect2(Vector2.ZERO, holder.size), colour)
	return canvas(Vector2(size, size), painter, tip)


## Draws icon `kind` inside `box` on `canvas_item`: bolt, flame, heart, star,
## coin, diamond, check, cross, up, down, sun, cloud, rain, person.
static func icon(canvas_item: CanvasItem, kind: String, box: Rect2, colour: Color) -> void:
	var at := func(x: float, y: float) -> Vector2: return box.position + Vector2(box.size.x * x, box.size.y * y)
	var unit: float = box.size.x
	match kind:
		"fatigue":
			canvas_item.draw_colored_polygon(PackedVector2Array([at.call(0.6, 0.0), at.call(0.18, 0.56), at.call(0.45, 0.56), at.call(0.35, 1.0), at.call(0.82, 0.4), at.call(0.55, 0.4), at.call(0.74, 0.0)]), colour)
		"motivation":
			canvas_item.draw_circle(at.call(0.5, 0.64), unit * 0.3, colour)
			canvas_item.draw_colored_polygon(PackedVector2Array([at.call(0.21, 0.55), at.call(0.79, 0.55), at.call(0.5, 0.02)]), colour)
		"rapport":
			canvas_item.draw_circle(at.call(0.3, 0.34), unit * 0.22, colour)
			canvas_item.draw_circle(at.call(0.7, 0.34), unit * 0.22, colour)
			canvas_item.draw_colored_polygon(PackedVector2Array([at.call(0.09, 0.44), at.call(0.91, 0.44), at.call(0.5, 0.95)]), colour)
		"star":
			var points := PackedVector2Array()
			for i in range(10):
				var angle: float = -PI * 0.5 + PI * float(i) / 5.0
				var reach: float = 0.5 if i % 2 == 0 else 0.22
				points.append(at.call(0.5 + cos(angle) * reach, 0.54 + sin(angle) * reach))
			canvas_item.draw_colored_polygon(points, colour)
		"coin":
			canvas_item.draw_circle(at.call(0.5, 0.5), unit * 0.46, colour)
			canvas_item.draw_arc(at.call(0.5, 0.5), unit * 0.3, 0.0, TAU, 20, Color(Style.INK, 0.6), 2.0, true)
		"diamond":
			canvas_item.draw_colored_polygon(PackedVector2Array([at.call(0.5, 0.04), at.call(0.96, 0.5), at.call(0.5, 0.96), at.call(0.04, 0.5)]), colour)
		"check":
			canvas_item.draw_polyline(PackedVector2Array([at.call(0.12, 0.55), at.call(0.4, 0.82), at.call(0.88, 0.2)]), colour, maxf(3.0, unit * 0.16), true)
		"cross":
			canvas_item.draw_line(at.call(0.15, 0.15), at.call(0.85, 0.85), colour, maxf(3.0, unit * 0.16), true)
			canvas_item.draw_line(at.call(0.85, 0.15), at.call(0.15, 0.85), colour, maxf(3.0, unit * 0.16), true)
		"up":
			canvas_item.draw_colored_polygon(PackedVector2Array([at.call(0.5, 0.1), at.call(0.92, 0.88), at.call(0.08, 0.88)]), colour)
		"down":
			canvas_item.draw_colored_polygon(PackedVector2Array([at.call(0.08, 0.12), at.call(0.92, 0.12), at.call(0.5, 0.9)]), colour)
		"sun":
			canvas_item.draw_circle(at.call(0.5, 0.5), unit * 0.24, colour)
			for i in range(8):
				var angle: float = TAU * float(i) / 8.0
				canvas_item.draw_line(at.call(0.5 + cos(angle) * 0.34, 0.5 + sin(angle) * 0.34), at.call(0.5 + cos(angle) * 0.48, 0.5 + sin(angle) * 0.48), colour, 2.5, true)
		"cloud", "rain":
			canvas_item.draw_circle(at.call(0.35, 0.5), unit * 0.22, colour)
			canvas_item.draw_circle(at.call(0.62, 0.42), unit * 0.28, colour)
			canvas_item.draw_rect(Rect2(at.call(0.3, 0.5), Vector2(unit * 0.55, unit * 0.2)), colour)
			if kind == "rain":
				for x in [0.3, 0.5, 0.7]:
					canvas_item.draw_line(at.call(x, 0.78), at.call(x - 0.06, 0.98), Style.HOLD, 2.5, true)
		"person":
			canvas_item.draw_circle(at.call(0.5, 0.28), unit * 0.2, colour)
			canvas_item.draw_colored_polygon(PackedVector2Array([at.call(0.15, 0.95), at.call(0.25, 0.55), at.call(0.75, 0.55), at.call(0.85, 0.95)]), colour)


## The weather as a picture: sun, cloud or rain.
static func weather_icon(weather_id: String, size: float, tip: String) -> Control:
	var kind: String = {"sunny": "sun", "cloudy": "cloud", "rain": "rain"}.get(weather_id, "cloud")
	var colour: Color = Color("f2c14e") if kind == "sun" else Color("b9c3cf")
	return icon_control(kind, size, colour, tip)


# ---- Season -----------------------------------------------------------

## The twelve weeks as one strip: blocks in their own shades, the weeks
## played filled in, a diamond on each mini goal (green passed, red missed,
## white still ahead) and a flag on race week.
static func season_strip(blocks: Array, week: int, milestones: Array, results: Dictionary, width: float) -> Control:
	var weeks: int = int(blocks.back().last_week)
	var shades: Array = [Color("5b8a5a"), Color("c28a3a"), Color("c0583a"), Color("5b86b8")]
	var painter := func(holder: Control) -> void:
		var cell: float = (holder.size.x - 4.0) / float(weeks)
		for i in range(blocks.size()):
			var block: Dictionary = blocks[i]
			var first: float = float(int(block.first_week) - 1)
			var span: float = float(int(block.last_week)) - first
			var colour: Color = shades[i % shades.size()]
			holder.draw_rect(Rect2(2.0 + first * cell + 1.0, 22.0, span * cell - 2.0, 12.0), Color(colour, 0.35))
			for w in range(int(block.first_week), int(block.last_week) + 1):
				var x: float = 2.0 + float(w - 1) * cell
				if w < week:
					holder.draw_rect(Rect2(x + 1.0, 22.0, cell - 2.0, 12.0), colour)
				elif w == week:
					holder.draw_rect(Rect2(x + 1.0, 18.0, cell - 2.0, 20.0), Style.PAPER)
			holder.draw_string(font_of(holder), Vector2(2.0 + first * cell + 4.0, 56.0), String(block.name), HORIZONTAL_ALIGNMENT_LEFT, span * cell, 15, Style.MUTED)
		for milestone in milestones:
			var x: float = 2.0 + float(int(milestone.week)) * cell - cell * 0.5
			var colour: Color = Style.PAPER
			if results.has(int(milestone.week)):
				colour = Style.GREEN if results[int(milestone.week)] else Style.RED
			holder.draw_colored_polygon(PackedVector2Array([Vector2(x, 0.0), Vector2(x + 8.0, 8.0), Vector2(x, 16.0), Vector2(x - 8.0, 8.0)]), colour)
		var flag_x: float = 2.0 + float(weeks) * cell - cell * 0.5
		holder.draw_line(Vector2(flag_x, 0.0), Vector2(flag_x, 16.0), Style.PAPER, 2.0)
		holder.draw_colored_polygon(PackedVector2Array([Vector2(flag_x, 0.0), Vector2(flag_x + 12.0, 4.0), Vector2(flag_x, 8.0)]), Style.AMBER)
	var tips: PackedStringArray = []
	for milestone in milestones:
		tips.append("Week %d: %s (readiness %d%%)" % [int(milestone.week), milestone.name, int(milestone.threshold)])
	return canvas(Vector2(width, 62.0), painter, "\n".join(tips))


## Green, amber and red, each with the call to make there: push (up) or
## hold back (down). The amber call is the block's rule.
static func signal_rule(push_on_amber: bool) -> Control:
	var painter := func(holder: Control) -> void:
		var calls: Array = [[Style.GREEN, true], [Style.AMBER, push_on_amber], [Style.RED, false]]
		for i in range(calls.size()):
			var x: float = 14.0 + 66.0 * float(i)
			holder.draw_circle(Vector2(x, 15.0), 11.0, calls[i][0])
			icon(holder, "up" if calls[i][1] else "down", Rect2(x + 16.0, 3.0, 24.0, 24.0), Style.PUSH if calls[i][1] else Style.HOLD)
	return canvas(Vector2(200.0, 30.0), painter, "On each signal: push (up) or hold back (down). Amber depends on the block.")


# ---- Race -------------------------------------------------------------

## Finishing times on one line: the band race-day luck allows, a notch at the
## goal, and the finish as a dot.
static func time_chart(low: float, high: float, goal: float, finish: float, cutoff: float, width: float, tip: String = "") -> Control:
	var painter := func(holder: Control) -> void:
		var from: float = minf(minf(low, goal), finish) - 8.0
		var to: float = maxf(maxf(high, goal), finish) + 8.0
		var line_y: float = 38.0
		var at := func(minutes: float) -> float: return 10.0 + (holder.size.x - 20.0) * (minutes - from) / (to - from)
		var font: Font = font_of(holder)
		holder.draw_rect(Rect2(10.0, line_y - 3.0, holder.size.x - 20.0, 6.0), TRACK)
		holder.draw_rect(Rect2(at.call(low), line_y - 12.0, at.call(high) - at.call(low), 24.0), Color(Style.ACCENT, 0.6))
		holder.draw_line(Vector2(at.call(goal), 4.0), Vector2(at.call(goal), 72.0), Style.PAPER, 3.0)
		holder.draw_string(font, Vector2(at.call(goal) - 40.0, 90.0), _clock(goal), HORIZONTAL_ALIGNMENT_CENTER, 80.0, 17, Style.PAPER)
		if cutoff > 0.0 and cutoff < to:
			holder.draw_line(Vector2(at.call(cutoff), 20.0), Vector2(at.call(cutoff), 56.0), Style.RED, 2.0)
		if finish > 0.0:
			var made: bool = finish <= goal
			holder.draw_circle(Vector2(at.call(finish), line_y), 11.0, Style.GREEN if made else Style.AMBER)
			if absf(at.call(finish) - at.call(goal)) > 70.0:
				holder.draw_string(font, Vector2(at.call(finish) - 40.0, 90.0), _clock(finish), HORIZONTAL_ALIGNMENT_CENTER, 80.0, 17, Style.GREEN if made else Style.AMBER)
	return canvas(Vector2(width, 98.0), painter, tip)


static func _clock(minutes: float) -> String:
	var total: int = int(round(minutes))
	return "%d:%02d" % [total / 60, total % 60]


## Readiness at each check as a line: a dot per mini goal (green passed, red
## missed), the race at the end, and a dashed line at 90%, where the goal
## time comes within reach.
static func journey(points: Array, width: float, tip: String = "") -> Control:
	var painter := func(holder: Control) -> void:
		var height: float = holder.size.y
		var plot := Rect2(14.0, 10.0, holder.size.x - 28.0, height - 20.0)
		var spot := func(point: Dictionary) -> Vector2:
			return Vector2(plot.position.x + plot.size.x * float(point.week) / 12.0, plot.end.y - plot.size.y * clampf(float(point.value) / 100.0, 0.0, 1.0))
		holder.draw_line(Vector2(plot.position.x, plot.end.y), Vector2(plot.end.x, plot.end.y), Color(Style.PAPER, 0.2), 1.0)
		var half_y: float = plot.end.y - plot.size.y * 0.5
		holder.draw_line(Vector2(plot.position.x, half_y), Vector2(plot.end.x, half_y), Color(Style.PAPER, 0.08), 1.0)
		var goal_y: float = plot.end.y - plot.size.y * 0.9
		var x: float = plot.position.x
		while x < plot.end.x:
			holder.draw_line(Vector2(x, goal_y), Vector2(minf(x + 8.0, plot.end.x), goal_y), Color(Style.PAPER, 0.4), 1.5)
			x += 14.0
		var line := PackedVector2Array()
		for point in points:
			line.append(spot.call(point))
		if line.size() >= 2:
			holder.draw_polyline(line, Style.ACCENT, 3.0, true)
		for i in range(points.size()):
			var point: Dictionary = points[i]
			if point.has("passed"):
				holder.draw_circle(line[i], 8.0, Style.GREEN if point.passed else Style.RED)
			else:
				holder.draw_circle(line[i], 4.0, Style.PAPER)
	return canvas(Vector2(width, 190.0), painter, tip)


## One bar split into parts of {value, colour}, widest first reading left to
## right: how a payment is made up.
static func stack_bar(parts: Array, width: float, tip: String = "") -> Control:
	var painter := func(holder: Control) -> void:
		var total: float = 0.0
		for part in parts:
			total += maxf(float(part.value), 0.0)
		if total <= 0.0:
			return
		var x: float = 0.0
		for part in parts:
			var span: float = holder.size.x * maxf(float(part.value), 0.0) / total
			holder.draw_rect(Rect2(x, 2.0, maxf(span - 2.0, 0.0), 16.0), part.colour)
			x += span
	return canvas(Vector2(width, 20.0), painter, tip)
