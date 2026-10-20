extends RefCounted
## A figure's head in profile: skull, jaw and nose as one outlined shape,
## an ear, hair cut to `hair_style` ("short" or "bob"), and a face that
## reads the client's state: relaxed brows and a smile, a set jaw, or a
## knotted grimace with flushed cheeks and sweat.
const Shapes = preload("res://scripts/ui/shapes.gd")

const INK := Color("2a1d17")
const LIP := Color("6a2e24")
const SWEAT := Color("bfe3ff")


## Where the head sits for a body skeleton from figure.gd.
static func centre(b: Dictionary) -> Vector2:
	var u: float = b.u
	var lift: Vector2 = Vector2(0.0, -0.35) if b.horizontal else Vector2(0.0, -0.8)
	var neck: Vector2 = (Vector2(b.up) + lift).normalized()
	return Vector2(b.shoulder) + neck * 12.0 * u + Vector2(b.front) * 1.2 * u


static func draw(ci: CanvasItem, b: Dictionary, look: Dictionary, colours: Dictionary, expression: String) -> void:
	var u: float = b.u
	var facing: float = b.facing
	var c: Vector2 = centre(b)
	var nod: float = (0.45 if b.horizontal else float(b.lean) * 0.3) * facing
	var at := func(x: float, y: float) -> Vector2: return c + Vector2(x * facing, y).rotated(nod) * u
	var skin: Color = colours.skin
	var hair: Color = colours.hair
	var bob: bool = look.get("hair_style", "short") == "bob"
	if bob:
		var mass: PackedVector2Array = _arc(at, 60.0, 215.0, 9.8)
		for v in [Vector2(-7.4, 8.2), Vector2(-2.0, 8.8), Vector2(0.4, 3.4)]:
			mass.append(at.call(v.x, v.y))
		Shapes.poly(ci, Shapes.smooth(mass, 1), hair.darkened(0.12), b.rim)
	var face: PackedVector2Array = Shapes.ellipse_points(at.call(0.0, 0.0), 8.0 * u, 8.4 * u, nod, 28)
	face = _merge(face, Shapes.ellipse_points(at.call(2.4, 3.6), 5.8 * u, 4.8 * u, nod, 20))
	face = _merge(face, PackedVector2Array([at.call(6.6, -1.2), at.call(9.4, 2.0), at.call(6.8, 3.2)]))
	Shapes.poly(ci, face, skin, b.rim)
	ci.draw_circle(at.call(-1.0, 6.6), 3.0 * u, Color(skin.darkened(0.12), 0.5))
	if not bob:
		Shapes.ellipse(ci, at.call(-1.2, 0.9), 1.8 * u + b.rim, 2.4 * u + b.rim, Shapes.outline_of(skin), nod)
		Shapes.ellipse(ci, at.call(-1.2, 0.9), 1.8 * u, 2.4 * u, skin.darkened(0.08), nod)
	_hair(ci, at, b, hair, bob)
	_face(ci, at, u, expression, skin)


## Points on a circle of `radius` (body units) round the head centre, from
## `from` to `to` degrees, measured from straight ahead and turning upward.
static func _arc(at: Callable, from: float, to: float, radius: float, steps: int = 10) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(steps + 1):
		var angle: float = deg_to_rad(lerpf(from, to, float(i) / float(steps)))
		points.append(at.call(cos(angle) * radius, -sin(angle) * radius))
	return points


static func _merge(a: PackedVector2Array, b: PackedVector2Array) -> PackedVector2Array:
	var merged: Array = Geometry2D.merge_polygons(a, b)
	var best: PackedVector2Array = a
	var best_area: float = 0.0
	for polygon in merged:
		if Geometry2D.is_polygon_clockwise(polygon) and merged.size() > 1:
			continue
		var area: float = absf(_area(polygon))
		if area > best_area:
			best = polygon
			best_area = area
	return best


