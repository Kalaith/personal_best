extends RefCounted
## One coached session as a sequence of beats: the check-in, then one
## minigame per routine exercise with its peak moments. The screen asks for
## `prompt()`, runs the sliding bar, and reports where the marker stopped
## with `press()`. Nothing here touches the scene tree; every roll comes from
## the session's own generator. `SessionReport.apply` turns the finished
## session into progress and pay.
const Balance = preload("res://addons/hatchery/core/balance.gd")
const Det = preload("res://addons/hatchery/core/det.gd")
const Beats = preload("res://scripts/core/session_beats.gd")
const RoutineRules = preload("res://scripts/core/routine_rules.gd")
const Encouragement = preload("res://scripts/core/encouragement.gd")

var game: RefCounted
var client: RefCounted
var catalog: RefCounted
var rng: RandomNumberGenerator
var day: String = ""
var energy: float = 100.0
var mood: float = 60.0
var start_fatigue: float = 0.0
var start_rapport: float = 0.0
## The client's condition today, drawn before they walk in.
var condition: Dictionary = {}
## {correct, grade, question, text}
var check_in: Dictionary = {}
## One record per routine entry; see `_make_record`.
var records: Array = []
## -1 during the check-in.
var index: int = -1
var beat: Dictionary = {}
var injured: bool = false
var motivation_change: float = 0.0
var extra_fatigue: float = 0.0
var done: bool = false
## Score of the last counted press (the check-in counts here), -1 before any.
var last_score: float = -1.0
## Coaching takeaways noticed along the way: {kind: "worked"/"change",
## priority, text}. The wrap-up leads with the strongest of each kind.
var lessons: Array = []


func _init(owner: RefCounted, state: RefCounted, booked_day: String) -> void:
	game = owner
	client = state
	catalog = owner.catalog
	day = booked_day
	rng = owner.rng_for("session-" + state.id)
	start_fatigue = state.fatigue
	start_rapport = state.rapport
	condition = _draw_condition()
	for entry in state.routine:
		records.append(_make_record(entry))
	beat = _check_in_beat()


func _draw_condition() -> Dictionary:
	var weights: Dictionary = client.def.check_in_weights
	var id: Variant = Det.weighted_key(rng, weights, "fresh")
	for state in catalog.lines.check_in_states:
		if state.id == id:
			return state
	return catalog.lines.check_in_states[0]


func _make_record(entry: Dictionary) -> Dictionary:
	var def: Dictionary = catalog.exercise(entry.exercise)
	var presses: int = int(clampf(float(entry.sets) + 2.0, Balance.number("bar.min_presses"), Balance.number("bar.max_presses")))
	if def.minigame == "effort":
		presses = int(clampf(float(entry.sets), Balance.number("bar.min_presses"), Balance.number("bar.max_presses")))
	elif def.minigame == "technique":
		presses = int(clampf(float(entry.sets) + 1.0, Balance.number("bar.min_presses"), Balance.number("bar.max_presses") - 1))
	return {
		"entry": entry,
		"def": def,
		"presses": presses,
		"done": 0,
		"scores": [],
		"peaks": [],
		"peak_bonus": 0.0,
		"knowledge_hits": 0.0,
		"crossed": false,
		## Repeat number the client stopped after, or 0 when they did them all.
		"stopped_after": 0,
		"intensity": RoutineRules.intensity(entry, client, def),
	}


func prompt() -> Dictionary:
	return beat


func record() -> Dictionary:
	return records[index] if index >= 0 and index < records.size() else {}


func current_signal() -> String:
	return Beats.signal_for(energy)


func signal_cue() -> String:
	var cues: Array = catalog.lines.signals[current_signal()].cues
	return Det.pick(rng, cues, "")


func block() -> Dictionary:
	return game.block()


