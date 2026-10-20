extends Control
## The client's face close up during coaching: the readable half of every
## signal. Fresh clients smile with relaxed brows; working clients set their
## jaw and sweat; overreaching clients grimace, brows knotted, cheeks flushed.
const Style = preload("res://scripts/ui/style.gd")
const Shapes = preload("res://scripts/ui/shapes.gd")

const INK := Color("2a1d17")
const LIP := Color("7a3328")
const SWEAT := Color("bfe3ff")

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
	draw_circle(centre, r, ring.darkened(0.6))
	Shapes.glow(self, centre + Vector2(-r * 0.15, -r * 0.2), r * 0.7, Color(ring.lightened(0.3), 0.18), 5)
	var breathe: float = sin(_time * {"green": 2.0, "amber": 4.0, "red": 7.0}.get(signal_id, 2.0)) * r * 0.015
	var head: Vector2 = centre + Vector2(0, r * 0.02 + breathe)
	var hr: float = r * 0.42
	var skin := Color(look.get("skin", "e0b090"))
	var hair := Color(look.get("hair", "3a2a20"))
	var top := Color(look.get("top", "3a7fbf"))
	var bob: bool = look.get("hair_style", "short") == "bob"
	var rim: float = maxf(1.5, r * 0.02)
	_shoulders(centre, r, hr, head, skin, top, rim)
	if bob:
		var mass := PackedVector2Array()
		for i in range(13):
			var angle: float = PI + PI * float(i) / 12.0
			mass.append(head + Vector2(cos(angle) * hr * 1.28, sin(angle) * hr * 1.3))
		for v in [Vector2(1.3, 0.55), Vector2(1.15, 0.9), Vector2(0.75, 0.92), Vector2(-0.75, 0.92), Vector2(-1.15, 0.9), Vector2(-1.3, 0.55)]:
			mass.append(head + v * hr)
		Shapes.poly(self, Shapes.smooth(mass, 2), hair.darkened(0.15), rim)
	else:
		for side in [-1.0, 1.0]:
			Shapes.ellipse(self, head + Vector2(side * hr * 0.92, hr * 0.12), hr * 0.18 + rim, hr * 0.26 + rim, Shapes.outline_of(skin))
			Shapes.ellipse(self, head + Vector2(side * hr * 0.92, hr * 0.12), hr * 0.18, hr * 0.26, skin.darkened(0.08))
	var face: PackedVector2Array = Shapes.smooth(PackedVector2Array([
		head + Vector2(-hr * 0.9, -hr * 0.55), head + Vector2(0, -hr * 1.02), head + Vector2(hr * 0.9, -hr * 0.55),
		head + Vector2(hr * 0.92, hr * 0.35), head + Vector2(hr * 0.42, hr * 0.98), head + Vector2(0, hr * 1.08),
		head + Vector2(-hr * 0.42, hr * 0.98), head + Vector2(-hr * 0.92, hr * 0.35),
	]), 3)
	Shapes.poly(self, face, skin, rim)
	Shapes.ellipse(self, head + Vector2(-hr * 0.35, -hr * 0.45), hr * 0.35, hr * 0.2, Color(1, 1, 1, 0.08), -0.4)
	_hair(head, hr, hair, bob, rim)
	var flush: float = {"green": 0.0, "amber": 0.18, "red": 0.42}.get(signal_id, 0.0)
	if flush > 0.0:
		for side in [-1.0, 1.0]:
			Shapes.ellipse(self, head + Vector2(side * hr * 0.52, hr * 0.38), hr * 0.2, hr * 0.13, Color(0.9, 0.3, 0.3, flush))
	_eyes(head, hr)
	_nose(head, hr, skin)
	_mouth(head, hr)
	if signal_id != "green":
		var drops: int = 1 if signal_id == "amber" else 3
		for i in range(drops):
			var fall: float = fposmod(_time * 0.5 + float(i) * 0.33, 1.0)
			var drop: Vector2 = head + Vector2(hr * (0.78 - float(i) * 0.14), -hr * 0.45 + fall * hr * 0.9)
			draw_circle(drop, hr * 0.08, SWEAT)
			Shapes.fill(self, PackedVector2Array([drop + Vector2(-hr * 0.075, 0), drop + Vector2(0, -hr * 0.18), drop + Vector2(hr * 0.075, 0)]), SWEAT)
	draw_arc(centre, r - 4.0, 0.0, TAU, 64, ring, 6.0, true)


## Shoulders in the client's top, a neck and a crew collar.
func _shoulders(centre: Vector2, r: float, hr: float, head: Vector2, skin: Color, top: Color, rim: float) -> void:
	var neck := Rect2(head + Vector2(-hr * 0.3, hr * 0.6), Vector2(hr * 0.6, hr * 0.7))
	Shapes.poly(self, Shapes.rounded_rect_points(neck, hr * 0.2), skin.darkened(0.12), rim)
	var body: PackedVector2Array = Shapes.smooth(PackedVector2Array([
		centre + Vector2(-r * 0.95, r * 1.05), centre + Vector2(-r * 0.78, r * 0.62), centre + Vector2(-r * 0.3, r * 0.5),
		centre + Vector2(r * 0.3, r * 0.5), centre + Vector2(r * 0.78, r * 0.62), centre + Vector2(r * 0.95, r * 1.05),
	]), 2)
	Shapes.poly(self, body, top, rim)
	draw_arc(head + Vector2(0, hr * 1.12), hr * 0.38, 0.15, PI - 0.15, 16, top.darkened(0.3), maxf(2.0, hr * 0.1), true)
	draw_line(centre + Vector2(-r * 0.62, r * 0.66), centre + Vector2(-r * 0.7, r * 1.0), top.darkened(0.2), maxf(1.5, hr * 0.05), true)
	draw_line(centre + Vector2(r * 0.62, r * 0.66), centre + Vector2(r * 0.7, r * 1.0), top.darkened(0.2), maxf(1.5, hr * 0.05), true)