static func _area(points: PackedVector2Array) -> float:
	var total: float = 0.0
	for i in range(points.size()):
		total += points[i].cross(points[(i + 1) % points.size()])
	return total * 0.5


static func _hair(ci: CanvasItem, at: Callable, b: Dictionary, hair: Color, bob: bool) -> void:
	var cap: PackedVector2Array
	var line: Array
	if bob:
		cap = _arc(at, 52.0, 225.0, 9.2)
		line = [Vector2(-7.0, 7.8), Vector2(-3.6, 8.6), Vector2(-2.2, 6.4), Vector2(-2.6, 2.4), Vector2(-0.6, -2.4), Vector2(2.6, -4.6), Vector2(5.2, -3.8), Vector2(6.4, -5.6)]
	else:
		cap = _arc(at, 45.0, 215.0, 8.9)
		line = [Vector2(-4.8, 4.6), Vector2(-3.4, 1.0), Vector2(-1.0, -2.6), Vector2(2.6, -4.4), Vector2(6.6, -4.4)]
	for v in line:
		cap.append(at.call(v.x, v.y))
	Shapes.poly(ci, Shapes.smooth(cap, 1), hair, b.rim)
	var shine := PackedVector2Array([at.call(-3.4, -6.6), at.call(-0.4, -7.7), at.call(3.0, -7.0)])
	ci.draw_polyline(shine, hair.lightened(0.22), maxf(1.0, float(b.u) * 1.1), true)


static func _face(ci: CanvasItem, at: Callable, u: float, expression: String, skin: Color) -> void:
	var line: float = maxf(1.0, u * 0.75)
	var eye: Vector2 = at.call(4.8, -0.4)
	if expression == "grimace":
		ci.draw_line(at.call(3.8, -0.4), at.call(5.8, -0.1), INK, line * 1.2, true)
		ci.draw_circle(at.call(3.0, 2.4), 2.0 * u, Color(0.9, 0.3, 0.3, 0.35))
	elif u >= 1.3:
		Shapes.ellipse(ci, eye, 1.5 * u, 1.2 * u, Color("f6f1ea"))
		ci.draw_circle(at.call(5.4, -0.3), 0.85 * u, INK)
	else:
		ci.draw_circle(at.call(5.1, -0.4), maxf(1.0, 0.95 * u), INK)
	var brow: Array = {"smile": [Vector2(3.0, -3.2), Vector2(6.6, -3.4)], "focus": [Vector2(3.0, -2.8), Vector2(6.6, -2.2)],
		"grimace": [Vector2(3.0, -3.6), Vector2(6.6, -2.0)]}.get(expression, [Vector2(3.0, -3.2), Vector2(6.6, -3.4)])
	ci.draw_line(at.call(brow[0].x, brow[0].y), at.call(brow[1].x, brow[1].y), INK, line * 1.1, true)
	var mouth: Vector2 = at.call(5.6, 4.6)
	match expression:
		"smile":
			ci.draw_polyline(PackedVector2Array([at.call(4.0, 4.0), at.call(5.4, 4.9), at.call(6.8, 4.2)]), LIP, line, true)
		"focus":
			ci.draw_line(at.call(4.2, 4.6), at.call(6.8, 4.5), LIP, line, true)
		_:
			Shapes.ellipse(ci, mouth, 1.7 * u, 1.1 * u, Color("5a2420"))
			ci.draw_line(at.call(4.4, 4.4), at.call(6.8, 4.4), Color("efe6dc"), maxf(1.0, u * 0.5))
	if expression != "smile":
		var drop: Vector2 = at.call(-2.6, -8.0)
		ci.draw_circle(drop, 1.3 * u, SWEAT)
		Shapes.fill(ci, PackedVector2Array([drop + Vector2(-1.2, 0) * u, drop + Vector2(0, -2.4) * u, drop + Vector2(1.2, 0) * u]), SWEAT)