## The marker stopped at `position` (0..1). `visible` is false when a press
## came before a hidden zone was revealed or after it vanished. Returns
## {grade, score, text, tone} and moves on to the next beat.
func press(position: float, visible: bool = true) -> Dictionary:
	var outcome: Dictionary
	match beat.kind:
		"check_in":
			outcome = _resolve_check_in(position)
		"pace":
			outcome = _resolve_pace(position)
		"spot":
			outcome = _resolve_spot(position, visible)
		"cue":
			outcome = _resolve_cue(position)
		"encouragement":
			outcome = _resolve_encouragement(position)
		"effort":
			outcome = _resolve_effort(position)
		"peak":
			outcome = _resolve_peak(position)
	return outcome


# --- Check-in -------------------------------------------------------------


func _check_in_beat() -> Dictionary:
	var options: Array = catalog.lines.questions.map(func(q: Dictionary) -> Dictionary: return {"id": q.id, "label": q.label, "color": "c9a66b"})
	var name: String = client.def.short
	return {
		"kind": "check_in",
		"title": "Check-in",
		"instruction": "Read how %s walks in, then ask the question that fits." % name,
		"cue": String(condition.hint).format({"name": name}),
		"zones": Beats.choices(rng, options),
		"pass_seconds": Balance.number("bar.pass_seconds"),
	}


func _resolve_check_in(position: float) -> Dictionary:
	var hit: Dictionary = Beats.hit(beat.zones, position)
	var correct: bool = hit.zone_id == condition.question
	var name: String = client.def.short
	var base: float = 100.0 - client.fatigue
	var change: float = float(condition.energy)
	var text: String
	var tone: String = "good"
	if correct:
		if change < 0.0:
			change *= Balance.number("check_in.correct_energy_share")
		mood = Balance.number("check_in.start_mood") + float(condition.mood) * 0.5 + Balance.number("check_in.correct_mood")
		_change_rapport(Balance.number("check_in.correct_rapport"))
		text = "\"%s\" %s" % [condition.answer, condition.adapt]
	elif hit.grade == "miss":
		mood = Balance.number("check_in.start_mood") + float(condition.mood) + Balance.number("check_in.miss_mood")
		text = "You fumble the small talk. You start without knowing how they really are."
		tone = "bad"
	else:
		mood = Balance.number("check_in.start_mood") + float(condition.mood) + Balance.number("check_in.wrong_mood")
		text = "\"Fine, fine.\" That question didn't get at what was going on today."
		tone = "warn"
	energy = clampf(base + change, 5.0, 100.0)
	mood = clampf(mood, 0.0, 100.0)
	check_in = {"correct": correct, "grade": hit.grade, "question": hit.zone_id, "text": text, "answer": String(condition.answer) if correct else ""}
	last_score = 1.0 if correct else 0.0
	var asked: String = _question_label(condition.question)
	if correct and condition.id != "fresh":
		_lesson("worked", 2.0, "Asking \"%s\" let you adapt the session to %s." % [asked, name])
	elif not correct:
		_lesson("change", 3.0, "Read the walk-in: \"%s\" was the question that fitted." % asked)
	_next_exercise()
	return {"grade": "right" if correct else hit.grade if hit.grade == "miss" else "wrong", "score": 1.0 if correct else 0.0, "text": text, "tone": tone}


# --- Exercise beats ---------------------------------------------------------


func _next_exercise() -> void:
	index += 1
	if index >= records.size():
		done = true
		beat = {"kind": "done"}
		return
	beat = _normal_beat()


func _common(kind: String, instruction: String) -> Dictionary:
	var rec: Dictionary = record()
	return {
		"kind": kind,
		"title": rec.def.name,
		"minigame": rec.def.minigame,
		"instruction": instruction,
		"exercise": index + 1,
		"exercises": records.size(),
		"press": rec.done + 1,
		"presses": rec.presses,
		"signal": current_signal(),
		"cue": signal_cue(),
		"pass_seconds": Beats.pass_seconds(rec.intensity, energy),
	}


