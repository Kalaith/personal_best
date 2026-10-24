extends Control
## The end of the season: both clients' journeys side by side, so the player can
## see how differently they needed coaching toward the same race. Each journey is
## a readiness line across the twelve weeks (a dot per mini goal) and the shape
## their attributes finished in against what the goal needed.
const Balance = preload("res://addons/hatchery/core/balance.gd")
const Style = preload("res://scripts/ui/style.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
const GymView = preload("res://scripts/ui/gym_view.gd")
const Charts = preload("res://scripts/ui/charts.gd")
const Portrait = preload("res://scripts/ui/portrait.gd")

signal new_requested
signal title_requested

var game: RefCounted
var results: Array = []


func setup(owner: RefCounted, race_results: Array) -> void:
	game = owner
	results = race_results


func _ready() -> void:
	var column: VBoxContainer = Style.screen(self, 12, 28)
	var achieved: int = results.filter(func(r: Dictionary) -> bool: return r.achieved).size()
	var header: HBoxContainer = Style.ui.hbox(22)
	column.add_child(header)
	header.add_child(Style.ui.heading("Season complete: %d/%d goals" % [achieved, results.size()], 34))
	header.add_child(Style.ui.spacer())
	var cash: HBoxContainer = Style.ui.hbox(6)
	cash.add_child(Charts.icon_control("coin", 28.0, Style.AMBER))
	cash.add_child(Style.ui.utility("%d" % game.cash, 24, Style.GREEN))
	header.add_child(cash)
	var rep: HBoxContainer = Style.ui.hbox(6)
	rep.add_child(Charts.icon_control("star", 28.0, Style.AMBER))
	rep.add_child(Style.ui.utility("%d" % game.reputation(), 24))
	rep.tooltip_text = "Reputation. %d pieces of kit in the shed." % game.owned.size()
	rep.mouse_filter = Control.MOUSE_FILTER_PASS
	header.add_child(rep)
	var view := GymView.new()
	view.custom_minimum_size = Vector2(0, 130)
	view.owned = game.owned
	view.look = game.clients[0].def.look if achieved > 0 else {}
	view.client_x = 0.66
	view.set_activity("shed", "wave", 0.6)
	column.add_child(view)
	var cards: HBoxContainer = Style.ui.hbox(14)
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(cards)
	for result in results:
		cards.add_child(_journey(result))
	column.add_child(Style.ui.wrapped("Same race, same twelve weeks, different people. This prototype ends here.", 16))
	var buttons: HBoxContainer = Style.ui.hbox(12)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(buttons)
	buttons.add_child(Style.ui.button("Title", func() -> void: title_requested.emit()))
	var again: Button = Style.ui.button("Coach a new season", func() -> void: new_requested.emit(), true)
	buttons.add_child(again)
	again.grab_focus.call_deferred()


func _journey(result: Dictionary) -> PanelContainer:
	var client: RefCounted = game.client(result.client)
	var parts: Array = Widgets.card("", 0.92)
	var panel: PanelContainer = parts[0]
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var inner: VBoxContainer = parts[1]
	var top: HBoxContainer = Style.ui.hbox(10)
	inner.add_child(top)
	var face := Portrait.new()
	face.look = client.def.look
	face.ready.connect(func() -> void: face.custom_minimum_size = Vector2(52, 52))
	top.add_child(face)
	top.add_child(Style.ui.heading(client.def.short, 24))
	top.add_child(Style.ui.spacer())
	var personality: Dictionary = game.catalog.personalities[client.def.personality]
	top.add_child(Charts.chip(personality.name, Style.ACCENT, "Responded best to %s encouragement. %s" % [personality.approach, personality.about]))
	var outcome: HBoxContainer = Style.ui.hbox(8)
	inner.add_child(outcome)
	var made: bool = bool(result.achieved)
	outcome.add_child(Charts.icon_control("check" if made else "cross", 28.0, Style.GREEN if made else Style.AMBER))
	var finish: String = "Withdrew" if result.withdrew else String(result.time)
	outcome.add_child(Style.ui.heading(finish, 26, Style.GREEN if made else Style.AMBER))
	outcome.add_child(Style.ui.spacer())
	var earned: HBoxContainer = Style.ui.hbox(6)
	earned.add_child(Charts.icon_control("coin", 24.0, Style.AMBER))
	earned.add_child(Style.ui.utility("%d" % (client.fees_paid + client.bonuses_paid), 18, Style.GREEN))
	earned.tooltip_text = "Coached %d sessions: $%d in fees and $%d in bonuses." % [client.sessions_done, client.fees_paid, client.bonuses_paid]
	earned.mouse_filter = Control.MOUSE_FILTER_PASS
	outcome.add_child(earned)
	var body: HBoxContainer = Style.ui.hbox(8)
	inner.add_child(body)
	var line: Control = Charts.journey(_points(client, made), 260.0, "Readiness each week. Dots mark the mini goals (green passed, red missed); the dashed line is 90%, where the goal time is in reach.")
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(line)
	var values: Dictionary = {}
	for attribute in client.attributes:
		values[attribute] = client.attributes[attribute]
	body.add_child(Charts.radar(game.catalog, values, client.def.requirements, 230.0, "Where they finished (shape) against what the goal needed (white line)."))
	return panel


## Readiness at intake and at the end of every week; a mini goal's week
## carries its result and the last point is the race.
func _points(client: RefCounted, achieved: bool) -> Array:
	var points: Array = [{"week": 0, "value": _intake(client)}]
	for i in range(client.readiness_history.size()):
		points.append({"week": i + 1, "value": float(client.readiness_history[i])})
	for milestone in client.milestones:
		for point in points:
			if int(point.week) == int(milestone.week):
				point["passed"] = bool(milestone.passed)
	points.back()["passed"] = achieved
	return points


## Readiness when they walked in, from their catalog entry's attributes.
func _intake(client: RefCounted) -> float:
	var weights: Dictionary = Balance.dict("readiness.weights")
	var total: float = 0.0
	for key in weights:
		total += float(weights[key]) * clampf(float(client.def.attributes[key]) / float(client.def.requirements[key]), 0.0, 1.0)
	return total * 100.0
