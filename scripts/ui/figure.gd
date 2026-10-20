extends RefCounted
## Draws a person side-on from a `look` ({skin, hair, hair_style, top,
## shorts, build, height}) in one of the training poses, animated by
## `phase` (0..1 repeating). Bodies are built from tapered, outlined limbs
## and a shaped torso whose depth follows `build`; poses come from
## figure_poses.gd and the kit they use from figure_props.gd.
const Shapes = preload("res://scripts/ui/shapes.gd")
const Poses = preload("res://scripts/ui/figure_poses.gd")
const Props = preload("res://scripts/ui/figure_props.gd")
const Head = preload("res://scripts/ui/figure_head.gd")
const Moods = preload("res://scripts/ui/figure_moods.gd")

const SHOE := Color("f1efe9")
const SOLE := Color("5a4c44")
const THIGH: float = 22.0
const SHIN: float = 22.0
const UPPER_ARM: float = 16.0
const FOREARM: float = 15.0
const SPINE: float = 40.0
## How much the far side of the body is shaded.
const FAR_TINT: float = 0.2


## `feet` is the ground point under the figure; `size` is roughly its height
## in pixels. `expression` is "smile", "focus" or "grimace". `fault` (a
## technique fault's `show` id) bends the pose by `fault_amount` (0..1).
## `mood` (see figure_moods.gd) lays body language over the pose and may
## change the face.
static func draw(ci: CanvasItem, feet: Vector2, look: Dictionary, pose: String, phase: float, size: float, facing: float = 1.0, expression: String = "smile",
		fault: String = "", fault_amount: float = 0.0, mood: Dictionary = {}) -> void:
	var u: float = size / 100.0 * float(look.get("height", 1.0))
	var build: float = float(look.get("build", 1.0))
	var colours: Dictionary = {
		"skin": Color(look.get("skin", "e0b090")),
		"hair": Color(look.get("hair", "3a2a20")),
		"top": Color(look.get("top", "3a7fbf")),
		"shorts": Color(look.get("shorts", "2a2a33")),
		"shoe": SHOE,
	}
	var spin: float = phase * TAU
	var p: Dictionary = Poses.pose(pose, spin, u, fault, fault_amount)
	if not mood.is_empty():
		Moods.apply(p, mood, u)
		expression = String(p.get("face", expression))
	var body: Dictionary = _skeleton(p, feet, u, facing)
	body.merge({"u": u, "build": build, "facing": facing, "feet": feet, "spin": spin, "colours": colours, "rim": maxf(1.0, u * 0.75),
		"neck": float(p.get("neck", 0.0)), "cheeks": float(p.get("cheeks", 0.0))})
	var prop: String = String(p.get("prop", ""))
	var lift: float = feet.y - maxf(body.near_ankle.y, body.far_ankle.y)
	var spread: float = 34.0 if p.has("horizontal") else 15.0
	Shapes.shadow(ci, Vector2(body.hip.x + 4.0 * u * facing * (1.0 if p.has("horizontal") else 0.0), feet.y - 1.0), spread * u * clampf(1.0 - lift / (60.0 * u), 0.5, 1.0), 3.2 * u)
	Props.behind(ci, prop, body)
	var far: Dictionary = _tinted(colours, FAR_TINT)
	_leg(ci, body, body.far_hip, body.far_knee, body.far_ankle, far, float(p.get("far_heel_lift", 0.0)))
	_arm(ci, body, body.far_shoulder, body.far_elbow, body.far_hand, far)
	Props.far(ci, prop, body)
	_torso(ci, body, colours)
	_leg(ci, body, body.near_hip, body.near_knee, body.near_ankle, colours, float(p.get("near_heel_lift", 0.0)))
	Head.draw(ci, body, look, colours, expression)
	_arm(ci, body, body.near_shoulder, body.near_elbow, body.near_hand, colours)
	Props.front(ci, prop, body)


