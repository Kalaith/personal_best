extends RefCounted
## The equipment along the shed's back wall: what the gym owns is what you
## see. A piece a client is using right now is left out here, because the
## client's figure brings it into the foreground. `k` scales the kit (1.0
## matches a 100-pixel person) and `base` is the foot of the back wall.
const Shapes = preload("res://scripts/ui/shapes.gd")
const Props = preload("res://scripts/ui/figure_props.gd")

const IRON := Color("2f3236")
const STEEL := Color("b8bec4")
const FRAME := Color("4a5058")
const WOOD := Color("6b4a33")


static func draw(ci: CanvasItem, size: Vector2, base: float, k: float, owned: Array, in_use: String) -> void:
	var x: float = size.x * 0.02
	var show := func(id: String) -> bool: return owned.has(id) and id != in_use
	if show.call("dumbbells"):
		_dumbbell_rack(ci, Vector2(x, base), k)
	if show.call("skipping_ropes"):
		_ropes(ci, Vector2(x + 72.0 * k, base - 78.0 * k), k)
	if show.call("floor_mats"):
		_rolled_mats(ci, Vector2(x + 72.0 * k, base), k)
	if show.call("foam_rollers"):
		_rollers(ci, Vector2(x + 104.0 * k, base), k)
	if show.call("step_box"):
		Props.step_box(ci, Rect2(Vector2(x + 138.0 * k, base - 14.0 * k), Vector2(34.0 * k, 14.0 * k)), k)
	if show.call("rowing_machine"):
		_rower(ci, Vector2(size.x * 0.27, base), k)
	if show.call("treadmill"):
		treadmill(ci, Vector2(size.x * 0.56, base), k, 0.0)
	if show.call("barbell_rack"):
		_squat_rack(ci, Vector2(size.x * 0.72, base), k)


## A two-shelf rack of hex dumbbells, light to heavy.
static func _dumbbell_rack(ci: CanvasItem, foot: Vector2, k: float) -> void:
	var width: float = 60.0 * k
	for leg in [0.08, 0.92]:
		Shapes.limb(ci, foot + Vector2(width * leg, -44.0 * k), foot + Vector2(width * leg + (4.0 if leg < 0.5 else -4.0) * k, 0.0), 1.6 * k, 1.8 * k, IRON, 1.0)
	for shelf in range(2):
		var y: float = -40.0 * k + float(shelf) * 20.0 * k
		var a: Vector2 = foot + Vector2(0.0, y)
		var z: Vector2 = foot + Vector2(width, y + 4.0 * k)
		Shapes.limb(ci, a, z, 1.4 * k, 1.4 * k, FRAME, 1.0)
		for i in range(3):
			var t: float = (0.2 + 0.3 * float(i))
			var weight: float = 0.75 + 0.12 * float(i + shelf * 3)
			var centre: Vector2 = a.lerp(z, t) + Vector2(0.0, -3.2 * k * weight)
			Props.dumbbell(ci, centre, Vector2(1.0, 0.0), k * weight * 0.85, 0.05 * float(1 - shelf))


## Two skipping ropes coiled on a wall hook.
static func _ropes(ci: CanvasItem, hook: Vector2, k: float) -> void:
	Shapes.box(ci, Rect2(hook - Vector2(4.0, 2.0) * k, Vector2(8.0, 4.0) * k), WOOD, 1.0, 1.0)
	for rope in range(2):
		var colour: Color = [Color("d24f4f"), Color("4f7fd2")][rope]
		var centre: Vector2 = hook + Vector2((float(rope) * 5.0 - 2.5) * k, 12.0 * k)
		Shapes.ellipse(ci, centre, 7.0 * k + 1.0, 11.0 * k + 1.0, Shapes.outline_of(colour))
		Shapes.ellipse(ci, centre, 7.0 * k, 11.0 * k, colour)
		Shapes.ellipse(ci, centre, 5.0 * k, 9.0 * k, Color("8d6040").darkened(0.05 * float(rope)))
		for handle in [-1.0, 1.0]:
			var top: Vector2 = centre + Vector2(handle * 3.0 * k, 10.0 * k)
			ci.draw_line(top, top + Vector2(handle * 1.5 * k, 6.0 * k), colour, maxf(1.0, 1.2 * k))
			Shapes.limb(ci, top + Vector2(handle * 1.5 * k, 6.0 * k), top + Vector2(handle * 2.0 * k, 14.0 * k), 1.4 * k, 1.4 * k, Color("2e2e33"), 1.0)


