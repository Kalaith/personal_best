extends Control
## After a session: how it went, what it built and why. Every peak moment
## is explained, unsuitable entries say what was wrong, and the payment is
## shown last.
const Style = preload("res://scripts/ui/style.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
const Catalog = preload("res://scripts/core/catalog.gd")

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
	header.add_child(Style.ui.heading("Session wrap-up: %s" % client.def.short, 30))
	header.add_child(Style.ui.spacer())
	header.add_child(Style.ui.utility("Performance %d%%" % int(round(report.performance * 100.0)), 22, Style.ui.palette.level_color(report.performance)))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var body: HBoxContainer = Style.ui.hbox(16)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	body.add_child(_exercises_column())
	body.add_child(_progress_column(client))
	var footer: HBoxContainer = Style.ui.hbox(16)
	column.add_child(footer)
	footer.add_child(Style.ui.utility("Paid: $%d session fee" % report.fee, 20, Style.GREEN))
	footer.add_child(Style.ui.spacer())
	var go: Button = Style.ui.button("Continue", func() -> void: continued.emit(), true)
	footer.add_child(go)
	go.grab_focus.call_deferred()


func _exercises_column() -> VBoxContainer:
	var column: VBoxContainer = Style.ui.vbox(10)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_stretch_ratio = 1.5
	var check_in: Dictionary = report.check_in
	if not check_in.is_empty():
		var parts: Array = Widgets.card("Check-in", 0.9)
		parts[1].add_child(Style.ui.wrapped(check_in.text, 14, Style.GREEN if check_in.correct else Style.AMBER))
		column.add_child(parts[0])
	for exercise in report.exercises:
		var parts: Array = Widgets.card("%s  ·  %d%%" % [exercise.name, int(round(exercise.score * 100.0))], 0.9)
		var inner: VBoxContainer = parts[1]
		for peak in exercise.peaks:
			var choice: String = {"push": "Pushed", "hold": "Held back"}.get(peak.choice, "No call")
			inner.add_child(Style.ui.wrapped("%s %s on %s: %s" % [Style.tone_mark(peak.tone), choice, peak.signal, peak.text], 14, Style.tone_color(peak.tone)))
		if absf(exercise.peak_bonus) > 0.001:
			inner.add_child(Style.ui.utility("Peak moments: %+d%% progress from this exercise" % int(round(exercise.peak_bonus * 100.0)), 14, Style.GREEN if exercise.peak_bonus > 0.0 else Style.RED))
		var gained: Array = []
		for key in Catalog.ATTRIBUTES:
			if float(exercise.gains.get(key, 0.0)) >= 0.05:
				gained.append("%s +%.1f" % [game.catalog.attribute_name(key), float(exercise.gains[key])])
		inner.add_child(Style.ui.label("Built: " + (", ".join(gained) if not gained.is_empty() else "very little"), 14, Style.PAPER))
		if exercise.unsuitable:
			inner.add_child(Style.ui.wrapped("× Unsuitable for %s today, so it gave half value:" % game.client(report.client).def.short, 14, Style.RED))
		inner.add_child(Widgets.notes(exercise.notes, 13))
		column.add_child(parts[0])
	return column


func _progress_column(client: RefCounted) -> VBoxContainer:
	var column: VBoxContainer = Style.ui.vbox(10)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var parts: Array = Widgets.card("Progress", 0.9)
	column.add_child(parts[0])
	var inner: VBoxContainer = parts[1]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	inner.add_child(grid)
	for change in report.changes:
		grid.add_child(Style.ui.label("%s (needs %d)" % [game.catalog.attribute_name(change.attribute), int(change.need)], 14))
		grid.add_child(Style.change_label(change.before, change.after, 14))
	inner.add_child(Style.ui.label("Readiness", 16, Style.ACCENT))
	inner.add_child(Style.change_label(report.readiness_before, report.readiness_after, 18, "%"))
	var condition: Array = Widgets.card("Condition", 0.9)
	column.add_child(condition[0])
	var lines: VBoxContainer = condition[1]
	var conditions := GridContainer.new()
	conditions.columns = 2
	conditions.add_theme_constant_override("h_separation", 14)
	lines.add_child(conditions)
	conditions.add_child(Style.ui.label("Fatigue", 14))
	conditions.add_child(Style.change_label(report.fatigue_before, report.fatigue_after, 14, "", false))
	conditions.add_child(Style.ui.label("Motivation", 14))
	conditions.add_child(Style.change_label(report.motivation_before, report.motivation_after, 14))
	conditions.add_child(Style.ui.label("Rapport", 14))
	conditions.add_child(Style.change_label(report.rapport_before, report.rapport_after, 14))
	if report.fatigue_modifier < 0.99:
		lines.add_child(Style.ui.wrapped("%s arrived carrying fatigue, so this session counted for %d%%." % [client.def.short, int(round(report.fatigue_modifier * 100.0))], 13, Style.AMBER))
	if report.injured:
		lines.add_child(Style.ui.wrapped("× Minor injury: %s will miss next week's session." % client.def.short, 15, Style.RED))
	lines.add_child(Style.ui.wrapped("Progress = routine value × suitability × performance × fatigue × peak bonuses.", 12))
	return column
