extends Control
## The one coaching input: a marker sweeps back and forth along a bar and a
## single press (Space, left click or gamepad A) stops it. Zones come from
## the session rules; this control only shows them, moves the marker and
## reports where it stopped. Hidden zones (spotting a form fault) appear
## after a delay and vanish again after a window.
const Style = preload("res://scripts/ui/style.gd")

signal stopped(position: float, visible: bool)

var zones: Array = []
var pass_seconds: float = 1.6
## Background bands (pace coaching): [{name, from, to}].
var bands: Array = []
var reveal_delay: float = -1.0
var window_seconds: float = 0.0
var marker: float = 0.0
var running: bool = false
var _direction: float = 1.0
var _elapsed: float = 0.0
var _flash: float = 0.0
var _flash_color: Color = Color.WHITE
var _font: Font


func _ready() -> void:
	custom_minimum_size = Vector2(0, 120)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = get_theme_default_font()


func start(beat: Dictionary, effort_bands: Array) -> void:
	zones = beat.get("zones", [])
	pass_seconds = maxf(float(beat.get("pass_seconds", 1.6)), 0.2)
	reveal_delay = float(beat.get("reveal_delay", -1.0))
	window_seconds = float(beat.get("window_seconds", 0.0))
	bands = effort_bands if beat.get("effort_bands", false) else []
	marker = 0.0
	_direction = 1.0
	_elapsed = 0.0
	running = true
	queue_redraw()


func stop() -> void:
	if not running:
		return
	running = false
	stopped.emit(marker, zones_visible())


func flash(colour: Color) -> void:
	_flash = 1.0
	_flash_color = colour


func zones_visible() -> bool:
	if reveal_delay < 0.0:
		return true
	return _elapsed >= reveal_delay and _elapsed <= reveal_delay + window_seconds


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		stop()


func _process(delta: float) -> void:
	_flash = maxf(_flash - delta * 2.5, 0.0)
	if running:
		_elapsed += delta
		marker += _direction * delta / pass_seconds
		if marker >= 1.0:
			marker = 2.0 - marker
			_direction = -1.0
		elif marker <= 0.0:
			marker = -marker
			_direction = 1.0
	queue_redraw()


func _draw() -> void:
	var bar := Rect2(Vector2(10, 40), Vector2(size.x - 20, 44))
	draw_rect(bar.grow(3), Color("1c1612"))
	draw_rect(bar, Color("3a2f28"))
	for band in bands:
		var r := Rect2(bar.position + Vector2(bar.size.x * float(band.from), 0), Vector2(bar.size.x * (float(band.to) - float(band.from)), bar.size.y))
		draw_rect(r, Color(1, 1, 1, 0.04 if int(band.get("index", 0)) % 2 == 0 else 0.09))
		draw_string(_font, r.position + Vector2(6, r.size.y + 20), String(band.name), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 6, 13, Style.MUTED)
	if zones_visible():
		for zone in zones:
			var colour := Color(zone.color)
			var r := Rect2(bar.position + Vector2(bar.size.x * float(zone.from), 0), Vector2(bar.size.x * (float(zone.to) - float(zone.from)), bar.size.y))
			draw_rect(r, Color(colour, 0.55))
			var core := Rect2(bar.position + Vector2(bar.size.x * float(zone.perfect_from), 0), Vector2(bar.size.x * (float(zone.perfect_to) - float(zone.perfect_from)), bar.size.y))
			draw_rect(core, Color(colour.lightened(0.35), 0.9))
			var label: String = String(zone.label)
			if not label.is_empty():
				draw_string(_font, Vector2(r.position.x - 30, bar.position.y - 10), label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x + 60, 15, colour.lightened(0.4))
	elif reveal_delay >= 0.0 and _elapsed < reveal_delay:
		draw_string(_font, Vector2(bar.position.x, bar.position.y - 10), "Watching the rep…", HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, 15, Style.MUTED)
	var x: float = bar.position.x + bar.size.x * marker
	draw_line(Vector2(x, bar.position.y - 6), Vector2(x, bar.end.y + 6), Color.WHITE, 4.0)
	draw_colored_polygon(PackedVector2Array([Vector2(x - 9, bar.position.y - 14), Vector2(x + 9, bar.position.y - 14), Vector2(x, bar.position.y - 2)]), Color.WHITE)
	if _flash > 0.0:
		draw_rect(bar.grow(6), Color(_flash_color, _flash * 0.8), false, 4.0)
