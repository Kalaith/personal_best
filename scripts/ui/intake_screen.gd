extends Control
## A new client walks in the door: they cross the shed to the desk, tell you
## what they want in their own words, then you run the intake assessment
## and see exactly where they start against what their goal needs.
const Balance = preload("res://addons/hatchery/core/balance.gd")
const Style = preload("res://scripts/ui/style.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
const GymView = preload("res://scripts/ui/gym_view.gd")
const Readiness = preload("res://scripts/core/readiness.gd")

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


func setup(owner: RefCounted, state: RefCounted, index: int) -> void:
	game = owner
	client = state
	order = index


func _ready() -> void:
	var column: VBoxContainer = Style.screen(self, 10, 24)
	var event: String = Balance.value("event.name")
	var first: String = "Your first client" if order == 0 else "Another client"
	column.add_child(Style.ui.heading("%s walks in" % first, 30))
	column.add_child(Style.ui.label("The %s is twelve weeks away. The shed is small, but it's yours." % event, 16, Style.MUTED))
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
	_view.custom_minimum_size = Vector2(0, 170)
	var row: HBoxContainer = Style.ui.hbox(16)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lower.add_child(row)
	var about: Array = Widgets.card("%s, %d" % [client.def.name, int(client.def.age)])
	about[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(about[0])
	var info: VBoxContainer = about[1]
	info.add_child(Style.ui.wrapped(client.def.life, 15, Style.PAPER))
	info.add_child(Style.ui.wrapped("Assessment: " + client.def.intake, 15))
	var goal: String = game.catalog.targets[client.def.target.type].describe.format({"cutoff": Readiness.format_minutes(Balance.number("event.cutoff_minutes")), "time": Readiness.format_minutes(float(client.def.target.minutes))})
	info.add_child(Style.rich("[b]Goal:[/b] %s." % goal, 16))
	var personality: Dictionary = game.catalog.personalities[client.def.personality]
	info.add_child(Style.rich("[b]Personality:[/b] %s. %s" % [personality.name, personality.about], 15))
	info.add_child(Style.rich("[b]Experience:[/b] %s.  [b]Available:[/b] %s, one coached session a week. Trains alone %d times a week." % [String(client.def.experience).capitalize(), " / ".join(client.def.available_days), int(client.def.own_sessions_per_week)], 15))
	info.add_child(Style.rich("[b]Pays:[/b] $%d a session." % game.session_fee(client), 15))
	var stats: Array = Widgets.card("Where %s starts" % client.def.short)
	row.add_child(stats[0])
	var column: VBoxContainer = stats[1]
	column.add_child(Widgets.attribute_table(client, game.catalog))
	column.add_child(Widgets.readiness_bar(Readiness.readiness(client), float(game.next_milestone().get("threshold", 0)), 200.0))
	column.add_child(Style.ui.wrapped("The line on each bar is what %s's goal needs. Readiness counts each attribute up to that line: 45%% Endurance, 20%% Pace, 15%% Strength, 10%% Recovery, 10%% Pacing Knowledge." % client.def.short, 13))
	var go: Button = Style.ui.button("Take %s on: plan the first routine" % client.def.short, func() -> void: accepted.emit(), true)
	go.size_flags_horizontal = Control.SIZE_SHRINK_END
	_lower.add_child(go)
	go.grab_focus.call_deferred()