func _hair(head: Vector2, hr: float, hair: Color, bob: bool, rim: float) -> void:
	var points := PackedVector2Array()
	var span: float = 1.0 if bob else 0.9
	for i in range(13):
		var angle: float = PI + PI * float(i) / 12.0
		points.append(head + Vector2(cos(angle) * hr * (1.08 if bob else 1.0), sin(angle) * hr * 1.08))
	if bob:
		points.append(head + Vector2(hr * 1.12, hr * 0.7))
		points.append(head + Vector2(hr * 0.86, hr * 0.74))
		points.append(head + Vector2(hr * 0.78, -hr * 0.1))
	points.append(head + Vector2(hr * 0.55 * span, -hr * 0.42))
	points.append(head + Vector2(hr * 0.1, -hr * 0.55))
	points.append(head + Vector2(-hr * 0.35, -hr * 0.38))
	points.append(head + Vector2(-hr * 0.7, -hr * 0.5))
	if bob:
		points.append(head + Vector2(-hr * 0.78, -hr * 0.1))
		points.append(head + Vector2(-hr * 0.86, hr * 0.74))
		points.append(head + Vector2(-hr * 1.12, hr * 0.7))
	else:
		points.append(head + Vector2(-hr * 0.92, -hr * 0.05))
	Shapes.poly(self, Shapes.smooth(points, 1), hair, rim)
	draw_arc(head + Vector2(-hr * 0.1, -hr * 0.05), hr * 0.85, PI * 1.25, PI * 1.55, 10, hair.lightened(0.22), maxf(2.0, hr * 0.08), true)


func _eyes(head: Vector2, hr: float) -> void:
	for side in [-1.0, 1.0]:
		var eye: Vector2 = head + Vector2(side * hr * 0.36, hr * 0.02)
		match signal_id:
			"green":
				draw_arc(eye + Vector2(0, hr * 0.06), hr * 0.13, PI * 1.12, PI * 1.88, 10, INK, maxf(2.5, hr * 0.07), true)
				draw_line(eye + Vector2(-hr * 0.18, -hr * 0.3), eye + Vector2(hr * 0.18, -hr * 0.33), INK, maxf(3.0, hr * 0.08), true)
			"amber":
				Shapes.ellipse(self, eye, hr * 0.15, hr * 0.11, Color("f6f1ea"))
				draw_circle(eye + Vector2(0, hr * 0.01), hr * 0.075, INK)
				draw_circle(eye + Vector2(-hr * 0.03, -hr * 0.03), hr * 0.025, Color.WHITE)
				draw_line(eye + Vector2(-hr * 0.19, -hr * 0.24), eye + Vector2(hr * 0.19, -hr * 0.2), INK, maxf(3.0, hr * 0.09), true)
			_:
				draw_polyline(PackedVector2Array([eye + Vector2(-hr * 0.14, -hr * 0.04), eye + Vector2(0, hr * 0.03), eye + Vector2(hr * 0.14, -hr * 0.04)]), INK, maxf(2.5, hr * 0.07), true)
				draw_line(eye + Vector2(-hr * 0.2 * side, -hr * 0.3), eye + Vector2(hr * 0.2 * side, -hr * 0.16), INK, maxf(3.5, hr * 0.1), true)


func _nose(head: Vector2, hr: float, skin: Color) -> void:
	var tip: Vector2 = head + Vector2(hr * 0.02, hr * 0.32)
	draw_arc(tip, hr * 0.1, 0.2, PI - 0.2, 8, skin.darkened(0.25), maxf(1.5, hr * 0.05), true)


func _mouth(head: Vector2, hr: float) -> void:
	var mouth: Vector2 = head + Vector2(0, hr * 0.6)
	match signal_id:
		"green":
			var smile := PackedVector2Array()
			for i in range(9):
				var t: float = float(i) / 8.0
				smile.append(mouth + Vector2((t - 0.5) * hr * 0.5, sin(t * PI) * hr * 0.14 - hr * 0.04))
			draw_polyline(smile, LIP, maxf(3.0, hr * 0.08), true)
		"amber":
			draw_line(mouth + Vector2(-hr * 0.18, 0), mouth + Vector2(hr * 0.18, hr * 0.02), LIP, maxf(3.0, hr * 0.08), true)
		_:
			var open := Rect2(mouth + Vector2(-hr * 0.22, -hr * 0.07), Vector2(hr * 0.44, hr * 0.18))
			Shapes.poly(self, Shapes.rounded_rect_points(open, hr * 0.06), Color("5a2420"), maxf(1.0, hr * 0.03))
			draw_line(open.position + Vector2(hr * 0.04, hr * 0.06), open.position + Vector2(open.size.x - hr * 0.04, hr * 0.06), Color("efe6dc"), maxf(2.0, hr * 0.06))