func _width() -> float:
	return Beats.zone_width(client.rapport, energy, mood)


func _normal_beat() -> Dictionary:
	var rec: Dictionary = record()
	var def: Dictionary = rec.def
	match def.minigame:
		"pace":
			var result: Dictionary = _common("pace", def.cue)
			var perfect: float = Balance.number("bar.perfect_width")
			if game.has_effect("precise_pace"):
				perfect += Balance.number("bar.treadmill_perfect_bonus")
			result["zones"] = Beats.target(rng, float(def.effort), _width(), perfect, Balance.number("bar.pace_drift"))
			result["effort_bands"] = true
			return result
		"technique":
			var fault: Dictionary = Det.pick(rng, def.faults, {})
			var result: Dictionary = _common("spot", "Watch the rep. Stop the marker when the fault shows.")
			var width: float = _width()
			result["zones"] = [Beats.zone("fault", fault.fault, rng.randf_range(width * 0.5, 1.0 - width * 0.5), width, Balance.number("bar.perfect_width"), "e0b24a")]
			result["fault"] = fault
			result["reveal_delay"] = rng.randf_range(Balance.number("bar.technique_reveal_min"), Balance.number("bar.technique_reveal_max"))
			result["window_seconds"] = Balance.number("bar.technique_window_passes") * float(result.pass_seconds)
			return result
		"encouragement":
			var situation: String = Encouragement.draw(rng, current_signal(), mood, last_score)
			var result: Dictionary = _common("encouragement", def.cue + " Read how they are right now, then choose how to encourage them.")
			var words: Dictionary = {"name": client.def.short}
			var cue: String = String(Encouragement.find(catalog, situation).cue)
			if not cue.is_empty():
				result["cue"] = cue.format(words)
			result["situation"] = situation
			result["best"] = Encouragement.best(catalog, client, situation)
			result["zones"] = Beats.choices(rng, catalog.lines.approaches)
			return result
		"effort":
			var result: Dictionary = _common("effort", "Repeat %d of %d. Read the signal: continue, ease off or stop?" % [rec.done + 1, rec.presses])
			result["zones"] = Beats.effort()
			return result
	return {}


func _peak_beat(final: bool) -> Dictionary:
	var result: Dictionary = _common("peak", "Peak moment! Push them, or hold back?")
	result["zones"] = Beats.peak()
	result["final"] = final
	result["press"] = record().done
	return result


## After a counted press: drain energy, then pick the next beat.
func _after_press(score: float, drain_scale: float = 1.0) -> void:
	var rec: Dictionary = record()
	rec.scores.append(score)
	rec.done += 1
	last_score = score
	var before: float = energy
	_drain(rec.intensity * drain_scale)
	var line: float = Balance.number("energy.peak_on_cross")
	if rec.done >= rec.presses:
		beat = _peak_beat(true)
	elif before >= line and energy < line and not rec.crossed and rec.def.minigame != "effort":
		rec.crossed = true
		beat = _peak_beat(false)
	else:
		beat = _normal_beat()


func _drain(intensity: float) -> void:
	var relief: float = Balance.number("energy.endurance_drain_relief") * float(client.attributes.endurance) / 100.0
	energy = clampf(energy - Balance.number("energy.drain_per_press") * intensity * (1.0 - relief), 0.0, 100.0)


func _graded(grade: String, good_text: String) -> Dictionary:
	match grade:
		"perfect":
			return {"grade": grade, "score": Beats.grade_score(grade), "text": "Perfect! " + good_text, "tone": "good"}
		"good":
			return {"grade": grade, "score": Beats.grade_score(grade), "text": "Good. " + good_text, "tone": "good"}
	return {"grade": "miss", "score": 0.0, "text": "Missed. The moment passed.", "tone": "bad"}


