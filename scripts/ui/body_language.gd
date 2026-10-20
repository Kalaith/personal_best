extends RefCounted
## Turns how a client really is today into body language the trainer can
## read before asking anything: the stance they hold, the gestures they slip
## into now and then, how fast they walk in, and how they answer each
## check-in question with their body. Stance ids are the check-in states in
## data/lines.json plus "exhausted" (carried fatigue) and "injured"; the
## poses themselves are in figure_moods.gd.

## Carried fatigue from which a client looks worn out (the planner's red line).
const EXHAUSTED_FATIGUE: float = 50.0
## The gestures each stance slips into while waiting, taken in turn.
const IDLE_GESTURES: Dictionary = {
	"fresh": ["stretch"],
	"poor_sleep": ["rub_eyes", "nod_off"],
	"sore_legs": ["rub_calf"],
	"stressed": ["check_phone"],
	"exhausted": ["hands_on_knees"],
}
## How each question is answered with the body, by stance; "" is everyone
## else. The stance the check-in is about comes first, so the right question
## draws the clearest answer.
const REACTIONS: Dictionary = {
	"legs": {"sore_legs": "rub_calf", "injured": "rub_calf", "exhausted": "hands_on_knees", "fresh": "stretch", "": "shrug"},
	"sleep": {"poor_sleep": "yawn", "exhausted": "rub_eyes", "fresh": "straighten", "": "shrug"},
	"ready": {"fresh": "fist_pump", "": "shrug"},
	"week": {"stressed": "head_rub", "fresh": "open_arms", "": "shrug"},
}
## Seconds to walk in from the door: brisk when fresh, slow when hurting.
const WALK_SECONDS: Dictionary = {"fresh": 1.3, "stressed": 1.5, "poor_sleep": 2.0, "sore_legs": 2.1, "exhausted": 2.1, "injured": 2.4}


## Heavy carried fatigue outweighs feeling fresh: nobody bounces on their
## toes with legs that tired.
static func stance(condition_id: String, fatigue: float, injured: bool) -> Array:
	var result: Array = [condition_id]
	if fatigue >= EXHAUSTED_FATIGUE:
		result.erase("fresh")
		result.append("exhausted")
	if injured:
		result.append("injured")
	return result


static func idle_gestures(states: Array) -> Array:
	var result: Array = []
	for id in states:
		result.append_array(IDLE_GESTURES.get(id, []))
	return result


static func reaction(question: String, states: Array) -> String:
	var answers: Dictionary = REACTIONS.get(question, {})
	for id in states:
		if answers.has(id):
			return answers[id]
	return String(answers.get("", "shrug"))


static func walk_seconds(states: Array) -> float:
	var slowest: float = 0.0
	for id in states:
		slowest = maxf(slowest, float(WALK_SECONDS.get(id, 1.5)))
	return slowest if slowest > 0.0 else 1.5
