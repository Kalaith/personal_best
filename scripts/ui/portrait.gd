extends Control
## The client's face close up during coaching: the readable half of every
## signal. Fresh clients smile with relaxed brows; working clients set their
## jaw and sweat; overreaching clients grimace, brows knotted, cheeks flushed.
const Style = preload("res://scripts/ui/style.gd")

var look: Dictionary = {}
## "green", "amber" or "red".
var signal_id: String = "green"
var _time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(170, 170)
	clip_contents = true


func set_signal(value: String) -> void:
	signal_id = value
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if look.is_empty():
		return
	var centre: Vector2 = size * 0.5
	var r: float = minf(size.x, size.y) * 0.5
	var ring: Color = Style.signal_color(signal_id)
	draw_circle(centre, r, ring.darkened(0.55))
	draw_arc(centre, r - 4.0, 0.0, TAU, 48, ring, 6.0)
	var breathe: float = sin(_time * {"green": 2.0, "amber": 4.0, "red": 7.0}.get(signal_id, 2.0)) * r * 0.012
	var head: Vector2 = centre + Vector2(0, r * 0.06 + breathe)
	var hr: float = r * 0.5
	var skin := Color(look.get("skin", "e0b090"))
	var hair := Color(look.get("hair", "3a2a20"))
	var top := Color(look.get("top", "3a7fbf"))
	draw_circle(centre + Vector2(0, r * 0.95), r * 0.62, top)
	draw_rect(Rect2(head + Vector2(-hr * 0.28, hr * 0.7), Vector2(hr * 0.56, hr * 0.6)), skin.darkened(0.08))
	if look.get("hair_style", "short") == "bob":
		draw_circle(head + Vector2(0, hr * 0.15), hr * 1.18, hair)
	draw_circle(head, hr, skin)
	draw_arc(head + Vector2(0, -hr * 0.05), hr * 1.0, PI * 1.08, PI * 1.92, 24, hair, hr * 0.42)
	if signal_id == "red":
		draw_circle(head + Vector2(-hr * 0.5, hr * 0.3), hr * 0.2, Color(0.9, 0.3, 0.3, 0.45))
		draw_circle(head + Vector2(hr * 0.5, hr * 0.3), hr * 0.2, Color(0.9, 0.3, 0.3, 0.45))
	_eyes(head, hr)
	_mouth(head, hr)
	if signal_id != "green":
		var drops: int = 1 if signal_id == "amber" else 3
		for i in range(drops):
			var fall: float = fposmod(_time * 0.5 + i * 0.33, 1.0)
			draw_circle(head + Vector2(hr * (0.75 - i * 0.12), -hr * 0.4 + fall * hr * 0.9), hr * 0.09, Color("bfe3ff"))


func _eyes(head: Vector2, hr: float) -> void:
	var ink := Color("2a1d17")
	for side in [-1.0, 1.0]:
		var eye: Vector2 = head + Vector2(side * hr * 0.36, -hr * 0.05)
		match signal_id:
			"green":
				draw_arc(eye, hr * 0.11, PI * 1.1, PI * 1.9, 8, ink, 3.0)
				draw_line(eye + Vector2(-hr * 0.16, -hr * 0.3), eye + Vector2(hr * 0.16, -hr * 0.32), ink, 3.0)
			"amber":
				draw_circle(eye, hr * 0.08, ink)
				draw_line(eye + Vector2(-hr * 0.17, -hr * 0.24), eye + Vector2(hr * 0.17, -hr * 0.2), ink, 3.5)
			_:
				draw_line(eye + Vector2(-hr * 0.1, 0), eye + Vector2(hr * 0.1, 0), ink, 3.0)
				draw_line(eye + Vector2(-hr * 0.18 * side, -hr * 0.28), eye + Vector2(hr * 0.18 * side, -hr * 0.16), ink, 4.0)


func _mouth(head: Vector2, hr: float) -> void:
	var lip := Color("6a2e24")
	var mouth: Vector2 = head + Vector2(0, hr * 0.42)
	match signal_id:
		"green":
			draw_arc(mouth + Vector2(0, -hr * 0.1), hr * 0.24, 0.35, PI - 0.35, 12, lip, 4.0)
		"amber":
			draw_line(mouth + Vector2(-hr * 0.18, 0), mouth + Vector2(hr * 0.18, hr * 0.02), lip, 4.0)
		_:
			draw_rect(Rect2(mouth + Vector2(-hr * 0.22, -hr * 0.06), Vector2(hr * 0.44, hr * 0.16)), Color("5a2420"))
			draw_line(mouth + Vector2(-hr * 0.2, hr * 0.02), mouth + Vector2(hr * 0.2, hr * 0.02), Color("efe6dc"), 2.0)