## Exercise mats rolled up and stood on end.
static func _rolled_mats(ci: CanvasItem, foot: Vector2, k: float) -> void:
	for i in range(2):
		var colour: Color = [Color("4a7a8c"), Color("6a8a5c")][i]
		var rect := Rect2(foot + Vector2(float(i) * 11.0 * k, -40.0 * k + float(i) * 6.0 * k), Vector2(10.0 * k, 40.0 * k - float(i) * 6.0 * k))
		Shapes.box(ci, rect, colour, 4.0 * k, 1.0)
		Shapes.ellipse(ci, Vector2(rect.get_center().x, rect.position.y + 2.0 * k), rect.size.x * 0.5, 2.2 * k, colour.lightened(0.15))
		ci.draw_arc(Vector2(rect.get_center().x, rect.position.y + 2.0 * k), rect.size.x * 0.25, 0.0, TAU, 10, colour.darkened(0.3), 1.0)
		ci.draw_line(rect.position + Vector2(0, rect.size.y * 0.3), rect.position + Vector2(rect.size.x, rect.size.y * 0.3), Color("2a2a2a"), maxf(1.0, 1.5 * k))


## Foam rollers stood upright.
static func _rollers(ci: CanvasItem, foot: Vector2, k: float) -> void:
	for i in range(3):
		var colour: Color = Color("3fa7a0").darkened(0.08 * float(i))
		var height: float = (30.0 - float(i % 2) * 6.0) * k
		var rect := Rect2(foot + Vector2(float(i) * 10.0 * k, -height), Vector2(9.0 * k, height))
		Shapes.box(ci, rect, colour, 3.0 * k, 1.0)
		for r in range(1, 6):
			var y: float = rect.position.y + rect.size.y * float(r) / 6.0
			ci.draw_line(Vector2(rect.position.x + 1.0, y), Vector2(rect.end.x - 1.0, y), colour.darkened(0.18), maxf(1.0, k))
		Shapes.ellipse(ci, Vector2(rect.get_center().x, rect.position.y + 1.5 * k), rect.size.x * 0.5, 1.8 * k, colour.lightened(0.2))
		ci.draw_circle(Vector2(rect.get_center().x, rect.position.y + 1.5 * k), 1.6 * k, Color("1c2a2a"))


## A rowing machine at rest against the wall, seat parked at the back.
static func _rower(ci: CanvasItem, foot: Vector2, k: float) -> void:
	var at := func(x: float, y: float) -> Vector2: return foot + Vector2(x, y) * k
	var rail := PackedVector2Array([at.call(0.0, -7.0), at.call(70.0, -11.0), at.call(70.0, -7.0), at.call(0.0, -4.0)])
	Shapes.poly(ci, rail, FRAME, 1.0)
	Shapes.box(ci, Rect2(at.call(-3.0, -4.0), Vector2(8.0, 4.0) * k), IRON, 1.0, 1.0)
	Shapes.limb(ci, at.call(70.0, -9.0), at.call(76.0, 0.0), 2.0 * k, 2.4 * k, FRAME, 1.0)
	Shapes.limb(ci, at.call(76.0, -18.0), at.call(70.0, -44.0), 1.2 * k, 1.0 * k, IRON, 1.0)
	Shapes.box(ci, Rect2(Vector2(at.call(70.0, -44.0)) - Vector2(4.5, 4.0) * k, Vector2(9.0, 7.0) * k), IRON, 1.2 * k, 1.0)
	ci.draw_rect(Rect2(Vector2(at.call(70.0, -44.0)) - Vector2(3.0, 2.5) * k, Vector2(6.0, 4.0) * k), Color("6a7f70"))
	var fan: Vector2 = at.call(76.0, -17.0)
	ci.draw_circle(fan, 10.0 * k + 1.0, Color("0e0f10"))
	ci.draw_circle(fan, 10.0 * k, IRON)
	ci.draw_arc(fan, 7.0 * k, 0.0, TAU, 18, Color("4a4f56"), maxf(1.0, k))
	ci.draw_circle(fan, 2.4 * k, STEEL.darkened(0.2))
	Shapes.poly(ci, PackedVector2Array([at.call(59.0, -8.0), at.call(63.0, -21.0), at.call(66.0, -20.0), at.call(64.0, -8.0)]), Color("3d4147"), 1.0)
	Shapes.box(ci, Rect2(at.call(8.0, -11.5), Vector2(12.0, 3.0) * k), Color("2b2d30"), 1.2 * k, 1.0)
	Shapes.capsule(ci, at.call(66.0, -24.0), at.call(66.0, -20.0), 1.2 * k, 1.2 * k, Color("26282b"))


