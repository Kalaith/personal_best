extends RefCounted
## Draws a person side-on from a `look` ({skin, hair, hair_style, top,
## shorts, build, height}) in one of the training poses, animated by
## `phase` (0..1 repeating). Limbs are angled from straight down; positive
## angles point the way the figure faces.

const SHOE := Color("f1efe9")
const SOLE := Color("5a4c44")


## `feet` is the ground point under the figure; `size` is roughly its height
## in pixels. `expression` is "smile", "focus" or "grimace".
static func draw(ci: CanvasItem, feet: Vector2, look: Dictionary, pose: String, phase: float, size: float, facing: float = 1.0, expression: String = "smile") -> void:
	var u: float = size / 100.0 * float(look.get("height", 1.0))
	var build: float = float(look.get("build", 1.0))
	var colours: Dictionary = {
		"skin": Color(look.get("skin", "e0b090")),
		"hair": Color(look.get("hair", "3a2a20")),
		"top": Color(look.get("top", "3a7fbf")),
		"shorts": Color(look.get("shorts", "2a2a33")),
	}
	var spin: float = phase * TAU
	var p: Dictionary = _pose(pose, spin, u)
	var hip: Vector2 = feet + Vector2(float(p.hip_x) * facing, -46.0 * u + float(p.hip_y))
	var lean: float = float(p.lean)
	var shoulder: Vector2 = hip + _dir(lean + PI, facing) * 40.0 * u
	if p.has("horizontal"):
		shoulder = hip + Vector2(40.0 * u * facing, -4.0 * u)
	var limb: float = (5.5 + 1.8 * (build - 1.0)) * u
	# Far side first so the near limbs overlap it.
	var far_tint: float = 0.18
	var hip_gap: Vector2 = Vector2(2.5 * u * facing, 0.0) if not p.has("horizontal") else Vector2(0.0, 1.5 * u)
	_leg(ci, hip - hip_gap, p.far_thigh, p.far_shin, u, limb, colours.shorts.darkened(far_tint), colours.skin.darkened(far_tint), facing)
	_arm(ci, shoulder, p.far_upper, p.far_fore, u, limb * 0.8, colours.top.darkened(far_tint), colours.skin.darkened(far_tint), facing)
	_torso(ci, hip, shoulder, u, build, colours)
	_leg(ci, hip + hip_gap, p.near_thigh, p.near_shin, u, limb, colours.shorts, colours.skin, facing)
	var head: Vector2 = shoulder + (shoulder - hip).normalized() * 13.0 * u
	_head(ci, head, u, look, colours, facing, expression)
	var hand: Vector2 = _arm(ci, shoulder, p.near_upper, p.near_fore, u, limb * 0.8, colours.top, colours.skin, facing)
	if p.has("prop"):
		_prop(ci, String(p.prop), hand, u, spin, feet, facing)


static func _dir(angle: float, facing: float) -> Vector2:
	return Vector2(sin(angle) * facing, cos(angle))


