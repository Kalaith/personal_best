extends Control
## The weekly planner: where each client stands, what the week holds (block,
## weather, the next mini goal), booking this week's coached sessions,
## routines and the shop. Starting the week plays the booked sessions.
const Balance = preload("res://addons/hatchery/core/balance.gd")
const Style = preload("res://scripts/ui/style.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
const Readiness = preload("res://scripts/core/readiness.gd")
const RoutineRules = preload("res://scripts/core/routine_rules.gd")
const WeekRules = preload("res://scripts/core/week_rules.gd")

signal edit_routine(state: RefCounted)
signal open_shop
signal book(state: RefCounted, day: String)
signal start_week
signal quit_to_title
signal settings_requested

var game: RefCounted
var arrived: Array = []
var notice: String = ""


func setup(owner: RefCounted, deliveries: Array, message: String) -> void:
	game = owner
	arrived = deliveries
	notice = message


func _ready() -> void:
	var column: VBoxContainer = Style.screen(self, 10, 22)
	column.add_child(_header())
	var block: Dictionary = game.block()
	column.add_child(Style.ui.wrapped("%s block: %s" % [block.name, game.catalog.lines.blocks[block.id]], 14, Style.PAPER))
	var milestone: Dictionary = game.next_milestone()
	if not milestone.is_empty():
		var when: String = "this week" if int(milestone.week) == game.week else "at the end of week %d" % int(milestone.week)
		column.add_child(Style.ui.label("Next mini goal %s: %s (readiness %d%%)." % [when, milestone.name, int(milestone.threshold)], 15, Style.ACCENT))
	else:
		column.add_child(Style.ui.label("Race week. The %s is at the end of this week." % Balance.value("event.name"), 16, Style.ACCENT))
	for item in arrived:
		column.add_child(Style.ui.label("Delivered: %s is set up in the shed." % item, 14, Style.GREEN))
	if not notice.is_empty():
		column.add_child(Style.ui.wrapped(notice, 14, Style.AMBER))
	var cards: HBoxContainer = Style.ui.hbox(14)
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(cards)
	for state in game.clients:
		cards.add_child(_client_card(state))
	column.add_child(_footer())


func _header() -> HBoxContainer:
	var row: HBoxContainer = Style.ui.hbox(22)
	row.add_child(Style.ui.heading("Week %d of %d" % [game.week, Balance.integer("campaign.weeks")], 30))
	row.add_child(Style.ui.spacer())
	var weather: Dictionary = game.weather_kind()
	var forecast: String = "Forecast: %s" % weather.name
	if weather.bad:
		forecast += " (outdoor runs lose value%s)" % (", but the treadmill covers it" if game.has_effect("weatherproof_runs") else "")
	row.add_child(Style.ui.label(forecast, 15, Style.AMBER if weather.bad else Style.PAPER))
	row.add_child(Style.ui.utility("$%d" % game.cash, 22, Style.GREEN))
	var per_level: int = Balance.integer("income.rep_points_per_level")
	var rep: Label = Style.ui.label("Reputation %d  (%d/%d)" % [game.reputation(), game.rep_points % per_level, per_level], 15)
	rep.tooltip_text = "Passing a mini goal earns 1 point; a client reaching their marathon goal earns %d. Every %d points is a reputation level." % [Balance.integer("income.rep_points_major"), per_level]
	rep.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(rep)
	return row


func _client_card(state: RefCounted) -> PanelContainer:
	var parts: Array = Widgets.card(state.def.name)
	var panel: PanelContainer = parts[0]
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column: VBoxContainer = parts[1]
	var goal: String = String(game.catalog.targets[state.def.target.type].describe).format({"cutoff": Readiness.format_minutes(Balance.number("event.cutoff_minutes")), "time": Readiness.format_minutes(float(state.def.target.minutes))})
	column.add_child(Style.ui.label("Goal: " + goal, 14, Style.MUTED))
	column.add_child(Widgets.readiness_bar(Readiness.readiness(state), float(game.next_milestone().get("threshold", 90)), 160.0))
	if game.week >= Balance.integer("event.projection_from_week"):
		column.add_child(_projection(state))
	var conditions: HBoxContainer = Style.ui.hbox(12)
	column.add_child(conditions)
	conditions.add_child(Widgets.condition("Fatigue", state.fatigue, Style.RED if state.fatigue >= 50.0 else Style.AMBER, "Carried into the next session: lower starting energy, a faster bar and less progress."))
	conditions.add_child(Widgets.condition("Motivation", state.motivation, Style.GREEN, "How much they get from training alone between sessions."))
	column.add_child(Widgets.condition("Rapport", state.rapport, Color("9cc4e4"), "Widens the target zones in sessions. Grows with good coaching calls."))
	column.add_child(Style.ui.label("Routine", 16, Style.ACCENT))
	for entry in state.routine:
		column.add_child(Style.ui.label("•  " + RoutineRules.describe(entry, game.catalog), 14))
	var stale: bool = state.routine_block != game.block().id
	var edit: Button = Style.ui.button("Review routine for the %s block" % game.block().name if stale else "Edit routine", func() -> void: edit_routine.emit(state), stale, 15)
	column.add_child(edit)
	column.add_child(_booking(state))
	var history: Array = state.milestones.map(func(m: Dictionary) -> String: return "%s %s" % ["+" if m.passed else "×", m.name])
	if not history.is_empty():
		column.add_child(Style.ui.wrapped("  ".join(history), 13))
	return panel


## The finishing range if the race were today, so race week holds no surprise.
func _projection(state: RefCounted) -> Label:
	var projection: Dictionary = Readiness.projection(state)
	var verdicts: Dictionary = {
		"on_track": ["on track for the goal", Style.GREEN],
		"in_reach": ["the goal is in reach on a good day", Style.AMBER],
		"not_yet": ["not yet on goal pace", Style.RED],
		"withdraw": ["not ready to finish yet", Style.RED],
	}
	var verdict: Array = verdicts[projection.verdict]
	var range_text: String = "%s to %s" % [Readiness.format_minutes(projection.low), Readiness.format_minutes(projection.high)]
	var tired: String = " Fatigue %d is costing time; a taper wins it back." % int(round(state.fatigue)) if state.fatigue >= 30.0 else ""
	if projection.niggle:
		tired += " Still injured: that costs %d%% readiness until it heals." % int(round(Readiness.NIGGLE_PENALTY * 100.0))
	var line: Label = Style.ui.wrapped("Race today: %s, %s.%s" % [range_text, verdict[0], tired], 14, verdict[1])
	line.tooltip_text = "Today's readiness and fatigue turned into a finishing time, with race-day luck either way. Better Pacing Knowledge narrows the range; a taper removes the fatigue penalty."
	line.mouse_filter = Control.MOUSE_FILTER_PASS
	return line


func _booking(state: RefCounted) -> VBoxContainer:
	var column: VBoxContainer = Style.ui.vbox(4)
	if not state.is_available(game.week):
		column.add_child(Style.ui.wrapped("Not available this week: %s." % state.unavailable_reason(game.week), 14, Style.AMBER))
		return column
	column.add_child(Style.ui.label("Book this week's session", 15, Style.ACCENT))
	var row: HBoxContainer = Style.ui.hbox(6)
	column.add_child(row)
	for day in Balance.list("campaign.days"):
		var open: bool = WeekRules.booking_problem(game, state, day).is_empty()
		var chosen: bool = state.booked_day == day
		var button: Button = Style.ui.button(day, func() -> void: book.emit(state, "" if chosen else day), chosen, 15)
		button.custom_minimum_size = Vector2(62, 40)
		button.disabled = not open
		if chosen:
			button.text = "+ " + day
		row.add_child(button)
	var status: String = "Booked for %s. Fee $%d." % [state.booked_day, game.session_fee(state)] if not state.booked_day.is_empty() else "Not booked: skipping a week costs motivation."
	column.add_child(Style.ui.label(status, 13, Style.MUTED if state.booked_day.is_empty() else Style.GREEN))
	return column


func _footer() -> HBoxContainer:
	var row: HBoxContainer = Style.ui.hbox(12)
	row.add_child(Style.ui.button("Title", func() -> void: quit_to_title.emit(), false, 15))
	row.add_child(Style.ui.button("Settings", func() -> void: settings_requested.emit(), false, 15))
	var pending: String = "" if game.pending.is_empty() else ", %d arriving" % game.pending.size()
	row.add_child(Style.ui.button("Shop  (slots %d/%d%s)" % [game.slots_used(), game.slots_total(), pending], func() -> void: open_shop.emit()))
	row.add_child(Style.ui.label("Clients %d/%d" % [game.clients.size(), game.capacity()], 14, Style.MUTED))
	row.add_child(Style.ui.spacer())
	if not game.notes.is_empty():
		row.add_child(Style.ui.label(game.notes.back(), 13, Style.MUTED))
	var booked: int = WeekRules.sessions(game).size()
	var label: String = "Start week %d  (%d session%s)" % [game.week, booked, "" if booked == 1 else "s"]
	var start: Button = Style.ui.button(label, func() -> void: start_week.emit(), true)
	row.add_child(start)
	start.grab_focus.call_deferred()
	return row