## A treadmill: deck and belt, motor hood, uprights and the console. When
## `belt` moves, the slats run backwards under a runner.
static func treadmill(ci: CanvasItem, foot: Vector2, k: float, belt: float) -> void:
	var at := func(x: float, y: float) -> Vector2: return foot + Vector2(x, y) * k
	var deck := Rect2(at.call(0.0, -11.0), Vector2(84.0, 7.0) * k)
	Shapes.box(ci, Rect2(at.call(2.0, -5.0), Vector2(6.0, 5.0) * k), IRON, 1.0, 1.0)
	Shapes.box(ci, Rect2(at.call(74.0, -5.0), Vector2(8.0, 5.0) * k), IRON, 1.0, 1.0)
	Shapes.box(ci, deck, FRAME, 2.0 * k, 1.0)
	var belt_rect := Rect2(deck.position + Vector2(2.0 * k, -1.5 * k), Vector2(deck.size.x - 18.0 * k, 3.0 * k))
	ci.draw_rect(belt_rect, Color("1d1f22"))
	var gap: float = 6.0 * k
	for i in range(int(belt_rect.size.x / gap) + 1):
		var x: float = belt_rect.position.x + fposmod(float(i) * gap - belt, belt_rect.size.x)
		ci.draw_line(Vector2(x, belt_rect.position.y), Vector2(x, belt_rect.end.y), Color(1, 1, 1, 0.08), 1.0)
	Shapes.box(ci, Rect2(at.call(66.0, -16.0), Vector2(18.0, 9.0) * k), Color("3d4147"), 3.0 * k, 1.0)
	Shapes.limb(ci, at.call(74.0, -14.0), at.call(70.0, -56.0), 1.8 * k, 1.5 * k, FRAME, 1.0)
	Shapes.limb(ci, at.call(70.0, -40.0), at.call(52.0, -38.0), 1.2 * k, 1.2 * k, Color("5a6068"), 1.0)
	var console := PackedVector2Array([at.call(60.0, -62.0), at.call(78.0, -60.0), at.call(76.0, -52.0), at.call(62.0, -52.0)])
	Shapes.poly(ci, console, IRON, 1.0)
	ci.draw_rect(Rect2(at.call(64.0, -59.0), Vector2(9.0, 4.0) * k), Color("3fd28a") if belt != 0.0 else Color("3a5a48"))


## A squat stand with the barbell racked on its hooks and plates loaded.
static func _squat_rack(ci: CanvasItem, foot: Vector2, k: float) -> void:
	var at := func(x: float, y: float) -> Vector2: return foot + Vector2(x, y) * k
	for x in [12.0, 62.0]:
		Shapes.box(ci, Rect2(at.call(x - 8.0, -3.0), Vector2(18.0, 3.0) * k), IRON, 1.0, 1.0)
		Shapes.box(ci, Rect2(at.call(x - 2.0, -86.0), Vector2(5.0, 84.0) * k), Color("3b3f45"), 1.0, 1.0)
		for h in range(10):
			ci.draw_circle(at.call(x + 0.5, -80.0 + float(h) * 7.0), maxf(0.8, 0.8 * k), Color("16181a"))
		Shapes.box(ci, Rect2(at.call(x - 4.0, -60.0), Vector2(5.0, 6.0) * k), Color("c94a3a"), 1.0, 1.0)
	ci.draw_line(at.call(-14.0, -60.0), at.call(88.0, -60.0), STEEL, maxf(1.5, 1.8 * k), true)
	ci.draw_line(at.call(-14.0, -60.8), at.call(88.0, -60.8), Color(1, 1, 1, 0.35), 1.0)
	for side in [-1.0, 1.0]:
		var plate_x: float = 37.0 + side * 43.0
		Shapes.box(ci, Rect2(at.call(plate_x - 2.5, -73.0), Vector2(5.0, 26.0) * k), Color("26282b"), 2.0 * k, 1.0)
		Shapes.box(ci, Rect2(at.call(plate_x + side * 3.0 - 1.5, -70.0), Vector2(3.0, 20.0) * k), Color("c94a3a"), 1.5 * k, 1.0)
		Shapes.box(ci, Rect2(at.call(plate_x + side * 6.0 - 1.0, -62.0), Vector2(2.0, 4.0) * k), STEEL, 0.5, 0.0)
	for i in range(2):
		Shapes.box(ci, Rect2(at.call(26.0 + float(i) * 4.0, -24.0 + float(i) * 3.0), Vector2(3.5, 24.0 - float(i) * 3.0) * k), Color("26282b").lightened(0.04 * float(i)), 1.5 * k, 1.0)


## The intake desk with the assessment sheet on it.
static func desk(ci: CanvasItem, left: Vector2, k: float) -> void:
	var top := Rect2(left + Vector2(0.0, -40.0 * k), Vector2(96.0, 6.0) * k)
	for x in [5.0, 85.0]:
		Shapes.box(ci, Rect2(left + Vector2(x * k, -35.0 * k), Vector2(6.0, 35.0) * k), WOOD.darkened(0.15), 1.0, 1.0)
	Shapes.box(ci, Rect2(left + Vector2(4.0 * k, -34.0 * k), Vector2(88.0, 8.0) * k), WOOD.darkened(0.1), 1.0, 1.0)
	Shapes.box(ci, top, WOOD, 1.5 * k, 1.0)
	var sheet := PackedVector2Array([left + Vector2(30.0, -41.0) * k, left + Vector2(52.0, -42.5) * k, left + Vector2(54.0, -40.5) * k, left + Vector2(32.0, -39.5) * k])
	Shapes.fill(ci, sheet, Color("f2ead8"))
	Shapes.box(ci, Rect2(left + Vector2(64.0, -48.0) * k, Vector2(7.0, 8.0) * k), Color("c0563a"), 1.5 * k, 1.0)
