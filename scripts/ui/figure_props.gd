extends RefCounted
## The kit a figure trains with, drawn around its body. `behind` comes
## before the body (machines, the step, the mat, the roller), `far` after
## the far-side limbs, and `front` over everything (what the near hand
## holds). `b` is the skeleton from figure.gd.
const Shapes = preload("res://scripts/ui/shapes.gd")

const IRON := Color("2f3236")
const STEEL := Color("b8bec4")
const RUBBER := Color("26282b")
const FRAME := Color("4a5058")


static func behind(ci: CanvasItem, prop: String, b: Dictionary) -> void:
	var u: float = b.u
	var f: float = b.facing
	var feet: Vector2 = b.feet
	var at := func(x: float, y: float) -> Vector2: return feet + Vector2(x * f, y) * u
	match prop:
		"step":
			step_box(ci, Rect2(feet + Vector2((4.0 if f > 0.0 else -30.0) * u, -17.0 * u), Vector2(26.0 * u, 17.0 * u)), u)
		"mat":
			mat(ci, at.call(-48.0, 0.0), at.call(22.0, 0.0), u, Color("4a7a8c"))
		"roller":
			mat(ci, at.call(-52.0, 0.0), at.call(22.0, 0.0), u, Color("6a8a5c"))
			roller_end(ci, at.call(-13.0, -6.4), 6.4 * u, Color("3fa7a0"), u)
		"rower":
			_rower(ci, b, at)
		"barbell":
			_plate(ci, _bar(b) + Vector2(1.5 * u * f, -1.0 * u), u, 0.25)
		"rope":
			if sin(float(b.spin)) < 0.0:
				_rope(ci, b)


static func far(ci: CanvasItem, prop: String, b: Dictionary) -> void:
	if prop == "dumbbells":
		dumbbell(ci, b.far_hand, Vector2(b.facing, 0.0), b.u * 0.95, 0.2)


static func front(ci: CanvasItem, prop: String, b: Dictionary) -> void:
	var u: float = b.u
	match prop:
		"dumbbells":
			dumbbell(ci, b.near_hand, Vector2(b.facing, 0.0), u, 0.0)
		"goblet":
			var grip: Vector2 = (Vector2(b.near_hand) + Vector2(b.far_hand)) * 0.5
			dumbbell(ci, grip + Vector2(b.up) * 1.0 * u, Vector2(b.up), u * 1.05, 0.0)
		"barbell":
			_plate(ci, _bar(b), u, 0.0)
		"rope":
			if sin(float(b.spin)) >= 0.0:
				_rope(ci, b)
		"clipboard":
			_clipboard(ci, b)
		"rower":
			var hand: Vector2 = b.near_hand
			var fan: Vector2 = Vector2(b.feet) + Vector2(36.0 * b.facing, -17.0) * u
			ci.draw_line(fan + (hand - fan).normalized() * 6.0 * u, hand, Color("6b6f74"), maxf(1.0, u * 0.6), true)
			Shapes.capsule(ci, hand - Vector2(0, 2.2) * u, hand + Vector2(0, 2.2) * u, 1.2 * u, 1.2 * u, RUBBER)


## A dumbbell along `axis`: rubber hex heads on a knurled steel handle.
static func dumbbell(ci: CanvasItem, centre: Vector2, axis: Vector2, u: float, shade: float) -> void:
	var a: Vector2 = axis.normalized()
	var side: Vector2 = a.orthogonal()
	ci.draw_line(centre - a * 4.0 * u, centre + a * 4.0 * u, STEEL.darkened(shade), maxf(1.0, 1.4 * u), true)
	for end in [-1.0, 1.0]:
		var mid: Vector2 = centre + a * end * 5.6 * u
		var head := PackedVector2Array()
		for v in [Vector2(-1.8, -2.2), Vector2(1.8, -2.2), Vector2(2.2, 0.0), Vector2(1.8, 2.2), Vector2(-1.8, 2.2), Vector2(-2.2, 0.0)]:
			head.append(mid + (a * v.x * 0.9 + side * v.y * 1.25) * u)
		Shapes.poly(ci, head, RUBBER.lightened(0.06).darkened(shade), maxf(1.0, u * 0.5))
		ci.draw_line(mid - side * 2.0 * u + a * -1.2 * u, mid - side * 2.0 * u + a * 1.2 * u, Color(1, 1, 1, 0.18), maxf(1.0, u * 0.6))


