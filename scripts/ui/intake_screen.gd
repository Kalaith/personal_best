extends Control
## A new client walks in the door: they cross the shed to the desk, tell you
## what they want in their own words, then you run the intake assessment
## and see exactly where they start against what their goal needs.
const Balance = preload("res://addons/hatchery/core/balance.gd")
const Style = preload("res://scripts/ui/style.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
const GymView = preload("res://scripts/ui/gym_view.gd")
const Readiness = preload("res://scripts/core/readiness.gd")
const Charts = preload("res://scripts/ui/charts.gd")

signal accepted

var game: RefCounted
var client: RefCounted
var order: int = 0
var _view: GymView
var _talk: VBoxContainer
var _speech: Label
var _next: Button
var _line: int = -1
var _lower: VBoxContainer
var _subtitle: Label


func setup(owner: RefCounted, state: RefCounted, index: int) -> void:
	game = owner
	client = state
	order = index


func _ready() -> void:
	var column: VBoxContainer = Style.screen(self, 10, 24)
	var event: String = Balance.value("event.name")
	var first: String = "Your first client" if order == 0 else "Another client"
	column.add_child(Style.ui.heading("%s walks in" % first, 30))
	_subtitle = Style.ui.label("The %s is twelve weeks away. The shed is small, but it's yours." % event, 16, Style.MUTED)
	column.add_child(_subtitle)
	_view = GymView.new()
	_view.custom_minimum_size = Vector2(0, 330)
	_view.owned = game.owned
	_view.show_desk = true
	_view.rain = game.bad_weather()
	_view.look = client.def.look
	_view.set_activity("shed", "walk", 1.0)
	column.add_child(_view)
	_lower = Style.ui.vbox(10)
	_lower.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_lower)
	_talk = Style.ui.vbox(10)
	_lower.add_child(_talk)
	var parts: Array = Widgets.card("")
	_talk.add_child(parts[0])
	_speech = Style.ui.wrapped("The door creaks open…", 20, Style.PAPER)
	_speech.custom_minimum_size.y = 64
	parts[1].add_child(_speech)
	_next = Style.ui.button("…", _advance, true)
	_next.disabled = true
	_next.size_flags_horizontal = Control.SIZE_SHRINK_END
	_talk.add_child(_next)
	_view.arrived.connect(_on_arrived)
	_view.walk(0.92, 0.6, 2.6)


func _on_arrived() -> void:
	_next.disabled = false
	_next.grab_focus()
	_advance()


func _advance() -> void:
	_line += 1
	var lines: Array = client.def.intro
	if _line < lines.size():
		_speech.text = "%s: \"%s\"" % [client.def.short, lines[_line]]
		_next.text = "Go on" if _line < lines.size() - 1 else "Run the intake assessment"
		if _line == lines.size() - 1:
			_view.set_activity("shed", "wave", 0.5)
		return
	_view.set_activity("shed", "stand", 0.0)
	_show_assessment()


func _show_assessment() -> void:
	_talk.queue_free()
	_subtitle.hide()
	_view.custom_minimum_size = Vector2(0, 170)
	var row: HBoxContainer = Style.ui.hbox(16)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lower.add_child(row)
	row.add_child(_about_card())
	row.add_child(_start_card())
	var go: Button = Style.ui.button("Take %s on" % client.def.short, func() -> void: accepted.emit(), true)
	go.size_flags_horizontal = Control.SIZE_SHRINK_END
	_lower.add_child(go)
	go.grab_focus.call_deferred()


## Who they are: one line of life, the assessment, the goal, then chips for
## personality, experience, days, solo sessions and fee.
func _about_card() -> PanelContainer:
	var about: Array = Widgets.card("%s, %d" % [client.def.name, int(client.def.age)])
	about[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var info: VBoxContainer = about[1]
	info.add_child(Style.ui.wrapped(client.def.life, 17, Style.PAPER))
	info.add_child(Style.ui.wrapped(client.def.intake, 16, Style.MUTED))
	var goal: String = game.catalog.targets[client.def.target.type].describe.format({"cutoff": Readiness.format_minutes(Balance.number("event.cutoff_minutes")), "time": Readiness.format_minutes(float(client.def.target.minutes))})
	info.add_child(Style.rich("[b]Goal:[/b] %s" % goal, 18))
	var personality: Dictionary = game.catalog.personalities[client.def.personality]
	var chips: HFlowContainer = HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 10)
	chips.add_theme_constant_override("v_separation", 8)
	info.add_child(chips)
	chips.add_child(Charts.chip(personality.name, Style.ACCENT, "%s: %s" % [personality.name, personality.about]))
	var experience: String = String(client.def.experience)
	chips.add_child(Charts.pips({"none": 0, "some": 1}.get(experience, 2), 3, Style.ACCENT, "Running experience: %s" % experience))
	for day in client.def.available_days:
		chips.add_child(Charts.chip(day, Style.HOLD, "Free for one coached session a week"))
	chips.add_child(Charts.pips(int(client.def.own_sessions_per_week), int(client.def.own_sessions_per_week), Style.GREEN, "Trains alone %d times a week" % int(client.def.own_sessions_per_week)))
	var fee: HBoxContainer = Style.ui.hbox(6)
	fee.add_child(Charts.icon_control("coin", 22.0, Style.AMBER))
	fee.add_child(Style.ui.utility("$%d" % game.session_fee(client), 18, Style.GREEN))
	fee.tooltip_text = "Pays $%d a session" % game.session_fee(client)
	chips.add_child(fee)
	return about[0]


## Where they start: the radar of attributes against what the goal needs, and
## readiness against the first test.
func _start_card() -> PanelContainer:
	var stats: Array = Widgets.card("%s's start" % client.def.short)
	var body: HBoxContainer = Style.ui.hbox(18)
	stats[1].add_child(body)
	var values: Dictionary = {}
	for attribute in client.attributes:
		values[attribute] = client.attributes[attribute]
	body.add_child(Charts.radar(game.catalog, values, client.def.requirements, 290.0, "The shape is where %s stands; the white line is what the goal needs. Green dots are needs already met." % client.def.short))
	var gauge: VBoxContainer = Style.ui.vbox(6)
	gauge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	body.add_child(gauge)
	var threshold: float = float(game.next_milestone().get("threshold", 0))
	gauge.add_child(Widgets.readiness_ring(Readiness.readiness(client), threshold, 128.0))
	gauge.add_child(Style.ui.label("Readiness", 16, Style.MUTED))
	var test: HBoxContainer = Style.ui.hbox(6)
	test.add_child(Charts.icon_control("diamond", 18.0, Style.PAPER))
	test.add_child(Style.ui.utility("%d%%" % int(threshold), 16))
	test.tooltip_text = "The first mini goal needs %d%% readiness." % int(threshold)
	gauge.add_child(test)
	return stats[0]