func _resolve_pace(position: float) -> Dictionary:
	var hit: Dictionary = Beats.hit(beat.zones, position)
	var outcome: Dictionary = _graded(hit.grade, "Right on the effort they should hold.")
	if hit.grade == "miss":
		var centre: float = (float(beat.zones[0].from) + float(beat.zones[0].to)) * 0.5
		outcome.text = "Off the mark: that cue would have them running too %s." % ("hard" if position > centre else "easy")
	record().knowledge_hits += outcome.score
	_after_press(outcome.score)
	return outcome


func _resolve_spot(position: float, visible: bool) -> Dictionary:
	var hit: Dictionary = Beats.hit(beat.zones, position) if visible else {"zone_id": "", "grade": "miss"}
	if hit.grade == "miss":
		var outcome: Dictionary = {"grade": "miss", "score": 0.0, "text": "You missed the fault: %s." % beat.fault.fault.to_lower(), "tone": "bad"}
		_after_press(0.0)
		return outcome
	var spotted: Dictionary = beat.fault
	var spot_score: float = Beats.grade_score(hit.grade)
	var options: Array = [{"id": spotted.cue, "label": spotted.cue}]
	for fault in record().def.faults:
		if fault.cue != spotted.cue:
			options.append({"id": fault.cue, "label": fault.cue})
	var next: Dictionary = _common("cue", "Spotted: %s. Which cue fixes it?" % spotted.fault.to_lower())
	next["zones"] = Beats.choices(rng, options)
	next["fault"] = spotted
	next["spot_score"] = spot_score
	next["press"] = record().done + 1
	beat = next
	return {"grade": hit.grade, "score": spot_score, "text": "Spotted it: %s." % spotted.fault.to_lower(), "tone": "good"}


func _resolve_cue(position: float) -> Dictionary:
	var hit: Dictionary = Beats.hit(beat.zones, position)
	var right: bool = hit.zone_id == beat.fault.cue
	var cue_score: float = Beats.grade_score(hit.grade) if right else 0.0
	var outcome: Dictionary
	if right:
		outcome = {"grade": hit.grade, "score": cue_score, "text": "\"%s!\" The rep cleans up." % beat.fault.cue, "tone": "good"}
	elif hit.grade == "miss":
		outcome = {"grade": "miss", "score": 0.0, "text": "No cue given. The fault carries on.", "tone": "bad"}
	else:
		outcome = {"grade": "wrong", "score": 0.0, "text": "\"%s\" doesn't fix %s." % [hit.zone_id, beat.fault.fault.to_lower()], "tone": "warn"}
	_after_press((float(beat.spot_score) + cue_score) * 0.5)
	return outcome


func _resolve_encouragement(position: float) -> Dictionary:
	var hit: Dictionary = Beats.hit(beat.zones, position)
	var personality: String = client.def.personality
	var usual: String = catalog.personalities[personality].approach
	var best: String = beat.best
	var situation: Dictionary = Encouragement.find(catalog, beat.situation)
	var steady: bool = beat.situation == "steady"
	var words: Dictionary = {
		"name": client.def.short,
		"state": situation.state,
		"usual": Encouragement.approach_name(catalog, usual),
		"best": Encouragement.approach_name(catalog, best).to_lower(),
	}
	var outcome: Dictionary
	if hit.zone_id == best:
		var text: String = catalog.lines.approach_right[personality] if steady else String(situation.right).format(words)
		outcome = {"grade": hit.grade, "score": Beats.grade_score(hit.grade), "text": text, "tone": "good"}
		_change_rapport(Balance.number("encouragement.right_rapport"))
		motivation_change += Balance.number("encouragement.right_motivation")
		if not steady:
			_lesson("worked", 3.0, "When %s was %s, %s encouragement was right." % [words.name, words.state, words.best])
	elif hit.grade == "miss":
		outcome = {"grade": "miss", "score": 0.0, "text": "You said nothing useful. They plod on alone.", "tone": "bad"}
	elif hit.zone_id == usual:
		var text: String = String(catalog.lines.encouragement_usual).format(words)
		outcome = {"grade": "usual", "score": Beats.grade_score(hit.grade) * Balance.number("encouragement.usual_score"), "text": text, "tone": "warn"}
		_lesson("change", 3.0, "When %s is %s, try %s encouragement, not their usual." % [words.name, words.state, words.best])
	else:
		var text: String = catalog.lines.approach_wrong[personality] if steady else String(situation.wrong).format(words)
		outcome = {"grade": "wrong", "score": Balance.number("bar.score_wrong_choice"), "text": text, "tone": "warn"}
		_change_rapport(Balance.number("encouragement.wrong_rapport"))
		if steady:
			_lesson("change", 2.0, "When %s is settled, use their usual %s encouragement." % [words.name, words.usual.to_lower()])
		else:
			_lesson("change", 3.0, "When %s is %s, %s encouragement helps most." % [words.name, words.state, words.best])
	_after_press(outcome.score)
	return outcome