## Joint angles and offsets for each pose at `spin` (radians).
static func _pose(pose: String, spin: float, u: float) -> Dictionary:
	var s: float = sin(spin)
	var c: float = cos(spin)
	var p: Dictionary = {"hip_x": 0.0, "hip_y": 0.0, "lean": 0.0, "near_thigh": 0.1, "near_shin": 0.04, "far_thigh": -0.1, "far_shin": -0.04,
		"near_upper": 0.15, "near_fore": 0.25, "far_upper": -0.1, "far_fore": 0.1}
	match pose:
		"walk":
			p.hip_y = -absf(s) * 1.5 * u
			p.near_thigh = 0.35 * s
			p.far_thigh = -0.35 * s
			p.near_shin = p.near_thigh - maxf(0.0, -s) * 0.5
			p.far_shin = p.far_thigh - maxf(0.0, s) * 0.5
			p.near_upper = -0.3 * s
			p.far_upper = 0.3 * s
			p.near_fore = p.near_upper + 0.3
			p.far_fore = p.far_upper + 0.3
		"run":
			p.hip_y = -absf(s) * 4.0 * u
			p.lean = 0.16
			p.near_thigh = 0.75 * s + 0.1
			p.far_thigh = -0.75 * s + 0.1
			p.near_shin = p.near_thigh - 0.6 - 0.6 * maxf(0.0, -s)
			p.far_shin = p.far_thigh - 0.6 - 0.6 * maxf(0.0, s)
			p.near_upper = -0.7 * s
			p.far_upper = 0.7 * s
			p.near_fore = p.near_upper + 1.5
			p.far_fore = p.far_upper + 1.5
		"squat":
			var d: float = (1.0 - c) * 0.5
			p.hip_y = d * 22.0 * u
			p.hip_x = -d * 14.0 * u
			p.lean = d * 0.8
			p.near_thigh = d * 1.35
			p.far_thigh = d * 1.35
			p.near_shin = -d * 0.45
			p.far_shin = -d * 0.45
			p.near_upper = 1.2
			p.near_fore = 2.6
			p.far_upper = 1.2
			p.far_fore = 2.6
			p.prop = "dumbbell"
		"lunge":
			var d: float = (1.0 - c) * 0.5
			p.hip_y = d * 16.0 * u
			p.near_thigh = 0.35 + d * 0.9
			p.near_shin = 0.1 - d * 0.2
			p.far_thigh = -0.3 - d * 0.2
			p.far_shin = -0.35 - d * 1.0
			p.near_upper = 0.0
			p.near_fore = 0.0
			p.far_upper = 0.0
			p.far_fore = 0.0
			p.prop = "dumbbell"
		"step":
			var d: float = (1.0 - c) * 0.5
			p.hip_y = -d * 18.0 * u
			p.hip_x = d * 6.0 * u
			p.near_thigh = 0.9 - d * 0.9
			p.near_shin = -0.1
			p.far_thigh = -0.1 + d * 0.2
			p.far_shin = -0.1 - (1.0 - d) * 0.5
			p.near_upper = 0.05
			p.near_fore = 0.05
			p.prop = "box"
		"skip":
			p.hip_y = -absf(s) * 7.0 * u
			p.near_thigh = 0.1
			p.far_thigh = 0.05
			p.near_shin = -0.15
			p.far_shin = -0.2
			p.near_upper = 0.5
			p.near_fore = 1.3
			p.far_upper = 0.5
			p.far_fore = 1.3
			p.prop = "rope"
		"plank":
			var breathe: float = s * 0.6 * u
			p.horizontal = true
			p.hip_y = 32.0 * u + breathe
			p.near_thigh = -1.45
			p.far_thigh = -1.45
			p.near_shin = -1.5
			p.far_shin = -1.5
			p.near_upper = 0.1
			p.near_fore = 1.55
			p.far_upper = 0.1
			p.far_fore = 1.55
			p.prop = "mat"
		"roll":
			p.horizontal = true
			p.hip_y = 32.0 * u
			p.hip_x = s * 6.0 * u
			p.near_thigh = -1.5
			p.far_thigh = -1.55
			p.near_shin = -1.6
			p.far_shin = -1.6
			p.near_upper = 0.2
			p.near_fore = 0.2
			p.far_upper = 0.15
			p.far_fore = 0.15
			p.prop = "roller"
		"row":
			var d: float = (1.0 + c) * 0.5
			p.hip_y = 28.0 * u
			p.hip_x = -d * 14.0 * u
			p.lean = -0.25 + d * 0.5
			p.near_thigh = 1.0 + d * 0.5
			p.far_thigh = 1.0 + d * 0.5
			p.near_shin = -0.2 - d * 0.9 + 1.4
			p.far_shin = -0.2 - d * 0.9 + 1.4
			p.near_upper = 1.6 - (1.0 - d) * 0.9
			p.near_fore = 1.6 + (1.0 - d) * 0.6
			p.far_upper = p.near_upper
			p.far_fore = p.near_fore
			p.prop = "rower"
		"wave":
			p.near_upper = 2.6 + s * 0.25
			p.near_fore = 3.0 + s * 0.4
	return p


