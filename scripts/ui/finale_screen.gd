extends Control
## The end of the season: both clients' journeys side by side, so the
## player can see how differently they needed coaching toward the same race.
const Balance = preload("res://addons/hatchery/core/balance.gd")
const Style = preload("res://scripts/ui/style.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
const GymView = preload("res://scripts/ui/gym_view.gd")

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
	column.add_child(Style.ui.heading("Season complete: %d of %d goals reached" % [achieved, results.size()], 34))
	column.add_child(Style.ui.label("Cash $%d  ·  Reputation %d  ·  %d pieces of kit in the shed" % [game.cash, game.reputation(), game.owned.size()], 17, Style.PAPER))
	var view := GymView.new()
	view.custom_minimum_size = Vector2(0, 150)
	view.owned = game.owned
	view.look = game.clients[0].def.look if achieved > 0 else {}
	view.client_x = 0.66
	view.set_activity("shed", "wave", 0.6)
	column.add_child(view)
	# The journeys scroll when they outgrow the screen; the buttons stay put.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var body: VBoxContainer = Style.ui.vbox(12)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	var cards: HBoxContainer = Style.ui.hbox(14)
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(cards)
	for result in results:
		cards.add_child(_journey(result))
	body.add_child(Style.ui.wrapped("Same race, same twelve weeks, different people. This prototype ends here; in the full game they may come back with a new goal, and new clients will walk through the door.", 15))
	var buttons: HBoxContainer = Style.ui.hbox(12)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(buttons)
	buttons.add_child(Style.ui.button("Title", func() -> void: title_requested.emit()))
	var again: Button = Style.ui.button("Coach a new season", func() -> void: new_requested.emit(), true)
	buttons.add_child(again)
	again.grab_focus.call_deferred()


func _journey(result: Dictionary) -> PanelContainer:
	var client: RefCounted = game.client(result.client)
	var parts: Array = Widgets.card(client.def.name, 0.92)
	var panel: PanelContainer = parts[0]
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var inner: VBoxContainer = parts[1]
	var outcome: String = "Goal reached in %s" % result.time if result.achieved else ("Withdrew" if result.withdrew else "Finished in %s; goal missed" % result.time)
	inner.add_child(Style.ui.label(outcome, 18, Style.GREEN if result.achieved else Style.AMBER))
	var path: Array = ["Intake %d%%" % int(round(_intake(client)))]
	for milestone in client.milestones:
		path.append("Week %d %d%% %s" % [int(milestone.week), int(round(milestone.readiness)), "+" if milestone.passed else "×"])
	path.append("Race morning %d%%" % int(round(result.race_readiness)))
	inner.add_child(Style.ui.wrapped("  →  ".join(path), 14, Style.PAPER))
	var personality: Dictionary = game.catalog.personalities[client.def.personality]
	inner.add_child(Style.ui.wrapped("%s: responded best to %s encouragement. %s" % [personality.name, personality.approach, personality.about], 14))
	inner.add_child(Style.ui.wrapped("Coached %d sessions  ·  earned $%d in fees and $%d in bonuses." % [client.sessions_done, client.fees_paid, client.bonuses_paid], 14))
	inner.add_child(Widgets.attribute_table(client, game.catalog, 160.0))
	return panel


## Readiness when they walked in, from their catalog entry's attributes.
func _intake(client: RefCounted) -> float:
	var weights: Dictionary = Balance.dict("readiness.weights")
	var total: float = 0.0
	for key in weights:
		total += float(weights[key]) * clampf(float(client.def.attributes[key]) / float(client.def.requirements[key]), 0.0, 1.0)
	return total * 100.0