## Effort management: continue, ease off or stop for each repeat. Stop
## ends the exercise there: the client walks it off and recovers. On red that
## is the right call, and the repeats they skip do not count against the
## score; stopping a client who had more in them leaves those repeats unscored
## at zero.
func _resolve_effort(position: float) -> Dictionary:
	var hit: Dictionary = Beats.hit(beat.zones, position)
	var colour: String = beat.signal
	var best: String = {"green": "continue", "amber": "continue" if block().push_on_amber else "ease", "red": "stop"}[colour]
	var near: String = {"green": "ease", "amber": "ease" if block().push_on_amber else "continue", "red": "ease"}[colour]
	var score: float = 0.0
	var tone: String = "bad"
	var text: String
	if hit.grade == "miss":
		text = "No decision. They carried on without a plan."
	elif hit.zone_id == best:
		score = Beats.grade_score(hit.grade)
		tone = "good"
		text = {"continue": "Another repeat, and they had it in them.", "ease": "Easing off kept this repeat useful without digging a hole.", "stop": "Stopping there protected them. Smart."}[best]
	elif hit.zone_id == near:
		score = 0.4
		tone = "warn"
		text = "Not quite. %s was the better call for a %s signal." % [{"continue": "Continuing", "ease": "Easing off", "stop": "Stopping"}[best], colour]
	else:
		text = "Wrong call for a %s signal: %s was right." % [colour, {"continue": "continuing", "ease": "easing off", "stop": "stopping"}[best]]
	if colour == "red" and hit.zone_id == "continue":
		extra_fatigue += Balance.number("peaks.effort_red_continue_fatigue")
		text += " That added fatigue."
		_lesson("change", 6.0, "On red, stop the repeats: continuing only added fatigue.")
	# Judging each repeat is pacing judgment too: it teaches Pacing Knowledge.
	record().knowledge_hits += score
	if hit.zone_id == "stop":
		text += _stop_exercise(score, best == "stop")
		return {"grade": hit.grade if score > 0.0 else "wrong", "score": score, "text": text, "tone": tone}
	var drain: float = {"continue": 1.3, "ease": 0.7}.get(hit.zone_id, 1.0)
	_after_press(score, drain)
	return {"grade": hit.grade if score > 0.0 else "wrong", "score": score, "text": text, "tone": tone}


