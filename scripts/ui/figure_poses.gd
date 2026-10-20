extends RefCounted
## Joint angles, offsets and reach targets for every training pose, at a
## point `spin` (radians) through its cycle. Read by figure.gd.
##
## Angles are measured from straight down; positive points the way the
## figure faces. `lean` tips the torso forward from upright. Instead of
## angles a pose may give limb targets in body units (x the way the figure
## faces, y down):
##   near_ankle / far_ankle   from the ground point under the figure
##   near_hand / far_hand     from the shoulder
##   near_grip / far_grip     in the torso's frame (x forward of the chest,
##                            y down the spine from the shoulder)
## and the limb bends to reach them. Lying poses set `horizontal`, and
## `tilt` raises their shoulders a little further off the floor.
##
## A form `fault` (a technique fault's `show` id) bends the pose by
## `amount` (0..1) so the client visibly does it: `near_knee_shift` and
## `far_knee_shift` nudge the knees, `near_heel_lift` and `far_heel_lift`
## tip the toes down,
## `neck` cranes the head up and `cheeks` puffs them out.


static func pose(name: String, spin: float, u: float, fault: String = "", amount: float = 0.0) -> Dictionary:
	if amount > 0.0:
		spin = _rushed(fault, spin, amount)
	var s: float = sin(spin)
	var c: float = cos(spin)
	var p: Dictionary = {"hip_x": 0.0, "hip_y": 0.0, "lean": 0.02, "near_thigh": 0.06, "near_shin": 0.02, "far_thigh": -0.06, "far_shin": -0.02,
		"near_upper": 0.1, "near_fore": 0.22, "far_upper": -0.08, "far_fore": 0.08}
	match name:
		"stand":
			p.hip_y = s * 0.3 * u
		"walk":
			p.hip_y = -absf(s) * 1.5 * u
			p.lean = 0.04
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
			p.lean = 0.14
			p.near_thigh = 0.75 * s + 0.1
			p.far_thigh = -0.75 * s + 0.1
			p.near_shin = p.near_thigh - 0.6 - 0.6 * maxf(0.0, -s)
			p.far_shin = p.far_thigh - 0.6 - 0.6 * maxf(0.0, s)
			p.near_upper = -0.7 * s
			p.far_upper = 0.7 * s
			p.near_fore = p.near_upper + 1.6
			p.far_fore = p.far_upper + 1.6
		"squat", "back_squat":
			_squat(p, (1.0 - c) * 0.5, u, name == "back_squat")
		"lunge":
			var d: float = (1.0 - c) * 0.5
			p.hip_x = -2.0 * u
			p.hip_y = d * 17.0 * u
			p.lean = 0.04
			p.near_ankle = Vector2(13.0, -2.5)
			p.far_ankle = Vector2(-17.0, -4.0)
			p.near_upper = 0.04
			p.near_fore = 0.02
			p.far_upper = -0.04
			p.far_fore = -0.02
			p.prop = "dumbbells"
		"step":
			_step(p, (1.0 - c) * 0.5, u)
		"skip":
			p.hip_y = -absf(s) * 7.0 * u
			p.near_thigh = 0.1
			p.far_thigh = 0.05
			p.near_shin = -0.15
			p.far_shin = -0.2
			p.near_upper = 0.2
			p.near_fore = 0.95
			p.far_upper = 0.15
			p.far_fore = 0.9
			p.prop = "rope"
		"plank":
			p.horizontal = true
			p.hip_y = 32.0 * u + s * 0.6 * u
			p.near_ankle = Vector2(-42.0, -3.0)
			p.far_ankle = Vector2(-42.5, -3.0)
			p.near_upper = 0.08
			p.near_fore = 1.57
			p.far_upper = 0.04
			p.far_fore = 1.57
			p.prop = "mat"
		"roll":
			p.horizontal = true
			p.tilt = 1.0
			p.hip_y = 31.0 * u
			p.hip_x = s * 6.0 * u
			p.near_ankle = Vector2(-42.0 + s * 6.0, -10.0)
			p.far_ankle = Vector2(-42.5 + s * 6.0, -10.0)
			p.near_upper = 0.12
			p.near_fore = 1.57
			p.far_upper = 0.08
			p.far_fore = 1.57
			p.prop = "roller"
		"row":
			_row(p, (1.0 - c) * 0.5, u)
		"wave":
			p.near_upper = 2.6 + s * 0.25
			p.near_fore = 3.0 + s * 0.4
		"coach":
			p.hip_y = s * 0.3 * u
			p.near_grip = Vector2(9.0, 15.0)
			p.far_grip = Vector2(8.0, 18.0)
			p.prop = "clipboard"
	if amount > 0.0:
		_fault(p, fault, spin, u, amount)
	return p


## Faults about tempo replay the cycle with one half hurried: a lunge that
## drops onto the back knee, a step-up that falls off the box.
static func _rushed(fault: String, spin: float, amount: float) -> float:
	var t: float = fposmod(spin, TAU) / PI
	var bend: float = 1.0 / (1.0 + 2.5 * amount)
	match fault:
		"knee_slam":
			if t < 1.0:
				return pow(t, bend) * PI
		"drop_fast":
			if t >= 1.0:
				return (1.0 + pow(t - 1.0, bend)) * PI
	return spin


