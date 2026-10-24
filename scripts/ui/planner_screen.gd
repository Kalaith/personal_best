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
const Charts = preload("res://scripts/ui/charts.gd")
const Catalog = preload("res://scripts/core/catalog.gd")

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
	column.add_child(Widgets.season_strip(game, 400.0))
	for item in arrived:
		column.add_child(Style.ui.label("Delivered: %s" % item, 14, Style.GREEN))
	if not notice.is_empty():
		column.add_child(Style.ui.wrapped(notice, 14, Style.AMBER))
	# Late in the season the cards outgrow the screen; they scroll and the
	# footer stays put.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var cards: HBoxContainer = Style.ui.hbox(14)
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(cards)
	for state in game.clients:
		cards.add_child(_client_card(state))
	column.add_child(_footer())


func _header() -> HBoxContainer:
	var row: HBoxContainer = Style.ui.hbox(22)
	row.add_child(Style.ui.heading("Week %d/%d" % [game.week, Balance.integer("campaign.weeks")], 30))
	row.add_child(Style.ui.spacer())
	var weather: Dictionary = game.weather_kind()
	var forecast: String = "Forecast: %s" % weather.name
	if weather.bad:
		forecast += " (outdoor runs lose value%s)" % (", but the treadmill covers it" if game.has_effect("weatherproof_runs") else "")
	row.add_child(Charts.weather_icon(game.weather, 34.0, forecast))
	var cash: HBoxContainer = Style.ui.hbox(6)
	cash.add_child(Charts.icon_control("coin", 26.0, Style.AMBER))
	cash.add_child(Style.ui.utility("%d" % game.cash, 22, Style.GREEN))
	row.add_child(cash)
	var per_level: int = Balance.integer("income.rep_points_per_level")
	var rep: HBoxContainer = Style.ui.hbox(6)
	rep.add_child(Charts.icon_control("star", 26.0, Style.AMBER))
	rep.add_child(Style.ui.utility("%d" % game.reputation(), 22))
	rep.add_child(Charts.pips(game.rep_points % per_level, per_level, Style.AMBER))
	rep.tooltip_text = "Reputation %d. Passing a mini goal earns 1 point; a client reaching their marathon goal earns %d. Every %d points is a reputation level." % [game.reputation(), Balance.integer("income.rep_points_major"), per_level]
	rep.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(rep)
	return row


func _client_card(state: RefCounted) -> PanelContainer:
	var parts: Array = Widgets.card(state.def.short)
	var panel: PanelContainer = parts[0]
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column: VBoxContainer = parts[1]
	var goal: String = String(game.catalog.targets[state.def.target.type].describe).format({"cutoff": Readiness.format_minutes(Balance.number("event.cutoff_minutes")), "time": Readiness.format_minutes(float(state.def.target.minutes))})
	column.add_child(Style.ui.label(goal, 15, Style.MUTED))
	var status: HBoxContainer = Style.ui.hbox(18)
	column.add_child(status)
	var threshold: float = float(game.next_milestone().get("threshold", 90))
	status.add_child(Widgets.readiness_ring(Readiness.readiness(state), threshold, 104.0))
	var gauges: VBoxContainer = Style.ui.vbox(6)
	gauges.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status.add_child(gauges)
	if game.week >= Balance.integer("event.projection_from_week"):
		gauges.add_child(_projection(state))
	gauges.add_child(Charts.meter("fatigue", state.fatigue, Style.RED if state.fatigue >= 50.0 else Style.AMBER, "Fatigue %d: carried into the next session (lower energy, less progress)." % int(round(state.fatigue)), 150.0))
	gauges.add_child(Charts.meter("motivation", state.motivation, Style.GREEN, "Motivation %d: how much they get from training alone." % int(round(state.motivation)), 150.0))
	gauges.add_child(Charts.meter("rapport", state.rapport, Color("9cc4e4"), "Rapport %d: widens the target zones in sessions." % int(round(state.rapport)), 150.0))
	for entry in state.routine:
		column.add_child(_routine_row(entry))
	var stale: bool = state.routine_block != game.block().id
	var edit: Button = Style.ui.button("New block: review" if stale else "Edit routine", func() -> void: edit_routine.emit(state), stale, 15)
	column.add_child(edit)
	column.add_child(_booking(state))
	return panel


