extends RefCounted
## Drawing helpers shared by the figures, the kit and the scenery: tapered
## limbs, ellipses, outlined polygons, gradients and soft shadows. Every
## outline is a darker shade of the fill, so shapes read clearly without
## heavy black lines.

## Light falls from the upper left; highlights sit on that side of a shape.
const LIGHT := Vector2(-0.45, -0.89)


## A limb-like shape from `a` (radius `ra`) to `b` (radius `rb`).
static func capsule(ci: CanvasItem, a: Vector2, b: Vector2, ra: float, rb: float, colour: Color) -> void:
	ci.draw_circle(a, ra, colour)
	ci.draw_circle(b, rb, colour)
	var along: Vector2 = b - a
	if along.length() < 0.01:
		return
	var n: Vector2 = along.normalized().orthogonal()
	fill(ci, PackedVector2Array([a + n * ra, b + n * rb, b - n * rb, a - n * ra]), colour)


## A capsule with a darker rim and a soft highlight down its lit side.
static func limb(ci: CanvasItem, a: Vector2, b: Vector2, ra: float, rb: float, colour: Color, rim: float) -> void:
	capsule(ci, a, b, ra + rim, rb + rim, outline_of(colour))
	capsule(ci, a, b, ra, rb, colour)
	highlight(ci, a, b, ra, rb, colour)


## A soft highlight down the lit side of a limb from `a` to `b`.
static func highlight(ci: CanvasItem, a: Vector2, b: Vector2, ra: float, rb: float, colour: Color) -> void:
	var along: Vector2 = b - a
	if along.length() < 0.01:
		return
	var n: Vector2 = along.normalized().orthogonal()
	if n.dot(LIGHT) < 0.0:
		n = -n
	var lit: Color = Color(colour.lightened(0.2), 0.45)
	ci.draw_line(a.lerp(b, 0.2) + n * ra * 0.5, a.lerp(b, 0.8) + n * rb * 0.5, lit, maxf(1.0, minf(ra, rb) * 0.35), true)


## The outline of a capsule as a polygon, so it can be merged with others.
static func capsule_points(a: Vector2, b: Vector2, ra: float, rb: float, steps: int = 8) -> PackedVector2Array:
	var along: Vector2 = b - a
	if along.length() < 0.01:
		return ellipse_points(a, maxf(ra, rb), maxf(ra, rb), 0.0, steps * 2)
	var n: Vector2 = along.normalized().orthogonal()
	var points := PackedVector2Array()
	for i in range(steps + 1):
		points.append(b + n.rotated(PI * float(i) / float(steps)) * rb)
	for i in range(steps + 1):
		points.append(a - n.rotated(PI * float(i) / float(steps)) * ra)
	return points


## One outline around overlapping parts (a thigh, calf and knee; an upper
## arm, forearm and hand), with no seams where they meet.
static func union(parts: Array) -> PackedVector2Array:
	var result: PackedVector2Array = parts[0]
	for i in range(1, parts.size()):
		var merged: Array = Geometry2D.merge_polygons(result, parts[i])
		if not merged.is_empty():
			result = _largest(merged)
	return result


static func _largest(polygons: Array) -> PackedVector2Array:
	var best: PackedVector2Array = polygons[0]
	for polygon in polygons:
		if _area(polygon) > _area(best):
			best = polygon
	return best


static func _area(points: PackedVector2Array) -> float:
	var total: float = 0.0
	for i in range(points.size()):
		total += points[i].cross(points[(i + 1) % points.size()])
	return absf(total) * 0.5


## Merges `parts` into one shape and draws it with a single outline. Where
## the shape lies over `under` (a same-coloured shape already drawn, such as
## the shorts on the hips) the outline is left off, so the two read as one
## piece. Returns the merged shape.
static func silhouette(ci: CanvasItem, parts: Array, colour: Color, rim: float, under: PackedVector2Array = PackedVector2Array()) -> PackedVector2Array:
	var shape: PackedVector2Array = union(parts)
	if rim > 0.0:
		var grown: Array = Geometry2D.offset_polygon(shape, rim, Geometry2D.JOIN_ROUND)
		if not grown.is_empty():
			for piece in _outside(grown[0], under):
				fill(ci, piece, outline_of(colour))
	fill(ci, shape, colour)
	return shape


## `outer` with `under` cut away; the whole of `outer` when the cut would
## leave a hole, which a plain fill cannot draw.
static func _outside(outer: PackedVector2Array, under: PackedVector2Array) -> Array:
	if under.size() < 3:
		return [outer]
	var pieces: Array = Geometry2D.clip_polygons(outer, under)
	for piece in pieces:
		if Geometry2D.is_polygon_clockwise(piece) != Geometry2D.is_polygon_clockwise(outer):
			return [outer]
	return pieces


