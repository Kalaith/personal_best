extends Control
## Race day for one client: there is no playable race, just the result and
## why it happened: the moments that decided it, how their preparation
## showed, what it paid, and what it teaches for the next client like them.
const Balance = preload("res://addons/hatchery/core/balance.gd")
const Style = preload("res://scripts/ui/style.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
const GymView = preload("res://scripts/ui/gym_view.gd")

signal continued

var game: RefCounted
var result: Dictionary


func setup(owner: RefCounted, race_result: Dictionary) -> void:
	game = owner
	result = race_result


func _ready() -> void:
	var client: RefCounted = game.client(result.client)
	var column: VBoxContainer = Style.screen(self, 10, 24)
	column.add_child(Style.ui.label("%s  ·  race day" % Balance.value("event.name"), 16, Style.MUTED))
	var verdict: String
	var colour: Color = Style.GREEN
	if result.achieved:
		verdict = "%s did it!" % result.client_name
	elif result.withdrew:
		verdict = "%s withdrew at %d km" % [result.client_name, int(result.withdrew_km)]
		colour = Style.RED
	elif not result.finished:
		verdict = "%s finished after the cut-off" % result.client_name
		colour = Style.AMBER
	else:
		verdict = "%s finished, but missed the goal" % result.client_name
		colour = Style.AMBER
	column.add_child(Style.ui.heading(verdict, 36, colour))
	var view := GymView.new()
	view.custom_minimum_size = Vector2(0, 170)
	view.look = client.def.look
	view.show_trainer = false
	view.race_day = true
	view.expression = "smile" if result.achieved else "grimace"
	view.set_activity("road", "run" if not result.withdrew else "walk", 1.2 if not result.withdrew else 0.6)
	column.add_child(view)
	var line: String = "Goal: %s." % result.goal
	if not result.withdrew:
		line += "   Finishing time %s  ·  position %d of %d" % [result.time, int(result.position), int(result.field)] if result.finished else "   Crossed the line in %s, after the timing mats were packed away." % result.time
	column.add_child(Style.ui.label(line, 18, Style.PAPER))
	var body: HBoxContainer = Style.ui.hbox(14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	var story: Array = Widgets.card("How the race went", 0.92)
	story[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(story[0])
	for moment in result.moments:
		story[1].add_child(Style.ui.wrapped("•  " + moment, 15, Style.PAPER))
	story[1].add_child(Style.ui.label("Why", 16, Style.ACCENT))
	for reason in result.explain:
		story[1].add_child(Style.ui.wrapped(reason, 14))
	var money: Array = Widgets.card("Payment", 0.92)
	body.add_child(money[0])
	var mini: int = int(result.bonuses) - int(result.bonus)
	for row in [["Session fees", result.fees], ["Mini goal bonuses", mini], ["Marathon bonus", result.bonus]]:
		var item: HBoxContainer = Style.ui.hbox(16)
		var name: Label = Style.ui.label(row[0], 15)
		name.custom_minimum_size.x = 170
		item.add_child(name)
		item.add_child(Style.ui.utility("$%d" % int(row[1]), 15, Style.GREEN if int(row[1]) > 0 else Style.MUTED))
		money[1].add_child(item)
	if result.rep_change != 0:
		money[1].add_child(Style.ui.label("Reputation points %+d" % int(result.rep_change), 15, Style.GREEN if result.rep_change > 0 else Style.RED))
	if not result.achieved:
		money[1].add_child(Style.ui.wrapped("The goal bonus is lost; session fees are never taken back.", 13))
	column.add_child(Style.ui.wrapped(result.advice, 15, Style.ACCENT))
	var go: Button = Style.ui.button("Continue", func() -> void: continued.emit(), true)
	go.size_flags_horizontal = Control.SIZE_SHRINK_END
	column.add_child(go)
	go.grab_focus.call_deferred()