## Joint positions for the pose: hips, shoulders, knees, ankles, elbows and
## hands, plus the torso's frame (`up` along the spine, `front` out of the chest).
static func _skeleton(p: Dictionary, feet: Vector2, u: float, facing: float) -> Dictionary:
	var hip: Vector2 = feet + Vector2(float(p.hip_x) * facing, -46.0 * u + float(p.hip_y))
	var lean: float = float(p.lean)
	var axis: Vector2 = Vector2(sin(lean) * facing, -cos(lean)) * SPINE * u
	if p.has("horizontal"):
		axis = Vector2(SPINE * u * facing, -(4.0 + float(p.get("tilt", 0.0))) * u)
	var shoulder: Vector2 = hip + axis
	var up: Vector2 = axis.normalized()
	var front: Vector2 = -up.orthogonal() * facing
	var b: Dictionary = {"hip": hip, "shoulder": shoulder, "up": up, "front": front, "horizontal": p.has("horizontal"), "lean": lean}
	var hip_gap: Vector2 = Vector2(2.0 * u * facing, 0.0) if not p.has("horizontal") else Vector2(0.0, 1.5 * u)
	var shoulder_gap: Vector2 = Vector2(-1.5 * u * facing, 0.0) if not p.has("horizontal") else Vector2(0.0, 1.0 * u)
	b.near_hip = hip + hip_gap * 0.5
	b.far_hip = hip - hip_gap * 0.5
	b.near_shoulder = shoulder + shoulder_gap * 0.5 - up * 2.0 * u
	b.far_shoulder = shoulder - shoulder_gap * 0.5 - up * 2.0 * u
	for side in ["near", "far"]:
		var root: Vector2 = b[side + "_hip"]
		if p.has(side + "_ankle"):
			var target: Vector2 = feet + Vector2(p[side + "_ankle"].x * facing, p[side + "_ankle"].y) * u
			b[side + "_knee"] = Shapes.joint(root, target, THIGH * u, SHIN * u, -facing)
			b[side + "_ankle"] = b[side + "_knee"] + (target - b[side + "_knee"]).normalized() * SHIN * u
		else:
			b[side + "_knee"] = root + _dir(float(p[side + "_thigh"]), facing) * THIGH * u
			b[side + "_ankle"] = b[side + "_knee"] + _dir(float(p[side + "_shin"]), facing) * SHIN * u
		if p.has(side + "_knee_shift"):
			b[side + "_knee"] += Vector2(p[side + "_knee_shift"].x * facing, p[side + "_knee_shift"].y) * u
		var socket: Vector2 = b[side + "_shoulder"]
		var reach: Variant = null
		if p.has(side + "_hand"):
			reach = socket + Vector2(p[side + "_hand"].x * facing, p[side + "_hand"].y) * u
		elif p.has(side + "_grip"):
			reach = shoulder + (front * p[side + "_grip"].x - up * p[side + "_grip"].y) * u
		if reach != null:
			# Elbows fold whichever way keeps them lower, as arms naturally hang.
			var bent: Vector2 = Shapes.joint(socket, reach, UPPER_ARM * u, FOREARM * u, facing)
			var other: Vector2 = Shapes.joint(socket, reach, UPPER_ARM * u, FOREARM * u, -facing)
			b[side + "_elbow"] = bent if bent.y >= other.y else other
			b[side + "_hand"] = b[side + "_elbow"] + (Vector2(reach) - b[side + "_elbow"]).normalized() * FOREARM * u
		else:
			b[side + "_elbow"] = socket + _dir(float(p[side + "_upper"]), facing) * UPPER_ARM * u
			b[side + "_hand"] = b[side + "_elbow"] + _dir(float(p[side + "_fore"]), facing) * FOREARM * u
	return b


static func _dir(angle: float, facing: float) -> Vector2:
	return Vector2(sin(angle) * facing, cos(angle))


static func _tinted(colours: Dictionary, amount: float) -> Dictionary:
	var result: Dictionary = {}
	for key in colours:
		result[key] = Color(colours[key]).darkened(amount)
	return result


## A leg: thigh and calf in skin, the shorts' leg over the top of the thigh,
## and a running shoe that tips with the shin (`heel_lift` tips it further, toes down).
static func _leg(ci: CanvasItem, b: Dictionary, hip: Vector2, knee: Vector2, ankle: Vector2, colours: Dictionary, heel_lift: float = 0.0) -> void:
	var u: float = b.u
	var girth: float = 0.8 + 0.25 * float(b.build)
	var skin: Color = colours.skin
	var rim: float = b.rim
	var shin_dir: Vector2 = (ankle - knee).normalized()
	var back: Vector2 = shin_dir.orthogonal() * b.facing
	if back.dot(Vector2(-b.facing, 0.0)) < 0.0 and not b.horizontal:
		back = -back
	# The near leg runs on from the shorts already drawn on the hips, so
	# neither the skin nor the shorts' leg is outlined where it lies over them.
	var hips: PackedVector2Array = b.get("shorts", PackedVector2Array())
	Shapes.silhouette(ci, [Shapes.capsule_points(hip, knee, 4.6 * u * girth, 3.0 * u * girth),
		Shapes.capsule_points(knee, ankle, 2.9 * u * girth, 1.7 * u),
		Shapes.capsule_points(knee.lerp(ankle, 0.12) + back * 0.9 * u, knee.lerp(ankle, 0.5) + back * 0.5 * u, 3.0 * u * girth, 2.0 * u)], skin, rim, hips)
	ci.draw_line(knee.lerp(ankle, 0.15) - back * 1.4 * u, knee.lerp(ankle, 0.8) - back * 0.7 * u, skin.lightened(0.14), maxf(1.0, u * 0.9), true)
	var cuff: Vector2 = hip.lerp(knee, 0.42)
	Shapes.silhouette(ci, [Shapes.capsule_points(hip, cuff, 5.0 * u * girth, 3.9 * u * girth)], colours.shorts, rim, hips)
	Shapes.highlight(ci, hip, cuff, 5.0 * u * girth, 3.9 * u * girth, colours.shorts)
	_shoe(ci, b, ankle, shin_dir, colours, heel_lift)


