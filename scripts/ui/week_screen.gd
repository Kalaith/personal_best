extends Control
## The end of a week: what clients did on their own, how they recovered,
## and, at the end of a block, the mini goal test each of them faced.
const Style = preload("res://scripts/ui/style.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
const Catalog = preload("res://scripts/core/catalog.gd")

signal continued

var game: RefCounted
var summary: Dictionary


func setup(owner: RefCounted, week_summary: Dictionary) -> void:
	game = owner
	summary = week_summary


func _ready() -> void:
	var column: VBoxContainer = Style.screen(self, 12, 26)
	var milestone: Dictionary = summary.milestone
	if not milestone.is_empty():
		column.add_child(Style.ui.heading("Mini goal: %s" % milestone.name, 34))
		column.add_child(Style.ui.label("End of week %d. Readiness of %d%% passes the test." % [summary.week, int(milestone.threshold)], 16, Style.MUTED))
		var tests: HBoxContainer = Style.ui.hbox(14)
		column.add_child(tests)
		for result in summary.milestone_results:
			tests.add_child(_test_card(result))
	else:
		column.add_child(Style.ui.heading("End of week %d" % summary.week, 32))
	column.add_child(Style.ui.label("The rest of the week (%s)" % String(summary.weather).to_lower(), 18, Style.ACCENT))
	var weeks: HBoxContainer = Style.ui.hbox(14)
	column.add_child(weeks)
	for entry in summary.clients:
		weeks.add_child(_week_card(entry))
	column.add_child(Style.ui.spacer())
	var label: String = "Race day" if not summary.marathon.is_empty() else "On to week %d" % (int(summary.week) + 1)
	var go: Button = Style.ui.button(label, func() -> void: continued.emit(), true)
	go.size_flags_horizontal = Control.SIZE_SHRINK_END
	column.add_child(go)
	go.grab_focus.call_deferred()


func _test_card(result: Dictionary) -> PanelContainer:
	var parts: Array = Widgets.card(result.client_name, 0.95)
	var panel: PanelContainer = parts[0]
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var inner: VBoxContainer = parts[1]
	var verdict: String = "PASSED" if result.passed else "NOT YET"
	inner.add_child(Style.ui.heading(verdict, 26, Style.GREEN if result.passed else Style.AMBER))
	inner.add_child(Style.ui.utility("Readiness %d%%  (needed %d%%)" % [int(round(result.readiness)), int(result.threshold)], 16))
	if result.passed:
		inner.add_child(Style.ui.label("Bonus: $%d  ·  +1 reputation point" % int(result.bonus), 15, Style.GREEN))
	else:
		inner.add_child(Style.ui.wrapped("No bonus this time. The programme carries on; here is what is holding them back:", 14))
	for line in result.guidance:
		inner.add_child(Style.ui.wrapped("•  " + line, 14, Style.PAPER))
	return panel


func _week_card(entry: Dictionary) -> PanelContainer:
	var parts: Array = Widgets.card(entry.name, 0.9)
	var panel: PanelContainer = parts[0]
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var inner: VBoxContainer = parts[1]
	if entry.sat_out:
		inner.add_child(Style.ui.wrapped("Rested an injury all week: no training at all.", 14, Style.AMBER))
	elif entry.skipped:
		inner.add_child(Style.ui.wrapped("No coached session this week. Motivation dipped.", 14, Style.AMBER))
	if entry.own_sessions > 0:
		var share: int = int(round(entry.motivation_factor * 100.0))
		inner.add_child(Style.ui.wrapped("Trained alone %d times from their routine at half value%s." % [entry.own_sessions, "" if share >= 100 else ", and only %d%% of that with motivation this low" % share], 14, Style.PAPER))
		var gained: Array = []
		for key in Catalog.ATTRIBUTES:
			if float(entry.background.get(key, 0.0)) >= 0.05:
				gained.append("%s +%.1f" % [game.catalog.attribute_name(key), float(entry.background[key])])
		if not gained.is_empty():
			inner.add_child(Style.ui.label(", ".join(gained), 14, Style.GREEN))
	var fatigue: HBoxContainer = Style.ui.hbox(8)
	fatigue.add_child(Style.ui.label("Fatigue after %d rest day%s" % [entry.rest_days, "" if entry.rest_days == 1 else "s"], 14))
	fatigue.add_child(Style.change_label(entry.fatigue_before, entry.fatigue_after, 14, "", false))
	inner.add_child(fatigue)
	var ready: HBoxContainer = Style.ui.hbox(8)
	ready.add_child(Style.ui.label("Readiness from the rest of the week", 14))
	ready.add_child(Style.change_label(entry.readiness_before, entry.readiness_after, 14, "%"))
	inner.add_child(ready)
	if entry.injured_next_week:
		inner.add_child(Style.ui.wrapped("Still nursing a minor injury: unavailable next week.", 14, Style.RED))
	return panel
