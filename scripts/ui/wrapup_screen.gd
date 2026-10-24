extends Control
## After a session: how it went, what it built and why, shown as shapes. The
## header ring is the session's performance; one line says what worked and one
## what to change; each exercise shows its coaching score, its peak moments as
## marks (the explanation sits in their tooltips, and in plain words whenever a
## call was wrong) and what it built; bars show every attribute and condition
## moving; the payment comes last.
const Style = preload("res://scripts/ui/style.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
const Catalog = preload("res://scripts/core/catalog.gd")
const Charts = preload("res://scripts/ui/charts.gd")

signal continued

var game: RefCounted
var report: Dictionary


func setup(owner: RefCounted, session_report: Dictionary) -> void:
	game = owner
	report = session_report


func _ready() -> void:
	var client: RefCounted = game.client(report.client)
	var column: VBoxContainer = Style.screen(self, 10, 24)
	var header: HBoxContainer = Style.ui.hbox(18)
	column.add_child(header)
	header.add_child(Style.ui.heading(client.def.short, 30))
	header.add_child(Style.ui.spacer())
	var share: int = int(round(report.performance * 100.0))
	header.add_child(Charts.ring(report.performance * 100.0, 0.0, 76.0, "%d%%" % share, "Session performance: the average of every exercise's coaching score. It scales the gains from every exercise in the session, so strong coaching anywhere lifts %s's progress everywhere." % client.def.short, -1.0, Style.ui.palette.level_color(report.performance)))
	column.add_child(_takeaways())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var body: HBoxContainer = Style.ui.hbox(16)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	body.add_child(_exercises_column())
	body.add_child(_progress_column(client))
	var footer: HBoxContainer = Style.ui.hbox(10)
	column.add_child(footer)
	footer.add_child(Charts.icon_control("coin", 30.0, Style.AMBER, "Session fee paid"))
	footer.add_child(Style.ui.utility("$%d" % report.fee, 24, Style.GREEN))
	footer.add_child(Style.ui.spacer())
	var go: Button = Style.ui.button("Continue", func() -> void: continued.emit(), true)
	footer.add_child(go)
	go.grab_focus.call_deferred()


## What worked and what to change: one short line each, led by an icon.
func _takeaways() -> PanelContainer:
	var parts: Array = Widgets.card("", 0.97)
	var inner: VBoxContainer = parts[1]
	var lines: Dictionary = report.takeaways
	for entry in [["check", Style.GREEN, lines.worked], ["up", Style.AMBER, lines.change]]:
		var row: HBoxContainer = Style.ui.hbox(12)
		inner.add_child(row)
		row.add_child(Charts.icon_control(entry[0], 26.0, entry[1]))
		var text: Label = Style.ui.wrapped(entry[2], 18, Style.PAPER)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
	return parts[0]


func _exercises_column() -> VBoxContainer:
	var column: VBoxContainer = Style.ui.vbox(10)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_stretch_ratio = 1.5
	var check_in: Dictionary = report.check_in
	if not check_in.is_empty():
		column.add_child(_check_in_card(check_in))
	for exercise in report.exercises:
		column.add_child(_exercise_card(exercise))
	return column


## The check-in: right or wrong, and what the client said.
func _check_in_card(check_in: Dictionary) -> PanelContainer:
	var parts: Array = Widgets.card("", 0.9)
	var row: HBoxContainer = Style.ui.hbox(12)
	parts[1].add_child(row)
	var right: bool = bool(check_in.correct)
	row.add_child(Charts.icon_control("check" if right else "cross", 24.0, Style.GREEN if right else Style.AMBER))
	var text: String = "\"%s\"" % check_in.answer if right else ("Missed the check-in" if check_in.grade == "miss" else "Wrong question")
	var line: Label = Style.ui.wrapped(text, 16, Style.PAPER)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(line)
	parts[0].tooltip_text = String(check_in.text)
	return parts[0]


func _exercise_card(exercise: Dictionary) -> PanelContainer:
	var parts: Array = Widgets.card("", 0.9)
	var inner: VBoxContainer = parts[1]
	var top: HBoxContainer = Style.ui.hbox(12)
	inner.add_child(top)
	var name: Label = Style.ui.heading(exercise.name, 22)
	name.custom_minimum_size.x = 170
	top.add_child(name)
	var marks: HFlowContainer = HFlowContainer.new()
	marks.add_theme_constant_override("h_separation", 10)
	marks.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	marks.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(marks)
	var score: float = float(exercise.score) * 100.0
	top.add_child(Charts.ring(score, 0.0, 54.0, "%d" % int(round(score)), "Coaching score %d%%" % int(round(score)), -1.0, Style.ui.palette.level_color(float(exercise.score))))
	for peak in exercise.peaks:
		marks.add_child(_peak_mark(peak))
	if absf(exercise.peak_bonus) > 0.001:
		var bonus: Label = Style.ui.utility("%+d%%" % int(round(exercise.peak_bonus * 100.0)), 17, Style.GREEN if exercise.peak_bonus > 0.0 else Style.RED)
		bonus.tooltip_text = "Peak moments: %+d%% progress from this exercise" % int(round(exercise.peak_bonus * 100.0))
		bonus.mouse_filter = Control.MOUSE_FILTER_PASS
		marks.add_child(bonus)
	for key in Catalog.ATTRIBUTES:
		if float(exercise.gains.get(key, 0.0)) >= 0.5:
			marks.add_child(Charts.chip("%s +%.1f" % [Charts.short_name(game.catalog, key), float(exercise.gains[key])], Style.GREEN, game.catalog.attribute_name(key)))
	if int(exercise.stopped_after) > 0:
		marks.add_child(Charts.chip("Stopped %d/%d" % [int(exercise.stopped_after), int(exercise.presses)], Style.ACCENT, "Stopped after repeat %d of %d, then recovered." % [int(exercise.stopped_after), int(exercise.presses)]))
	if exercise.unsuitable:
		marks.add_child(Charts.chip("½ value", Style.RED, "Unsuitable for %s today, so it gave half value." % game.client(report.client).def.short))
	for peak in exercise.peaks:
		if peak.tone != "good":
			inner.add_child(Style.ui.wrapped("%s %s" % [Style.tone_mark(peak.tone), peak.text], 15, Style.tone_color(peak.tone)))
	inner.add_child(Widgets.notes(exercise.notes, 14))
	return parts[0]


## One peak moment: the signal it came on, the call made (up push, down hold
## back) and whether it was right. Its explanation is the tooltip.
func _peak_mark(peak: Dictionary) -> Control:
	var painter := func(holder: Control) -> void:
		holder.draw_circle(Vector2(13.0, 16.0), 11.0, Style.signal_color(String(peak.signal)))
		var made: String = String(peak.choice)
		if made == "push" or made == "hold":
			Charts.icon(holder, "up" if made == "push" else "down", Rect2(30.0, 4.0, 24.0, 24.0), Style.PUSH if made == "push" else Style.HOLD)
		var right: bool = peak.tone == "good"
		Charts.icon(holder, "check" if right else "cross", Rect2(60.0, 6.0, 20.0, 20.0), Style.GREEN if right else Style.tone_color(String(peak.tone)))
	var text: String = "Peak moment on %s: %s" % [peak.signal, peak.text]
	return Charts.canvas(Vector2(86.0, 32.0), painter, text)


func _progress_column(client: RefCounted) -> VBoxContainer:
	var column: VBoxContainer = Style.ui.vbox(10)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var parts: Array = Widgets.card("", 0.9)
	column.add_child(parts[0])
	var inner: VBoxContainer = parts[1]
	var rows: Array = []
	for change in report.changes:
		rows.append({"label": Charts.short_name(game.catalog, change.attribute), "before": change.before, "after": change.after, "mark": change.need, "tip": "%s %d → %d (needs %d)" % [game.catalog.attribute_name(change.attribute), int(round(change.before)), int(round(change.after)), int(change.need)]})
	inner.add_child(Charts.change_rows(game.catalog, rows, 280.0))
	var ready: HBoxContainer = Style.ui.hbox(14)
	inner.add_child(ready)
	ready.add_child(Widgets.readiness_ring(report.readiness_after, 0.0, 88.0, report.readiness_before))
	var gain: float = report.readiness_after - report.readiness_before
	ready.add_child(Style.ui.utility("%+d" % int(round(gain)), 26, Style.GREEN if gain > 0.0 else Style.MUTED))
	var condition: Array = Widgets.card("", 0.9)
	column.add_child(condition[0])
	var lines: VBoxContainer = condition[1]
	var moods: Array = [
		{"icon": "fatigue", "before": report.fatigue_before, "after": report.fatigue_after, "lower_is_better": true, "colour": Style.AMBER, "tip": "Fatigue %d → %d" % [int(round(report.fatigue_before)), int(round(report.fatigue_after))]},
		{"icon": "motivation", "before": report.motivation_before, "after": report.motivation_after, "colour": Style.GREEN, "tip": "Motivation %d → %d" % [int(round(report.motivation_before)), int(round(report.motivation_after))]},
		{"icon": "rapport", "before": report.rapport_before, "after": report.rapport_after, "colour": Color("9cc4e4"), "tip": "Rapport %d → %d" % [int(round(report.rapport_before)), int(round(report.rapport_after))]},
	]
	lines.add_child(Charts.change_rows(game.catalog, moods, 280.0))
	if report.fatigue_modifier < 0.99:
		var tired: HBoxContainer = Style.ui.hbox(8)
		tired.add_child(Charts.icon_control("fatigue", 22.0, Style.AMBER))
		tired.add_child(Style.ui.utility("%d%%" % int(round(report.fatigue_modifier * 100.0)), 17, Style.AMBER))
		tired.tooltip_text = "%s arrived carrying fatigue, so this session counted for %d%%." % [client.def.short, int(round(report.fatigue_modifier * 100.0))]
		tired.mouse_filter = Control.MOUSE_FILTER_PASS
		lines.add_child(tired)
	if report.injured:
		lines.add_child(Style.ui.wrapped("× Injured: misses next week", 16, Style.RED))
	return column
