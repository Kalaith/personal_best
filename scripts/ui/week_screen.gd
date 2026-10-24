extends Control
## The end of a week as pictures: what each client did on their own and how
## they recovered (a readiness ring, attribute bars and a fatigue bar), and,
## at the end of a block, the mini goal test each of them faced (a ring against
## the pass mark and the weakest areas as chips).
const Style = preload("res://scripts/ui/style.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
const Catalog = preload("res://scripts/core/catalog.gd")
const Charts = preload("res://scripts/ui/charts.gd")
const Portrait = preload("res://scripts/ui/portrait.gd")

signal continued

var game: RefCounted
var summary: Dictionary


func setup(owner: RefCounted, week_summary: Dictionary) -> void:
	game = owner
	summary = week_summary


func _ready() -> void:
	var column: VBoxContainer = Style.screen(self, 12, 26)
	var milestone: Dictionary = summary.milestone
	var header: HBoxContainer = Style.ui.hbox(14)
	column.add_child(header)
	if not milestone.is_empty():
		header.add_child(Style.ui.heading("Mini goal: %s" % milestone.name, 34))
	else:
		header.add_child(Style.ui.heading("End of week %d" % summary.week, 32))
	header.add_child(Style.ui.spacer())
	header.add_child(Charts.weather_icon(String(summary.weather).to_lower().replace("heavy ", ""), 36.0, "The rest of the week: %s" % String(summary.weather).to_lower()))
	if not milestone.is_empty():
		var tests: HBoxContainer = Style.ui.hbox(14)
		column.add_child(tests)
		for result in summary.milestone_results:
			tests.add_child(_test_card(result))
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


## A client's name beside their face, for recognising a card at a glance.
func _title(client_id: String, name: String) -> HBoxContainer:
	var row: HBoxContainer = Style.ui.hbox(10)
	var face := Portrait.new()
	face.look = game.client(client_id).def.look
	face.ready.connect(func() -> void: face.custom_minimum_size = Vector2(52, 52))
	row.add_child(face)
	row.add_child(Style.ui.heading(name, 22))
	return row


func _test_card(result: Dictionary) -> PanelContainer:
	var parts: Array = Widgets.card("", 0.95)
	var panel: PanelContainer = parts[0]
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var inner: VBoxContainer = parts[1]
	inner.add_child(_title(result.client, result.client_name))
	var body: HBoxContainer = Style.ui.hbox(18)
	inner.add_child(body)
	var passed: bool = bool(result.passed)
	body.add_child(Charts.ring(result.readiness, result.threshold, 118.0, "%d%%" % int(round(result.readiness)), "Readiness %d%% against the %d%% needed" % [int(round(result.readiness)), int(result.threshold)]))
	var verdict: VBoxContainer = Style.ui.vbox(6)
	verdict.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	body.add_child(verdict)
	var mark: HBoxContainer = Style.ui.hbox(8)
	mark.add_child(Charts.icon_control("check" if passed else "cross", 30.0, Style.GREEN if passed else Style.AMBER))
	mark.add_child(Style.ui.heading("PASSED" if passed else "NOT YET", 26, Style.GREEN if passed else Style.AMBER))
	verdict.add_child(mark)
	if passed:
		var bonus: HBoxContainer = Style.ui.hbox(8)
		bonus.add_child(Charts.icon_control("coin", 24.0, Style.AMBER))
		bonus.add_child(Style.ui.utility("%d" % int(result.bonus), 18, Style.GREEN))
		bonus.add_child(Charts.icon_control("star", 24.0, Style.AMBER))
		bonus.add_child(Style.ui.utility("+1", 18, Style.GREEN))
		bonus.tooltip_text = "Bonus $%d and +1 reputation point" % int(result.bonus)
		bonus.mouse_filter = Control.MOUSE_FILTER_PASS
		verdict.add_child(bonus)
	var lagging: HFlowContainer = HFlowContainer.new()
	lagging.add_theme_constant_override("h_separation", 8)
	verdict.add_child(lagging)
	for i in range(result.lagging.size()):
		lagging.add_child(Charts.chip(game.catalog.attribute_name(result.lagging[i]), Style.AMBER, String(result.guidance[i])))
	if not passed:
		inner.add_child(Style.ui.wrapped(String(result.guidance[0]), 15, Style.PAPER))
	return panel


func _week_card(entry: Dictionary) -> PanelContainer:
	var client: RefCounted = game.client(entry.id)
	var parts: Array = Widgets.card("", 0.9)
	var panel: PanelContainer = parts[0]
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var inner: VBoxContainer = parts[1]
	var top: HBoxContainer = Style.ui.hbox(12)
	inner.add_child(top)
	top.add_child(_title(entry.id, entry.name))
	top.add_child(Style.ui.spacer())
	if entry.own_sessions > 0:
		var share: int = int(round(entry.motivation_factor * 100.0))
		var alone: String = "Trained alone %d times from their routine at half value" % entry.own_sessions
		if share < 100:
			alone += ", and only %d%% of that with motivation this low" % share
		top.add_child(Charts.pips(int(entry.own_sessions), int(entry.own_sessions), Style.GREEN if share >= 100 else Style.AMBER, alone))
	var body: HBoxContainer = Style.ui.hbox(16)
	inner.add_child(body)
	var after: float = entry.readiness_after
	var gain: float = after - entry.readiness_before
	var gauge: VBoxContainer = Style.ui.vbox(2)
	gauge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	body.add_child(gauge)
	gauge.add_child(Widgets.readiness_ring(after, 0.0, 96.0, entry.readiness_before))
	if gain >= 0.5:
		var delta: Label = Style.ui.utility("%+d" % int(round(gain)), 22, Style.GREEN)
		delta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		gauge.add_child(delta)
	var bars: VBoxContainer = Style.ui.vbox(2)
	bars.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	body.add_child(bars)
	var rows: Array = []
	for key in Catalog.ATTRIBUTES:
		var gained: float = float(entry.background.get(key, 0.0))
		if gained >= 0.05:
			var now: float = float(client.attributes[key])
			rows.append({"label": Charts.short_name(game.catalog, key), "before": now - gained, "after": now, "mark": float(client.def.requirements[key]), "fine": true, "tip": "%s +%.1f" % [game.catalog.attribute_name(key), gained]})
	rows.append({"icon": "fatigue", "before": entry.fatigue_before, "after": entry.fatigue_after, "lower_is_better": true, "colour": Style.AMBER, "tip": "Fatigue after %d rest day%s: %d → %d" % [entry.rest_days, "" if entry.rest_days == 1 else "s", int(round(entry.fatigue_before)), int(round(entry.fatigue_after))]})
	bars.add_child(Charts.change_rows(game.catalog, rows, 260.0))
	var summary_text: String = "Readiness %d → %d%%" % [int(round(entry.readiness_before)), int(round(after))]
	panel.tooltip_text = summary_text
	_flags(inner, entry)
	return panel


## Anything that went wrong this week, in a few words.
func _flags(inner: VBoxContainer, entry: Dictionary) -> void:
	if entry.sat_out:
		inner.add_child(Style.ui.label("Resting an injury", 15, Style.AMBER))
	elif entry.skipped:
		inner.add_child(Style.ui.label("No coached session: motivation dipped", 15, Style.AMBER))
	if entry.injured_next_week:
		inner.add_child(Style.ui.label("× Out next week", 15, Style.RED))
