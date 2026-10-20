extends RefCounted
## Body language for a standing client, laid over the "stand" pose from
## figure_poses.gd: stances they hold while waiting (how they carry
## themselves) and short gestures played over a stance (a yawn, rubbing a
## calf, a fist pump). Stances combine; a gesture eases in, holds and eases
## back out to the stance. Read by figure.gd.
##
## A mood is {stance: [ids], gesture: id, progress: 0..1, time: seconds};
## while walking it is {stance: [ids], walking: true, spin: radians} and only
## the head, the torso, the face and a limp carry over.
## Limb targets use the poses' body units: hands from the shoulder, ankles
## from the ground point, x the way the figure faces and y down. A stance or
## gesture may also set `face` (an expression for figure_head.gd) and `prop`.

## Where the hands and ankles sit in the plain standing pose.
const REST: Dictionary = {
	"near_hand": Vector2(4.9, 30.5), "far_hand": Vector2(-0.1, 30.9),
	"near_ankle": Vector2(1.8, -2.0), "far_ankle": Vector2(-1.8, -2.0),
}
## How each stance carries over into a walk.
const CARRY: Dictionary = {
	"fresh": {"lean": -0.04, "neck": 0.12, "face": "smile"},
	"poor_sleep": {"lean": 0.12, "neck": -0.5, "face": "tired"},
	"sore_legs": {"lean": 0.06, "limp": 2.5, "face": "tense"},
	"stressed": {"neck": -0.25, "face": "tense"},
	"exhausted": {"lean": 0.16, "neck": -0.3, "face": "tired"},
	"injured": {"lean": 0.08, "limp": 4.0, "face": "tense"},
}
## Seconds each gesture lasts, start to finish.
const LENGTHS: Dictionary = {
	"stretch": 1.5, "fist_pump": 1.2, "open_arms": 1.3, "straighten": 1.2,
	"yawn": 1.7, "rub_eyes": 1.5, "nod_off": 1.9,
	"rub_calf": 1.7, "hands_on_knees": 1.8,
	"head_rub": 1.6, "check_phone": 2.0, "shrug": 1.1,
}


static func length(gesture: String) -> float:
	return float(LENGTHS.get(gesture, 1.2))


static func apply(p: Dictionary, mood: Dictionary, u: float) -> void:
	if mood.get("walking", false):
		_carry(p, mood, u)
		return
	p.merge(REST, true)
	var time: float = float(mood.get("time", 0.0))
	var face: String = ""
	for stance in mood.get("stance", []):
		var held: String = _stance(p, String(stance), time, u)
		if not held.is_empty():
			face = held
	var gesture: String = String(mood.get("gesture", ""))
	if not gesture.is_empty():
		var progress: float = clampf(float(mood.get("progress", 0.0)), 0.0, 1.0)
		var weight: float = smoothstep(0.0, 0.2, progress) * (1.0 - smoothstep(0.8, 1.0, progress))
		var target: Dictionary = _gesture(gesture, progress, u)
		for key in target:
			match key:
				"face":
					if weight > 0.3:
						face = target.face
				"prop":
					if weight > 0.3:
						p.prop = target.prop
				_:
					var from: Variant = p.get(key, Vector2.ZERO if target[key] is Vector2 else 0.0)
					p[key] = lerp(from, target[key], weight)
	if not face.is_empty():
		p.face = face


## A walk in the stance's spirit: head and torso as they hold them, and a
## dip of the hips each time the sore leg takes the weight.
static func _carry(p: Dictionary, mood: Dictionary, u: float) -> void:
	for stance in mood.get("stance", []):
		var carry: Dictionary = CARRY.get(stance, {})
		p.lean += float(carry.get("lean", 0.0))
		p.neck = float(p.get("neck", 0.0)) + float(carry.get("neck", 0.0))
		p.hip_y += maxf(0.0, -sin(float(mood.get("spin", 0.0)))) * float(carry.get("limp", 0.0)) * u
		if carry.has("face"):
			p.face = carry.face