static func _segment(ci: CanvasItem, a: Vector2, b: Vector2, width: float, colour: Color) -> void:
	ci.draw_line(a, b, colour, width)
	ci.draw_circle(a, width * 0.5, colour)
	ci.draw_circle(b, width * 0.5, colour)


static func _leg(ci: CanvasItem, hip: Vector2, thigh: float, shin: float, u: float, width: float, cloth: Color, skin: Color, facing: float) -> void:
	var knee: Vector2 = hip + _dir(thigh, facing) * 22.0 * u
	var ankle: Vector2 = knee + _dir(shin, facing) * 22.0 * u
	_segment(ci, knee, ankle, width * 0.9, skin)
	_segment(ci, hip, hip.lerp(knee, 0.75), width * 1.15, cloth)
	_segment(ci, hip.lerp(knee, 0.7), knee, width * 0.95, skin)
	var toe: Vector2 = ankle + Vector2(7.0 * u * facing, 0.0)
	_segment(ci, ankle + Vector2(-2.0 * u * facing, 0.0), toe, width * 1.0, SHOE)
	ci.draw_line(ankle + Vector2(-2.5 * u * facing, width * 0.45), toe + Vector2(0.5 * u * facing, width * 0.45), SOLE, maxf(1.5, u * 1.2))


static func _arm(ci: CanvasItem, shoulder: Vector2, upper: float, fore: float, u: float, width: float, cloth: Color, skin: Color, facing: float) -> Vector2:
	var elbow: Vector2 = shoulder + _dir(upper, facing) * 16.0 * u
	var hand: Vector2 = elbow + _dir(fore, facing) * 15.0 * u
	_segment(ci, elbow, hand, width * 0.85, skin)
	_segment(ci, shoulder, shoulder.lerp(elbow, 0.6), width * 1.05, cloth)
	_segment(ci, shoulder.lerp(elbow, 0.55), elbow, width * 0.9, skin)
	ci.draw_circle(hand, width * 0.6, skin)
	return hand


static func _torso(ci: CanvasItem, hip: Vector2, shoulder: Vector2, u: float, build: float, colours: Dictionary) -> void:
	var axis: Vector2 = (shoulder - hip)
	var side: Vector2 = axis.normalized().orthogonal()
	var waist: float = 7.5 * u * build
	var chest: float = 8.5 * u * (0.6 + 0.4 * build)
	var points := PackedVector2Array([
		hip + side * waist, hip.lerp(shoulder, 0.5) + side * (waist * 1.08), shoulder + side * chest,
		shoulder - side * chest, hip.lerp(shoulder, 0.5) - side * (waist * 1.08), hip - side * waist,
	])
	ci.draw_colored_polygon(points, colours.top)
	_segment(ci, hip + side * waist * 0.95, hip - side * waist * 0.95, 7.0 * u, colours.shorts)
	ci.draw_circle(shoulder, chest * 0.95, colours.top)


