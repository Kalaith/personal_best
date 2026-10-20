extends Control
## The side-on view of where training happens: inside the shed (with the
## equipment the gym owns), out on the road loop, or at the running track.
## Draws the client in their current pose and, optionally, the trainer.
const Figure = preload("res://scripts/ui/figure.gd")
const Room = preload("res://scripts/ui/gym_room.gd")
const Kit = preload("res://scripts/ui/gym_kit.gd")
const Outdoors = preload("res://scripts/ui/gym_outdoors.gd")

signal arrived

const TRAINER_LOOK: Dictionary = {"skin": "c98e66", "hair": "5a3a26", "hair_style": "short", "top": "e2803a", "shorts": "3a3f4a", "build": 1.0, "height": 1.0}

## "shed", "road" or "track".
var place: String = "shed"
var pose: String = "stand"
var look: Dictionary = {}
var expression: String = "smile"
## Animation cycles per second.
var tempo: float = 0.0
var rain: bool = false
## Dresses the road for the marathon: bunting and a cheering crowd.
var race_day: bool = false
var owned: Array = []
var show_trainer: bool = true
var show_desk: bool = false
## Client position as a share of the width.
var client_x: float = 0.45
var facing: float = 1.0
var phase: float = 0.0
var _scroll: float = 0.0
var _walk_from: float = 0.0
var _walk_to: float = 0.0
var _walk_time: float = 0.0
var _walk_left: float = 0.0


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_activity(where: String, new_pose: String, cycles_per_second: float) -> void:
	place = where
	pose = new_pose
	tempo = cycles_per_second
	queue_redraw()


## Walks the client from `from_x` to `to_x` (shares of the width), then emits `arrived`.
func walk(from_x: float, to_x: float, seconds: float) -> void:
	_walk_from = from_x
	_walk_to = to_x
	_walk_time = seconds
	_walk_left = seconds
	client_x = from_x
	facing = 1.0 if to_x >= from_x else -1.0
	pose = "walk"
	tempo = 1.1


func _process(delta: float) -> void:
	phase = fposmod(phase + delta * tempo, 1.0)
	if pose == "run":
		_scroll += delta * 140.0 * tempo
	if _walk_left > 0.0:
		_walk_left = maxf(_walk_left - delta, 0.0)
		client_x = lerpf(_walk_from, _walk_to, 1.0 - _walk_left / _walk_time)
		if _walk_left <= 0.0:
			pose = "stand"
			tempo = 0.0
			facing = 1.0
			arrived.emit()
	queue_redraw()


func _draw() -> void:
	var ground: float = size.y * 0.84
	var figure_size: float = size.y * 0.52
	var k: float = figure_size / 100.0
	var treadmill_run: bool = place == "shed" and pose == "run"
	match place:
		"road":
			Outdoors.road(self, size, ground, _scroll, rain, phase)
			if race_day:
				Outdoors.race_day(self, size, ground, _scroll, phase)
		"track":
			Outdoors.track(self, size, ground, _scroll, rain)
		_:
			var wall_base: float = size.y * 0.72
			Room.draw(self, size, wall_base, ground, k * 0.85, phase, rain)
			Kit.draw(self, size, wall_base, k * 0.85, owned, _in_use(treadmill_run))
			if show_desk:
				Kit.desk(self, Vector2(size.x * 0.28, ground + 2.0), k * 1.05)
	if show_trainer:
		var trainer_x: float = size.x * (0.2 if place == "shed" else 0.16)
		var trainer_pose: String = "run" if pose == "run" and place != "shed" else "coach"
		Figure.draw(self, Vector2(trainer_x, ground + 4.0), TRAINER_LOOK, trainer_pose, fposmod(phase + 0.3, 1.0), figure_size * 0.96, 1.0, "smile")
	if not look.is_empty():
		var feet := Vector2(size.x * client_x, ground + 4.0)
		if treadmill_run:
			var mill_k: float = k * 1.05
			Kit.treadmill(self, feet + Vector2(-34.0 * mill_k, 0.0), mill_k, _scroll * 0.4)
			feet.y -= 12.5 * mill_k
		Figure.draw(self, feet, look, pose, phase, figure_size, facing, expression)
	if rain and place != "shed":
		Outdoors.rain(self, size, phase, _scroll)


## The piece of kit the client is using, which the back wall leaves out.
func _in_use(treadmill_run: bool) -> String:
	if treadmill_run:
		return "treadmill"
	return {"row": "rowing_machine", "step": "step_box"}.get(pose, "")