## Holds a stance on the pose (adding to what earlier stances set) and
## returns the face that goes with it, if any.
static func _stance(p: Dictionary, stance: String, time: float, u: float) -> String:
	match stance:
		"fresh":
			# Bouncing on their toes, chin up, arms loose.
			var bounce: float = absf(sin(time * TAU * 0.9))
			p.hip_y -= bounce * 2.4 * u
			p.near_ankle += Vector2(0.0, -bounce * 1.8)
			p.far_ankle += Vector2(0.0, -bounce * 1.8)
			p.near_heel_lift = float(p.get("near_heel_lift", 0.0)) + bounce * 0.4
			p.far_heel_lift = float(p.get("far_heel_lift", 0.0)) + bounce * 0.4
			p.lean -= 0.05
			p.neck = float(p.get("neck", 0.0)) + 0.12
			# Elbows bent like a runner at the start line, hands swinging a little.
			p.near_hand = Vector2(9.0 + sin(time * TAU * 0.9) * 1.5, 21.0)
			p.far_hand = Vector2(6.0, 23.0)
			return "smile"
		"poor_sleep":
			# Head hanging, a slow sway, arms dead at their sides.
			p.lean += 0.14
			p.neck = float(p.get("neck", 0.0)) - 0.55
			p.hip_x += sin(time * TAU * 0.3) * 1.2 * u
			return "tired"
		"sore_legs":
			# Weight off the near leg: knee soft, heel up, hips over the far leg.
			p.hip_x -= 2.5 * u
			p.near_ankle = Vector2(4.5, -6.0)
			p.near_heel_lift = float(p.get("near_heel_lift", 0.0)) + 0.5
			p.lean += 0.06
			p.near_hand = Vector2(6.0, 27.0)
			return "tense"
		"stressed":
			# Arms folded tight, head down, a foot tapping, weight shifting.
			p.near_hand = Vector2(8.0, 14.5)
			p.far_hand = Vector2(9.0, 13.0)
			p.neck = float(p.get("neck", 0.0)) - 0.2
			p.hip_x += sin(time * TAU * 0.45) * 1.4 * u
			p.near_heel_lift = float(p.get("near_heel_lift", 0.0)) - maxf(0.0, sin(time * TAU * 2.2)) * 0.45
			return "tense"
		"exhausted":
			# Slumped: shoulders forward, head low, knees soft, slow deep breaths.
			p.lean += 0.18
			p.neck = float(p.get("neck", 0.0)) - 0.3
			p.hip_y += (3.0 + sin(time * TAU * 0.5) * 0.8) * u
			p.near_hand += Vector2(1.5, 0.0)
			return "tired"
		"injured":
			# Protecting the near leg: barely touching the floor with it.
			p.hip_x -= 3.5 * u
			p.near_ankle = Vector2(6.0, -9.0)
			p.near_heel_lift = float(p.get("near_heel_lift", 0.0)) + 0.6
			p.lean += 0.08
			return "tense"
	return ""


## The pose a gesture reaches for at `k` (0..1 through it).
static func _gesture(gesture: String, k: float, u: float) -> Dictionary:
	var beat: float = sin(k * TAU * 2.0)
	match gesture:
		"stretch":
			return {"near_hand": Vector2(3.0, -30.0), "far_hand": Vector2(1.0, -30.5), "near_ankle": Vector2(1.8, -5.0), "far_ankle": Vector2(-1.8, -5.0),
				"near_heel_lift": 0.6, "far_heel_lift": 0.6, "hip_y": -3.0 * u, "lean": -0.1, "neck": 0.3, "face": "beam"}
		"fist_pump":
			return {"near_hand": Vector2(12.0, -18.0 + beat * 3.0), "far_hand": Vector2(6.0, 22.0), "hip_y": -absf(beat) * 2.5 * u,
				"lean": -0.04, "neck": 0.25, "face": "beam"}
		"open_arms":
			return {"near_hand": Vector2(17.0, 8.0), "far_hand": Vector2(15.0, 10.0), "lean": -0.08, "neck": 0.2, "face": "beam"}
		"straighten":
			return {"lean": -0.1, "neck": 0.3 - maxf(0.0, beat) * 0.25, "hip_y": -1.5 * u, "near_hand": Vector2(4.0, 30.0), "face": "beam"}
		"yawn":
			return {"near_hand": Vector2(9.0, -9.0), "far_hand": Vector2(-5.0, -27.0), "lean": -0.18, "neck": 0.55, "face": "yawn"}
		"rub_eyes":
			var circle: Vector2 = Vector2(sin(k * TAU * 3.0), cos(k * TAU * 3.0)) * 1.2
			return {"near_hand": Vector2(8.5, -11.5) + circle, "neck": -0.2, "lean": 0.08, "face": "closed"}
		"nod_off":
			# The head sinks, then jerks back up.
			var sink: float = smoothstep(0.0, 0.7, k) * (1.0 - smoothstep(0.72, 0.8, k))
			return {"neck": -0.9 * sink + 0.15 * smoothstep(0.72, 0.8, k), "lean": 0.12 * sink, "face": "closed" if k < 0.74 else "tired"}
		"rub_calf":
			# Bends over the sore front leg, toes up, rubbing below the knee.
			return {"hip_x": -8.0 * u, "hip_y": 11.0 * u, "lean": 1.3, "near_ankle": Vector2(9.0, -2.5), "far_ankle": Vector2(-2.0, -2.2),
				"near_heel_lift": -0.35, "near_hand": Vector2(-20.0 + sin(k * TAU * 3.0) * 2.5, 28.0), "far_hand": Vector2(-24.0, 22.0), "face": "wince"}
		"hands_on_knees":
			return {"hip_x": -7.0 * u, "hip_y": 10.0 * u, "lean": 1.15 + sin(k * TAU * 2.5) * 0.05, "near_ankle": Vector2(1.5, -2.2), "far_ankle": Vector2(-1.5, -2.2),
				"near_hand": Vector2(-18.0, 23.5), "far_hand": Vector2(-17.0, 24.5), "neck": 0.35, "face": "pant"}
		"head_rub":
			return {"near_hand": Vector2(3.0 + sin(k * TAU * 2.5) * 1.5, -18.0), "neck": -0.35, "lean": 0.06 + smoothstep(0.6, 0.8, k) * 0.08, "face": "tense"}
		"check_phone":
			return {"near_hand": Vector2(11.0, 10.0), "far_hand": Vector2(10.0, 12.0), "neck": -0.6, "prop": "phone", "face": "tense"}
		"shrug":
			return {"near_hand": Vector2(14.0, 12.0), "far_hand": Vector2(12.0, 14.0), "neck": 0.1 + absf(beat) * 0.12, "hip_y": -1.0 * u, "lean": -0.05, "face": "flat"}
	return {}