static func _shoe(ci: CanvasItem, b: Dictionary, ankle: Vector2, shin_dir: Vector2, colours: Dictionary, heel_lift: float) -> void:
	var u: float = b.u
	var facing: float = b.facing
	var shin_angle: float = atan2(shin_dir.x * facing, shin_dir.y)
	var tip: float = clampf(-shin_angle * 0.65, -0.45, 1.1) + heel_lift
	var fwd: Vector2 = Vector2(cos(tip) * facing, sin(tip))
	var down: Vector2 = Vector2(-fwd.y, fwd.x) * facing
	var shape: Array = [Vector2(-0.6, -2.4), Vector2(2.6, -1.7), Vector2(6.2, -0.4), Vector2(8.2, 1.2), Vector2(7.6, 2.6),
		Vector2(-2.8, 2.6), Vector2(-3.0, 0.2)]
	var points := PackedVector2Array()
	for v in shape:
		points.append(ankle + (fwd * v.x + down * v.y) * u)
	Shapes.poly(ci, Shapes.smooth(points, 1), colours.shoe, b.rim)
	ci.draw_line(ankle + (fwd * -2.6 + down * 2.2) * u, ankle + (fwd * 7.6 + down * 2.2) * u, SOLE, maxf(1.0, u * 1.0), true)
	ci.draw_line(ankle + (fwd * 0.2 + down * 0.9) * u, ankle + (fwd * 4.4 + down * 0.2) * u, colours.top, maxf(1.0, u * 0.8), true)


## An arm: a short sleeve over the shoulder, then the upper arm, forearm and
## hand as one outlined shape, so the elbow and wrist bend without seams.
static func _arm(ci: CanvasItem, b: Dictionary, shoulder: Vector2, elbow: Vector2, hand: Vector2, colours: Dictionary) -> void:
	var u: float = b.u
	var girth: float = 0.82 + 0.2 * float(b.build)
	var rim: float = b.rim
	var along: Vector2 = (hand - elbow).normalized()
	Shapes.silhouette(ci, [Shapes.capsule_points(shoulder, elbow, 3.0 * u * girth, 2.1 * u * girth),
		Shapes.capsule_points(elbow, hand, 2.1 * u * girth, 1.6 * u),
		Shapes.ellipse_points(hand + along * 1.0 * u, 2.5 * u, 2.0 * u, along.angle(), 16)], colours.skin, rim)
	Shapes.highlight(ci, shoulder, elbow, 3.0 * u * girth, 2.1 * u * girth, colours.skin)
	Shapes.highlight(ci, elbow, hand, 2.1 * u * girth, 1.6 * u, colours.skin)
	var cuff: Vector2 = shoulder.lerp(elbow, 0.45)
	Shapes.silhouette(ci, [Shapes.capsule_points(shoulder, cuff, 4.0 * u * girth, 3.3 * u * girth)], colours.top, rim, _shoulder_cap(b, shoulder))
	Shapes.highlight(ci, shoulder, cuff, 4.0 * u * girth, 3.3 * u * girth, colours.top)


## The part of the shirt around a shoulder, where a sleeve drawn over it
## should flow into the shirt instead of showing its own seam. Empty until
## the shirt is drawn (the far arm sits behind it).
static func _shoulder_cap(b: Dictionary, shoulder: Vector2) -> PackedVector2Array:
	if not b.has("shirt"):
		return PackedVector2Array()
	var cap: Array = Geometry2D.intersect_polygons(b.shirt, Shapes.ellipse_points(shoulder, 5.0 * b.u, 5.0 * b.u))
	return cap[0] if not cap.is_empty() else PackedVector2Array()