static func _head(ci: CanvasItem, centre: Vector2, u: float, look: Dictionary, colours: Dictionary, facing: float, expression: String) -> void:
	var r: float = 9.0 * u
	if look.get("hair_style", "short") == "bob":
		ci.draw_circle(centre + Vector2(-2.5 * u * facing, 1.5 * u), r * 1.12, colours.hair)
	ci.draw_circle(centre + Vector2(0.0, 3.0 * u), r * 0.42, colours.skin.darkened(0.08))
	ci.draw_circle(centre, r, colours.skin)
	ci.draw_arc(centre + Vector2(-0.5 * u * facing, -0.5 * u), r * 1.02, PI * 1.05, PI * 1.95, 18, colours.hair, r * 0.55)
	if look.get("hair_style", "short") == "bob":
		ci.draw_circle(centre + Vector2(-5.0 * u * facing, 0.0), r * 0.6, colours.hair)
	var eye: Vector2 = centre + Vector2(4.2 * u * facing, -1.0 * u)
	ci.draw_circle(eye, 1.1 * u, Color("2a1d17"))
	var mouth: Vector2 = centre + Vector2(4.8 * u * facing, 3.8 * u)
	match expression:
		"smile":
			ci.draw_arc(mouth + Vector2(0, -1.2 * u), 2.0 * u, 0.3, PI - 0.3, 8, Color("6a2e24"), maxf(1.2, u * 0.9))
		"focus":
			ci.draw_line(mouth + Vector2(-1.6 * u, 0), mouth + Vector2(1.6 * u, 0), Color("6a2e24"), maxf(1.2, u * 0.9))
		"grimace":
			ci.draw_circle(mouth, 1.6 * u, Color("5a2420"))
			ci.draw_line(eye + Vector2(-1.6 * u, -2.2 * u), eye + Vector2(1.6 * u, -1.2 * u), Color("2a1d17"), maxf(1.0, u * 0.8))
	if expression != "smile":
		var drop: Vector2 = centre + Vector2(-3.0 * u * facing, -7.5 * u)
		ci.draw_circle(drop, 1.3 * u, Color("bfe3ff"))


static func _prop(ci: CanvasItem, prop: String, hand: Vector2, u: float, spin: float, feet: Vector2, facing: float) -> void:
	match prop:
		"dumbbell":
			ci.draw_line(hand + Vector2(-5 * u, 0), hand + Vector2(5 * u, 0), Color("3b3b3b"), 2.0 * u)
			ci.draw_rect(Rect2(hand + Vector2(-7 * u, -3 * u), Vector2(3 * u, 6 * u)), Color("2c2c2c"))
			ci.draw_rect(Rect2(hand + Vector2(4 * u, -3 * u), Vector2(3 * u, 6 * u)), Color("2c2c2c"))
		"rope":
			var top: float = -95.0 * u if sin(spin) > 0.0 else 4.0 * u
			var mid := Vector2(feet.x, feet.y + top)
			var left := hand + Vector2(-14.0 * u * facing, 0)
			var points := PackedVector2Array()
			for i in range(13):
				var t: float = float(i) / 12.0
				var a: Vector2 = left.lerp(hand, t)
				points.append(a.lerp(mid, sin(t * PI)))
			ci.draw_polyline(points, Color("d24f4f"), maxf(1.5, u))
		"box":
			ci.draw_rect(Rect2(feet + Vector2(4.0 * u * facing - (0.0 if facing > 0 else 26.0 * u), -16.0 * u), Vector2(26.0 * u, 16.0 * u)), Color("8b5a3c"))
		"mat":
			ci.draw_rect(Rect2(feet + Vector2(-10.0 * u, -2.0 * u), Vector2(90.0 * u * facing, 3.0 * u)).abs(), Color("4a7a8c"))
		"roller":
			ci.draw_circle(feet + Vector2(-8.0 * u * facing, -6.0 * u), 6.0 * u, Color("3fa7a0"))
			ci.draw_rect(Rect2(feet + Vector2(-10.0 * u, -2.0 * u), Vector2(90.0 * u * facing, 3.0 * u)).abs(), Color("4a7a8c"))
		"rower":
			ci.draw_rect(Rect2(feet + Vector2(-30.0 * u, -14.0 * u), Vector2(90.0 * u, 5.0 * u)), Color("3a3a40"))
			ci.draw_circle(feet + Vector2(62.0 * u, -16.0 * u), 10.0 * u, Color("2b2b30"))
			ci.draw_line(hand, feet + Vector2(60.0 * u, -18.0 * u), Color("9a9a9a"), maxf(1.0, u * 0.8))
