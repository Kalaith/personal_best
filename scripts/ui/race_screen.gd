extends Control
## Race day for one client: there is no playable race, just the result and why
## it happened. The finish sits on a time line against the goal, inside the band
## race-day luck allows; a ring shows readiness on the start line (and what
## fatigue took off it); the moments that decided it are icon lines; payment is
## a bar and three amounts.
const Style = preload("res://scripts/ui/style.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
const GymView = preload("res://scripts/ui/gym_view.gd")
const Charts = preload("res://scripts/ui/charts.gd")

signal continued

## Readiness around which the goal time comes within reach.
const REACH_MARK: float = 90.0
const FEES := Color("6fa8dc")
const MINI := Color("e0a43a")
const MARATHON := Color("7fcf6a")

var game: RefCounted
var result: Dictionary


func setup(owner: RefCounted, race_result: Dictionary) -> void:
	game = owner
	result = race_result


func _ready() -> void:
	var client: RefCounted = game.client(result.client)
	var column: VBoxContainer = Style.screen(self, 10, 24)
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
		verdict = "%s missed the goal" % result.client_name
		colour = Style.AMBER
	column.add_child(Style.ui.heading(verdict, 36, colour))
	var view := GymView.new()
	view.custom_minimum_size = Vector2(0, 210)
	view.look = client.def.look
	view.show_trainer = false
	view.race_day = true
	view.expression = "smile" if result.achieved else "grimace"
	view.set_activity("road", "run" if not result.withdrew else "walk", 1.2 if not result.withdrew else 0.6)
	column.add_child(view)
	var body: HBoxContainer = Style.ui.hbox(14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	body.add_child(_story_card())
	body.add_child(_side_card())
	column.add_child(Style.ui.wrapped(result.advice, 17, Style.ACCENT))
	var go: Button = Style.ui.button("Continue", func() -> void: continued.emit(), true)
	go.size_flags_horizontal = Control.SIZE_SHRINK_END
	column.add_child(go)
	go.grab_focus.call_deferred()


## The finishing time, where it landed against the goal, and what decided it.
func _story_card() -> PanelContainer:
	var story: Array = Widgets.card("", 0.92)
	story[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var inner: VBoxContainer = story[1]
	var head: HBoxContainer = Style.ui.hbox(18)
	inner.add_child(head)
	if result.withdrew:
		head.add_child(Charts.icon_control("cross", 30.0, Style.RED))
	else:
		head.add_child(Style.ui.heading(String(result.time), 34, Style.GREEN if result.achieved else Style.AMBER))
		if result.finished:
			var place: Label = Style.ui.utility("#%d of %d" % [int(result.position), int(result.field)], 18, Style.MUTED)
			place.tooltip_text = "Finishing position in the field"
			place.mouse_filter = Control.MOUSE_FILTER_PASS
			head.add_child(place)
	var predicted: float = float(result.get("predicted_minutes", result.minutes))
	var spread: float = float(result.spread)
	var tip: String = "Goal: %s. The shaded band is where race-day luck (±%.0f%%) could land the time." % [result.goal, spread * 100.0]
	inner.add_child(Charts.time_chart(predicted * (1.0 - spread), predicted * (1.0 + spread), float(result.get("goal_minutes", result.minutes)), 0.0 if result.withdrew else float(result.minutes), float(result.get("cutoff_minutes", 0.0)), 560.0, tip))
	var strong: int = result.moments.size() - 1 - (1 if result.withdrew else 0)
	for i in range(result.moments.size()):
		var kind: String = "up" if i == strong else "down"
		var tint: Color = Style.GREEN if i == strong else Style.AMBER
		if result.withdrew and i == result.moments.size() - 1:
			kind = "cross"
			tint = Style.RED
		var line: HBoxContainer = Style.ui.hbox(10)
		line.add_child(Charts.icon_control(kind, 22.0, tint))
		var text: Label = Style.ui.wrapped(String(result.moments[i]), 16, Style.PAPER)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(text)
		inner.add_child(line)
	return story[0]


## Start-line readiness, the carried fatigue, and the payment.
func _side_card() -> PanelContainer:
	var money: Array = Widgets.card("", 0.92)
	var inner: VBoxContainer = money[1]
	var ready: HBoxContainer = Style.ui.hbox(14)
	inner.add_child(ready)
	var start: float = float(result.race_readiness)
	var why: String = "\n".join(PackedStringArray(result.explain))
	ready.add_child(Charts.ring(start, REACH_MARK, 104.0, "%d%%" % int(round(start)), why, float(result.readiness)))
	var tired: VBoxContainer = Style.ui.vbox(4)
	tired.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ready.add_child(tired)
	tired.add_child(Charts.meter("fatigue", float(result.race_fatigue), Style.RED if float(result.race_fatigue) >= 30.0 else Style.AMBER, "Fatigue carried into race day: %d" % int(round(float(result.race_fatigue))), 90.0))
	if result.niggle:
		tired.add_child(Style.ui.label("× Injured", 15, Style.RED))
	var mini: int = int(result.bonuses) - int(result.bonus)
	var total: int = int(result.fees) + int(result.bonuses)
	var sum: HBoxContainer = Style.ui.hbox(8)
	sum.add_child(Charts.icon_control("coin", 28.0, Style.AMBER))
	sum.add_child(Style.ui.heading("%d" % total, 28, Style.GREEN))
	if result.rep_change != 0:
		sum.add_child(Charts.icon_control("star", 26.0, Style.AMBER))
		sum.add_child(Style.ui.utility("%+d" % int(result.rep_change), 20, Style.GREEN if result.rep_change > 0 else Style.RED))
	inner.add_child(sum)
	var parts: Array = [["Fees", result.fees, FEES], ["Mini goals", mini, MINI], ["Marathon", result.bonus, MARATHON]]
	inner.add_child(Charts.stack_bar(parts.map(func(p: Array) -> Dictionary: return {"value": p[1], "colour": p[2]}), 230.0, "The goal bonus is lost if the goal is missed; session fees are never taken back."))
	for part in parts:
		var item: HBoxContainer = Style.ui.hbox(8)
		var swatch := ColorRect.new()
		swatch.color = part[2]
		swatch.custom_minimum_size = Vector2(14, 14)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		item.add_child(swatch)
		var name: Label = Style.ui.label(part[0], 15, Style.MUTED)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item.add_child(name)
		item.add_child(Style.ui.utility("$%d" % int(part[1]), 16, Style.GREEN if int(part[1]) > 0 else Style.MUTED))
		inner.add_child(item)
	return money[0]