## One routine entry as a line: name, sets, and the load as dots (or kg).
func _routine_row(entry: Dictionary) -> HBoxContainer:
	var def: Dictionary = game.catalog.exercise(entry.exercise)
	var row: HBoxContainer = Style.ui.hbox(10)
	var name: Label = Style.ui.label(def.name, 16)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.clip_text = true
	row.add_child(name)
	row.add_child(Style.ui.utility("%d×" % int(entry.sets), 16, Style.MUTED))
	if def.load_kind == "kg":
		var kg: Label = Style.ui.utility("%d kg" % int(entry.kg), 16)
		kg.custom_minimum_size.x = 64
		row.add_child(kg)
	else:
		var level: int = Catalog.LOADS.find(entry.load) + 1
		var colour: Color = [Style.GREEN, Style.AMBER, Style.RED][level - 1]
		var pips: Control = Charts.pips(level, 3, colour, "Load: %s" % String(entry.load).capitalize())
		pips.custom_minimum_size.x = 64
		row.add_child(pips)
	return row


## The finishing range if the race were today, so race week holds no surprise:
## a verdict mark and the two times, with the full sentence in the tooltip.
func _projection(state: RefCounted) -> HBoxContainer:
	var projection: Dictionary = Readiness.projection(state)
	var verdicts: Dictionary = {
		"on_track": ["check", "On track for the goal.", Style.GREEN],
		"in_reach": ["diamond", "The goal is in reach on a good day.", Style.AMBER],
		"not_yet": ["cross", "Not yet on goal pace.", Style.RED],
		"withdraw": ["cross", "Not ready to finish yet.", Style.RED],
	}
	var verdict: Array = verdicts[projection.verdict]
	var tired: String = " Fatigue %d is costing time; a taper wins it back." % int(round(state.fatigue)) if state.fatigue >= 30.0 else ""
	if projection.niggle:
		tired += " Still injured: that costs %d%% readiness until it heals." % int(round(Readiness.NIGGLE_PENALTY * 100.0))
	var row: HBoxContainer = Style.ui.hbox(8)
	row.add_child(Charts.icon_control(verdict[0], 24.0, verdict[2]))
	row.add_child(Style.ui.utility("%s–%s" % [Readiness.format_minutes(projection.low), Readiness.format_minutes(projection.high)], 18, verdict[2]))
	row.tooltip_text = "Race today: %s to %s. %s%s Today's readiness and fatigue turned into a finishing time, with race-day luck either way." % [Readiness.format_minutes(projection.low), Readiness.format_minutes(projection.high), verdict[1], tired]
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	return row


func _booking(state: RefCounted) -> VBoxContainer:
	var column: VBoxContainer = Style.ui.vbox(4)
	if not state.is_available(game.week):
		column.add_child(Style.ui.wrapped("Away: %s." % state.unavailable_reason(game.week), 14, Style.AMBER))
		return column
	var row: HBoxContainer = Style.ui.hbox(6)
	row.tooltip_text = "Book this week's coached session. Skipping a week costs motivation."
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(row)
	for day in Balance.list("campaign.days"):
		var open: bool = WeekRules.booking_problem(game, state, day).is_empty()
		var chosen: bool = state.booked_day == day
		var button: Button = Style.ui.button(day, func() -> void: book.emit(state, "" if chosen else day), chosen, 15)
		button.custom_minimum_size = Vector2(72, 48)
		button.disabled = not open
		if chosen:
			button.text = "+ " + day
		row.add_child(button)
	if not state.booked_day.is_empty():
		var fee: HBoxContainer = Style.ui.hbox(4)
		fee.add_child(Charts.icon_control("coin", 20.0, Style.AMBER))
		fee.add_child(Style.ui.utility("%d" % game.session_fee(state), 16, Style.GREEN))
		row.add_child(fee)
	return column


func _footer() -> HBoxContainer:
	var row: HBoxContainer = Style.ui.hbox(12)
	row.add_child(Style.ui.button("Title", func() -> void: quit_to_title.emit(), false, 15))
	row.add_child(Style.ui.button("Settings", func() -> void: settings_requested.emit(), false, 15))
	var shop: Button = Style.ui.button("Shop %d/%d" % [game.slots_used(), game.slots_total()], func() -> void: open_shop.emit())
	shop.tooltip_text = "Kit slots used%s" % ("" if game.pending.is_empty() else ", %d arriving" % game.pending.size())
	row.add_child(shop)
	var seats: Control = Charts.pips(game.clients.size(), game.capacity(), Style.MUTED, "Clients %d of %d" % [game.clients.size(), game.capacity()])
	row.add_child(seats)
	row.add_child(Style.ui.spacer())
	var booked: int = WeekRules.sessions(game).size()
	var label: String = "Start week %d" % game.week if booked > 0 else "Start week %d (rest week)" % game.week
	var start: Button = Style.ui.button(label, func() -> void: start_week.emit(), true)
	row.add_child(start)
	start.grab_focus.call_deferred()
	return row