## Fills a polygon, skipping one too degenerate to triangulate (a limb
## folded flat, a sliver of shade) rather than raising an engine error.
static func fill(ci: CanvasItem, points: PackedVector2Array, colour: Color) -> void:
	if Geometry2D.triangulate_polygon(points).is_empty():
		return
	ci.draw_colored_polygon(points, colour)


static func outline_of(colour: Color) -> Color:
	return Color(colour.darkened(0.6), colour.a)


static func ellipse_points(centre: Vector2, rx: float, ry: float, rotation: float = 0.0, steps: int = 24) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(steps):
		var t: float = TAU * float(i) / float(steps)
		points.append(centre + Vector2(cos(t) * rx, sin(t) * ry).rotated(rotation))
	return points


static func ellipse(ci: CanvasItem, centre: Vector2, rx: float, ry: float, colour: Color, rotation: float = 0.0) -> void:
	fill(ci, ellipse_points(centre, rx, ry, rotation), colour)


## A soft contact shadow on the floor.
static func shadow(ci: CanvasItem, centre: Vector2, rx: float, ry: float, strength: float = 0.28) -> void:
	for i in range(3):
		var k: float = 1.0 - float(i) * 0.22
		ellipse(ci, centre, rx * k, ry * k, Color(0.08, 0.05, 0.03, strength * 0.4))


## A filled polygon with an outline `rim` pixels wide around it.
static func poly(ci: CanvasItem, points: PackedVector2Array, colour: Color, rim: float) -> void:
	if rim > 0.0:
		var grown: Array = Geometry2D.offset_polygon(points, rim, Geometry2D.JOIN_ROUND)
		if not grown.is_empty():
			fill(ci, grown[0], outline_of(colour))
	fill(ci, points, colour)


## Rounds the corners of a closed outline (Chaikin's corner cutting).
static func smooth(points: PackedVector2Array, passes: int = 2) -> PackedVector2Array:
	var result: PackedVector2Array = points
	for p in range(passes):
		var next := PackedVector2Array()
		var count: int = result.size()
		for i in range(count):
			var a: Vector2 = result[i]
			var b: Vector2 = result[(i + 1) % count]
			next.append(a.lerp(b, 0.25))
			next.append(a.lerp(b, 0.75))
		result = next
	return result


static func rounded_rect_points(rect: Rect2, radius: float, steps: int = 4) -> PackedVector2Array:
	var r: float = minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var points := PackedVector2Array()
	var corners: Array = [
		[rect.position + Vector2(rect.size.x - r, r), -PI * 0.5],
		[rect.position + Vector2(rect.size.x - r, rect.size.y - r), 0.0],
		[rect.position + Vector2(r, rect.size.y - r), PI * 0.5],
		[rect.position + Vector2(r, r), PI],
	]
	for corner in corners:
		for i in range(steps + 1):
			var t: float = float(corner[1]) + PI * 0.5 * float(i) / float(steps)
			points.append(Vector2(corner[0]) + Vector2(cos(t), sin(t)) * r)
	return points


## A rounded box with an outline and a lit top edge.
static func box(ci: CanvasItem, rect: Rect2, colour: Color, radius: float = 2.0, rim: float = 1.0) -> void:
	poly(ci, rounded_rect_points(rect, radius), colour, rim)
	var lip: float = minf(rect.size.y * 0.25, maxf(1.0, radius))
	ci.draw_line(rect.position + Vector2(radius, lip * 0.6), rect.position + Vector2(rect.size.x - radius, lip * 0.6), colour.lightened(0.18), lip, true)


static func vgradient(ci: CanvasItem, rect: Rect2, top: Color, bottom: Color) -> void:
	var points := PackedVector2Array([rect.position, rect.position + Vector2(rect.size.x, 0), rect.end, rect.position + Vector2(0, rect.size.y)])
	ci.draw_polygon(points, PackedColorArray([top, top, bottom, bottom]))


## A glow made of stacked translucent discs.
static func glow(ci: CanvasItem, centre: Vector2, radius: float, colour: Color, layers: int = 6) -> void:
	for i in range(layers):
		var k: float = 1.0 - float(i) / float(layers)
		ci.draw_circle(centre, radius * k, Color(colour, colour.a / float(layers)))


## The second joint of a two-bone chain from `root` reaching for `target`.
## `bend` (+1 or -1) picks which side of the line the joint folds to.
static func joint(root: Vector2, target: Vector2, first: float, second: float, bend: float) -> Vector2:
	var to: Vector2 = target - root
	var reach: float = clampf(to.length(), absf(first - second) + 0.01, first + second - 0.01)
	var cosine: float = clampf((first * first + reach * reach - second * second) / (2.0 * first * reach), -1.0, 1.0)
	var direction: Vector2 = to.normalized() if to.length() > 0.001 else Vector2.DOWN
	return root + direction.rotated(acos(cosine) * bend) * first