## Ends the current exercise after a Stop: the client recovers instead of
## running the remaining repeats, and the session moves to the next exercise
## with no closing peak. Returns the line that says so.
func _stop_exercise(score: float, right: bool) -> String:
	var rec: Dictionary = record()
	rec.scores.append(score)
	rec.done += 1
	last_score = score
	var left: int = rec.presses - rec.done
	if left > 0:
		rec.stopped_after = rec.done
	if not right:
		for i in range(left):
			rec.scores.append(0.0)
	var before: float = energy
	energy = minf(energy + Balance.number("effort.stop_recovery"), 100.0)
	var name: String = client.def.short
	if right:
		_lesson("worked", 5.0, "Stopping on red protected %s." % name)
	else:
		_lesson("change", 4.0, "Save Stop for red: %s had more to give." % name)
	_next_exercise()
	var skipped: String = "" if left <= 0 else (" The last repeat is off." if left == 1 else " The last %d repeats are off." % left)
	if not right and left > 0:
		skipped += " They count as undone."
	return "%s %s walks it off and recovers (+%d energy)." % [skipped, name, int(round(energy - before))]


func _resolve_peak(position: float) -> Dictionary:
	var hit: Dictionary = Beats.hit(beat.zones, position)
	var rec: Dictionary = record()
	var colour: String = beat.signal
	var feedback: Dictionary = catalog.lines.peak_feedback
	var words: Dictionary = {"block": String(block().name)}
	var push_right: bool = colour == "green" or (colour == "amber" and block().push_on_amber)
	var text: String
	var tone: String = "good"
	if hit.zone_id == "":
		text = feedback.missed
		tone = "bad"
		_lesson("change", 2.0, "Make a call at every peak moment.")
		motivation_change += Balance.number("peaks.missed_motivation")
	elif (hit.zone_id == "push") == push_right:
		rec.peak_bonus += Balance.number("peaks.correct_bonus")
		_change_rapport(Balance.number("peaks.correct_rapport"))
		text = {"green": feedback.green_push, "red": feedback.red_hold}.get(colour, "")
		if colour == "amber":
			text = String(feedback.amber_push_right if push_right else feedback.amber_hold_right).format(words)
		if colour == "red":
			_lesson("worked", 4.0, "Holding %s back on red kept them safe." % client.def.short)
		elif colour == "amber":
			_lesson("worked", 2.5, "You followed the %s block's amber rule." % words.block)
	else:
		tone = "bad"
		match colour:
			"green":
				rec.peak_bonus -= Balance.number("peaks.green_hold_penalty")
				text = feedback.green_hold
				_lesson("change", 3.0, "Green means push: %s was fresh." % client.def.short)
			"amber":
				if hit.zone_id == "hold":
					rec.peak_bonus -= Balance.number("peaks.amber_hold_penalty")
					text = String(feedback.amber_hold_wrong).format(words)
				else:
					extra_fatigue += Balance.number("peaks.amber_push_fatigue")
					text = String(feedback.amber_push_wrong).format(words)
				_lesson("change", 4.0, "At amber in %s: %s." % [words.block, "push" if push_right else "hold back"])
			"red":
				extra_fatigue += Balance.number("peaks.red_push_fatigue")
				_change_rapport(Balance.number("peaks.red_push_rapport"))
				text = feedback.red_push
				_lesson("change", 7.0, "Red means hold back: pushing %s risked injury." % client.def.short)
				if Det.chance(rng, Balance.number("peaks.red_push_injury_chance")):
					injured = true
					text += " %s pulls up with a tweaked calf: a minor injury." % client.def.short
	rec.peaks.append({"signal": colour, "choice": hit.zone_id, "text": text, "tone": tone})
	if hit.zone_id == "push":
		_drain(rec.intensity)
	elif hit.zone_id == "hold":
		energy = minf(energy + 4.0, 100.0)
	if beat.final:
		_next_exercise()
	else:
		beat = _normal_beat()
	return {"grade": "right" if tone == "good" else "wrong", "score": 0.0, "text": text, "tone": tone}


func _lesson(kind: String, priority: float, text: String) -> void:
	lessons.append({"kind": kind, "priority": priority, "text": text})


func _question_label(id: String) -> String:
	for question in catalog.lines.questions:
		if question.id == id:
			return question.label
	return id


func _change_rapport(amount: float) -> void:
	client.rapport = clampf(client.rapport + amount, 0.0, 100.0)