## The torso in profile: back, chest and (with a bigger build) belly, a
## shirt over the shorts' waistband, and the neck.
static func _torso(ci: CanvasItem, b: Dictionary, colours: Dictionary) -> void:
	var u: float = b.u
	var build: float = float(b.build)
	var depth: float = 0.9 + 0.2 * build
	var belly: float = maxf(0.0, build - 1.0) * 7.0
	var front_profile: Array = [[-0.14, 6.0], [0.12, 6.2 + belly * 0.5], [0.38, 5.8 + belly], [0.62, 6.8 + belly * 0.45], [0.8, 7.6], [0.97, 5.0]]
	var back_profile: Array = [[0.99, 5.8], [0.84, 7.0], [0.6, 5.8], [0.36, 5.4], [0.1, 6.8], [-0.14, 6.4]]
	var neck_base: Vector2 = b.shoulder - b.up * 1.0 * u + b.front * 0.6 * u
	var neck_top: Vector2 = Head.centre(b) - b.up * 2.0 * u
	Shapes.limb(ci, neck_base, neck_top, 2.8 * u, 2.5 * u, colours.skin.darkened(0.06), b.rim)
	var shorts: PackedVector2Array = _outline(b, front_profile, back_profile, -0.14, 0.2, depth * 1.04)
	b.shorts = Shapes.smooth(shorts, 2)
	Shapes.poly(ci, b.shorts, colours.shorts, b.rim)
	var shirt: PackedVector2Array = Shapes.smooth(_outline(b, front_profile, back_profile, 0.12, 1.0, depth), 2)
	Shapes.poly(ci, shirt, colours.top, b.rim)
	b.shirt = shirt
	var lit_front: bool = Vector2(b.front).dot(Shapes.LIGHT) > 0.0
	var shade: PackedVector2Array = _edge_strip(b, back_profile if lit_front else front_profile, not lit_front, depth, 2.4 * u)
	Shapes.fill(ci, shade, Color(colours.top.darkened(0.22), 0.85))
	var hem_a: Vector2 = b.hip + b.up * 0.14 * SPINE * u
	ci.draw_line(hem_a + b.front * 5.6 * depth * u, hem_a - b.front * 5.4 * depth * u, colours.top.darkened(0.3), maxf(1.0, u * 0.7), true)
	var collar: Vector2 = b.shoulder + b.front * 3.2 * u - b.up * 0.2 * u
	ci.draw_arc(collar, 2.2 * u, 0.0, TAU, 12, colours.top.darkened(0.3), maxf(1.0, u * 0.7), true)


## A closed outline of the torso between `from` and `to` (shares of the spine).
static func _outline(b: Dictionary, front_profile: Array, back_profile: Array, from: float, to: float, depth: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for t in _stations(front_profile, from, to):
		points.append(_at(b, t, _width(front_profile, t) * depth))
	var back_stations: Array = _stations(back_profile, from, to)
	back_stations.reverse()
	for t in back_stations:
		points.append(_at(b, t, -_width(back_profile, t) * depth))
	return points


## The spine positions to sample between `from` and `to`, ascending.
static func _stations(profile: Array, from: float, to: float) -> Array:
	var result: Array = [from]
	for entry in profile:
		if float(entry[0]) > from + 0.01 and float(entry[0]) < to - 0.01:
			result.append(float(entry[0]))
	result.append(to)
	result.sort()
	return result


## The profile's depth at spine position `t`, interpolated between knots.
static func _width(profile: Array, t: float) -> float:
	var sorted: Array = profile.duplicate()
	sorted.sort_custom(func(a: Array, z: Array) -> bool: return float(a[0]) < float(z[0]))
	if t <= float(sorted[0][0]):
		return float(sorted[0][1])
	for i in range(sorted.size() - 1):
		var a: Array = sorted[i]
		var z: Array = sorted[i + 1]
		if t <= float(z[0]):
			return lerpf(float(a[1]), float(z[1]), (t - float(a[0])) / (float(z[0]) - float(a[0])))
	return float(sorted[-1][1])


## The point `out` body units in front of the spine (behind when negative).
static func _at(b: Dictionary, t: float, out: float) -> Vector2:
	return b.hip + b.up * t * SPINE * b.u + b.front * out * b.u


## A band of shade just inside one edge of the shirt.
static func _edge_strip(b: Dictionary, profile: Array, front_side: bool, depth: float, width: float) -> PackedVector2Array:
	var sign: float = 1.0 if front_side else -1.0
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for t in _stations(profile, 0.16, 0.95):
		var out: float = _width(profile, t) * depth
		outer.append(_at(b, t, sign * out))
		inner.append(_at(b, t, sign * (out - width / b.u)))
	inner.reverse()
	outer.append_array(inner)
	return outer