## A rubber-topped aerobic step on two risers.
static func step_box(ci: CanvasItem, rect: Rect2, u: float) -> void:
	var riser: Vector2 = Vector2(rect.size.x * 0.22, rect.size.y * 0.42)
	for x in [rect.position.x + rect.size.x * 0.04, rect.end.x - rect.size.x * 0.04 - riser.x]:
		Shapes.box(ci, Rect2(Vector2(x, rect.end.y - riser.y), riser), Color("3d4147"), 1.5 * u, maxf(1.0, u * 0.6))
	var deck := Rect2(rect.position, Vector2(rect.size.x, rect.size.y * 0.6))
	Shapes.box(ci, deck, Color("c9ccd0"), 2.0 * u, maxf(1.0, u * 0.6))
	Shapes.box(ci, Rect2(deck.position, Vector2(deck.size.x, deck.size.y * 0.32)), Color("3a3d42"), 1.5 * u, 0.0)
	for i in range(1, 6):
		var x: float = deck.position.x + deck.size.x * float(i) / 6.0
		ci.draw_line(Vector2(x, deck.position.y + 1.0), Vector2(x, deck.position.y + deck.size.y * 0.28), Color("54585e"), 1.0)


## A flat exercise mat between two ground points, a little thickness showing.
static func mat(ci: CanvasItem, a: Vector2, z: Vector2, u: float, colour: Color) -> void:
	var left: float = minf(a.x, z.x)
	var rect := Rect2(Vector2(left, a.y - 2.0 * u), Vector2(absf(z.x - a.x), 2.0 * u))
	Shapes.box(ci, rect, colour, 1.0 * u, maxf(1.0, u * 0.5))
	ci.draw_line(rect.position + Vector2(2.0 * u, 0.6 * u), rect.position + Vector2(rect.size.x - 2.0 * u, 0.6 * u), colour.lightened(0.25), maxf(1.0, u * 0.5))


## A foam roller seen end-on: a ridged rim round a hollow core.
static func roller_end(ci: CanvasItem, centre: Vector2, radius: float, colour: Color, u: float) -> void:
	ci.draw_circle(centre, radius + maxf(1.0, u * 0.6), Shapes.outline_of(colour))
	for i in range(12):
		var angle: float = TAU * float(i) / 12.0
		ci.draw_circle(centre + Vector2(cos(angle), sin(angle)) * radius * 0.92, radius * 0.18, colour.darkened(0.1))
	ci.draw_circle(centre, radius * 0.9, colour)
	ci.draw_circle(centre, radius * 0.62, colour.lightened(0.12))
	ci.draw_circle(centre, radius * 0.3, Color("1c2a2a"))


## Where a back-squat bar rests: across the upper back, behind the neck.
static func _bar(b: Dictionary) -> Vector2:
	return Vector2(b.shoulder) - Vector2(b.front) * 4.0 * b.u + Vector2(b.up) * 0.5 * b.u


## A bumper plate seen face-on, the bar's sleeve through its hub.
static func _plate(ci: CanvasItem, centre: Vector2, u: float, shade: float) -> void:
	var radius: float = 8.0 * u
	ci.draw_circle(centre, radius + maxf(1.0, u * 0.6), Color("0e0f10"))
	ci.draw_circle(centre, radius, RUBBER.darkened(shade))
	ci.draw_arc(centre, radius * 0.82, 0.0, TAU, 32, Color("3a3d42").darkened(shade), maxf(1.0, u * 0.7), true)
	ci.draw_arc(centre, radius * 0.92, PI * 1.1, PI * 1.6, 12, Color(1, 1, 1, 0.12), maxf(1.0, u * 1.0), true)
	ci.draw_circle(centre, radius * 0.3, STEEL.darkened(0.25 + shade))
	ci.draw_circle(centre, radius * 0.16, STEEL.darkened(shade))