static func _fault(p: Dictionary, fault: String, spin: float, u: float, a: float) -> void:
	var d: float = (1.0 - cos(spin)) * 0.5
	match fault:
		"knees_cave":
			p.near_knee_shift = Vector2(4.0 * d + sin(spin * 6.0) * 0.8 * d, 0.0) * a
			p.far_knee_shift = Vector2(2.5 * d, 0.0) * a
		"heels_lift":
			p.near_ankle += Vector2(0.5, -3.5) * d * a
			p.far_ankle += Vector2(0.5, -3.5) * d * a
			p.near_heel_lift = 0.6 * d * a
			p.far_heel_lift = 0.6 * d * a
		"chest_drop":
			p.lean += 0.5 * d * a
		"back_round":
			p.lean += 0.4 * d * a
			p.hip_x -= 3.0 * d * a * u
		"bar_forward":
			p.near_grip += Vector2(5.0, 0.0) * d * a
			p.far_grip += Vector2(5.0, 0.0) * d * a
			p.lean += 0.15 * d * a
		"knee_past_toes":
			p.hip_x += 7.0 * d * a * u
		"torso_lean":
			p.lean += 0.55 * d * a
		"knee_slam":
			p.hip_y += 3.0 * d * a * u
		"back_foot_push":
			var e: float = smoothstep(0.0, 1.0, d)
			p.hip_y -= sin(e * PI) * 5.0 * a * u
			p.lean -= 0.1 * a
			p.far_ankle += Vector2(-4.0, 0.0) * sin(e * PI) * a
			p.far_heel_lift = 0.5 * sin(e * PI) * a
		"knee_wobble":
			p.near_knee_shift = Vector2(sin(spin * 7.0) * 2.8, 0.0) * a
		"hips_sag":
			p.hip_y += 6.0 * a * u
			p.tilt = float(p.get("tilt", 0.0)) + 6.5 * a
			p.near_ankle += Vector2(-1.5, 0.0) * a
			p.far_ankle += Vector2(-1.5, 0.0) * a
		"breath_hold":
			p.hip_y -= sin(spin) * 0.6 * u * a
			p.cheeks = a
		"neck_crane":
			p.neck = 0.95 * a


## A squat with the feet planted: hips sit back and down, the chest stays up.
## Goblet squats hold a dumbbell at the chest; back squats carry a barbell.
static func _squat(p: Dictionary, d: float, u: float, barbell: bool) -> void:
	p.hip_x = -d * 15.0 * u
	p.hip_y = d * 23.0 * u
	p.lean = 0.04 + d * (0.62 if barbell else 0.5)
	p.near_ankle = Vector2(1.5, -2.5)
	p.far_ankle = Vector2(-1.0, -2.5)
	if barbell:
		p.near_grip = Vector2(-3.0, 0.5)
		p.far_grip = Vector2(-2.5, 0.5)
		p.prop = "barbell"
	else:
		p.near_grip = Vector2(8.0, 9.0)
		p.far_grip = Vector2(7.0, 10.0)
		p.prop = "goblet"


## A step-up: the lead foot stays on the box, the trailing foot rises to
## meet it, the hips travel up and forward.
static func _step(p: Dictionary, d: float, u: float) -> void:
	var e: float = smoothstep(0.0, 1.0, d)
	p.hip_x = e * 9.0 * u
	p.hip_y = -e * 17.0 * u
	p.lean = 0.12 - e * 0.1
	p.near_ankle = Vector2(15.0, -19.0)
	p.far_ankle = Vector2(-3.0, -2.5).lerp(Vector2(9.0, -19.0), e) + Vector2(0.0, -sin(e * PI) * 6.0)
	p.near_upper = -0.25 + e * 0.35
	p.near_fore = p.near_upper + 0.6
	p.far_upper = 0.25 - e * 0.35
	p.far_fore = p.far_upper + 0.6
	p.prop = "step"


## One rowing stroke, `d` 0 at the catch and 1 at the finish: legs drive,
## then the back swings, then the arms pull the handle to the ribs.
static func _row(p: Dictionary, d: float, u: float) -> void:
	var legs: float = smoothstep(0.0, 0.6, d)
	var back: float = smoothstep(0.3, 0.8, d)
	var arms: float = smoothstep(0.55, 1.0, d)
	p.hip_y = 34.0 * u
	p.hip_x = lerpf(3.0, -21.0, legs) * u
	p.lean = lerpf(0.42, -0.32, back)
	p.near_ankle = Vector2(23.0, -11.0)
	p.far_ankle = Vector2(22.5, -11.0)
	p.near_hand = Vector2(11.0, 18.0).lerp(Vector2(9.0, 15.0), arms)
	p.far_hand = Vector2(10.5, 18.5).lerp(Vector2(8.5, 15.5), arms)
	p.prop = "rower"
