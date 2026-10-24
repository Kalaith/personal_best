extends RefCounted
## The one thing that worked and the one thing to change, for the top of the
## session wrap-up. Candidates come from the lessons the session noticed as it
## went (see `SessionSim.lessons`) plus what the finished report shows: an
## unsuitable exercise, a weak or sharp minigame, a client who arrived tired.
## The highest priority of each kind wins.
const Readiness = preload("res://scripts/core/readiness.gd")


## {worked, change}: one plain sentence each.
static func pick(sim: RefCounted, exercises: Array, fatigue_modifier: float) -> Dictionary:
	var candidates: Array = sim.lessons.duplicate()
	var name: String = sim.client.def.short
	var lines: Dictionary = sim.catalog.lines
	for i in range(exercises.size()):
		var exercise: Dictionary = exercises[i]
		var minigame: String = sim.records[i].def.minigame
		var score: float = float(exercise.score)
		if exercise.unsuitable:
			var why: String = exercise.notes[0].text if not exercise.notes.is_empty() else "it did not suit them today"
			candidates.append({"kind": "change", "priority": 6.0, "text": "%s gave half value. Change it in the routine." % exercise.name})
		if score >= 0.85:
			candidates.append({"kind": "worked", "priority": 1.0 + score, "text": "Sharp %s coaching lifted the whole session." % String(exercise.name).to_lower()})
		elif score < 0.5 and lines.minigame_advice.has(minigame):
			candidates.append({"kind": "change", "priority": 2.5, "text": String(lines.minigame_advice[minigame]).format({"exercise": String(exercise.name).to_lower(), "name": name})})
	if fatigue_modifier < 0.85:
		candidates.append({"kind": "change", "priority": 3.5, "text": "%s arrived tired: everything counted for %d%%. Rest or foam rolling." % [name, int(round(fatigue_modifier * 100.0))]})
	var worked: String = _best(candidates, "worked")
	var change: String = _best(candidates, "change")
	if worked.is_empty():
		worked = "Every right call builds rapport and widens the targets."
	if change.is_empty():
		change = "All good. Next: " + String(lines.guidance[Readiness.weakest(sim.client)[0]])
	return {"worked": worked, "change": change}


static func _best(candidates: Array, kind: String) -> String:
	var text: String = ""
	var top: float = -INF
	for entry in candidates:
		if entry.kind == kind and float(entry.priority) > top:
			top = float(entry.priority)
			text = entry.text
	return text