## A rowing machine anchored at the feet: monorail, fan housing with the
## monitor on its arm, footplates, and the seat riding under the hips.
static func _rower(ci: CanvasItem, b: Dictionary, at: Callable) -> void:
	var u: float = b.u
	var rim: float = maxf(1.0, u * 0.6)
	var rail := PackedVector2Array([at.call(-38.0, -7.0), at.call(30.0, -11.0), at.call(30.0, -7.0), at.call(-38.0, -4.0)])
	Shapes.poly(ci, rail, FRAME, rim)
	Shapes.box(ci, Rect2(Vector2(at.call(-40.0, -4.0)).x - 2.0 * u, Vector2(at.call(0, -4.0)).y, 8.0 * u, 4.0 * u), IRON, 1.0 * u, rim)
	Shapes.limb(ci, at.call(30.0, -9.0), at.call(36.0, 0.0), 2.0 * u, 2.4 * u, FRAME, rim)
	Shapes.capsule(ci, at.call(31.0, 0.0), at.call(41.0, 0.0), 1.2 * u, 1.2 * u, IRON)
	Shapes.limb(ci, at.call(36.0, -18.0), at.call(30.0, -44.0), 1.2 * u, 1.0 * u, IRON, rim)
	Shapes.box(ci, Rect2(Vector2(at.call(30.0, -44.0)) - Vector2(4.5, 4.0) * u, Vector2(9.0, 7.0) * u), IRON, 1.2 * u, rim)
	ci.draw_rect(Rect2(Vector2(at.call(30.0, -44.0)) - Vector2(3.0, 2.5) * u, Vector2(6.0, 4.0) * u), Color("a8d8b0"))
	var fan: Vector2 = at.call(36.0, -17.0)
	ci.draw_circle(fan, 10.0 * u + rim, Color("0e0f10"))
	ci.draw_circle(fan, 10.0 * u, IRON)
	for i in range(6):
		var angle: float = TAU * float(i) / 6.0 + float(b.spin) * 2.0
		ci.draw_line(fan, fan + Vector2(cos(angle), sin(angle)) * 8.0 * u, Color("4a4f56"), maxf(1.0, u * 1.0), true)
	ci.draw_circle(fan, 2.4 * u, STEEL.darkened(0.2))
	var plate := PackedVector2Array([at.call(19.0, -8.0), at.call(23.0, -21.0), at.call(26.0, -20.0), at.call(24.0, -8.0)])
	Shapes.poly(ci, plate, Color("3d4147"), rim)
	var hip: Vector2 = b.hip
	var seat_y: float = Vector2(at.call(0.0, -9.5)).y + (Vector2(hip).x - Vector2(at.call(0, 0)).x) * 4.0 / 68.0 * b.facing
	Shapes.box(ci, Rect2(Vector2(hip.x - 6.0 * u, seat_y - 2.5 * u), Vector2(12.0 * u, 3.0 * u)), RUBBER.lightened(0.08), 1.2 * u, rim)
	Shapes.box(ci, Rect2(Vector2(hip.x - 3.0 * u, seat_y + 0.5 * u), Vector2(6.0 * u, 2.0 * u)), FRAME.darkened(0.2), 0.5 * u, 0.0)


## A skipping rope swinging round the body: under the feet, up behind the
## back (drawn before the body), over the head and down in front.
static func _rope(ci: CanvasItem, b: Dictionary) -> void:
	var u: float = b.u
	var near: Vector2 = b.near_hand
	var far: Vector2 = b.far_hand
	var grip: Vector2 = (near + far) * 0.5
	var hub: Vector2 = Vector2(b.hip) + Vector2(0.0, -12.0 * u)
	var swing: float = float(b.spin)
	var apex: Vector2 = hub + Vector2(sin(swing) * 12.0 * u * b.facing, cos(swing) * 56.0 * u)
	apex.y = minf(apex.y, Vector2(b.feet).y - 0.5 * u)
	# Seen side-on the rope's loop would be a single line, so it is drawn
	# turned a little towards the viewer: a narrow U from hand to hand.
	var reach: Vector2 = apex - grip
	var across: Vector2 = reach.normalized().orthogonal() * 5.0 * u
	var points := PackedVector2Array()
	for i in range(21):
		var t: float = float(i) / 20.0
		points.append(grip + reach * sin(t * PI) + across * cos(t * PI))
	ci.draw_polyline(points, Color("d24f4f"), maxf(1.0, u * 0.8), true)
	for hand in [near, far]:
		var out: Vector2 = (apex - Vector2(hand)).normalized()
		Shapes.capsule(ci, Vector2(hand) + out * 1.5 * u, Vector2(hand) - out * 3.0 * u, 1.1 * u, 1.1 * u, Color("2e2e33"))


## The trainer's clipboard, held at the chest.
static func _clipboard(ci: CanvasItem, b: Dictionary) -> void:
	var u: float = b.u
	var centre: Vector2 = (Vector2(b.near_hand) + Vector2(b.far_hand)) * 0.5 - Vector2(0.0, 4.0 * u)
	var tilt: float = 0.25 * b.facing
	var corners: Array = [Vector2(-4.5, -6.5), Vector2(4.5, -6.5), Vector2(4.5, 6.5), Vector2(-4.5, 6.5)]
	var board := PackedVector2Array()
	var paper := PackedVector2Array()
	for v in corners:
		board.append(centre + Vector2(v).rotated(tilt) * u)
		paper.append(centre + (Vector2(v) * Vector2(0.8, 0.82) + Vector2(0, 0.6)).rotated(tilt) * u)
	Shapes.poly(ci, board, Color("8a5a36"), maxf(1.0, u * 0.5))
	Shapes.fill(ci, paper, Color("f2ead8"))
	for i in range(4):
		var y: float = -2.5 + float(i) * 2.2
		ci.draw_line(centre + Vector2(-2.6, y).rotated(tilt) * u, centre + Vector2(2.6 - float(i % 2) * 1.4, y).rotated(tilt) * u, Color("9a8f80"), maxf(1.0, u * 0.4))
	ci.draw_line(centre + Vector2(-1.8, -6.6).rotated(tilt) * u, centre + Vector2(1.8, -6.6).rotated(tilt) * u, STEEL, maxf(1.5, u * 1.4))
