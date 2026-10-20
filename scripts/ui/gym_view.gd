extends Control
## The side-on view of where training happens: inside the shed (with the
## equipment the gym owns), out on the road loop, or at the running track.
## Draws the client in their current pose and, optionally, the trainer.
const Figure = preload("res://scripts/ui/figure.gd")

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
	if pose == "run" and place != "shed":
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
	match place:
		"road":
			_draw_road(ground)
		"track":
			_draw_track(ground)
		_:
			_draw_shed(ground)
	var figure_size: float = size.y * 0.52
	if show_trainer:
		var trainer_x: float = size.x * (0.2 if place == "shed" else 0.16)
		var trainer_pose: String = "run" if pose == "run" and place != "shed" else "stand"
		Figure.draw(self, Vector2(trainer_x, ground + 4.0), TRAINER_LOOK, trainer_pose, fposmod(phase + 0.3, 1.0), figure_size * 0.96, 1.0, "smile")
		if trainer_pose == "stand":
			draw_rect(Rect2(trainer_x + figure_size * 0.07, ground - figure_size * 0.5, figure_size * 0.09, figure_size * 0.12), Color("f2ead8"))
	if not look.is_empty():
		Figure.draw(self, Vector2(size.x * client_x, ground + 4.0), look, pose, phase, figure_size, facing, expression)
	if rain and place != "shed":
		_draw_rain()


func _draw_sky(ground: float) -> void:
	var top: Color = Color("8a9aa6") if rain else Color("8cc4e8")
	var bottom: Color = Color("b8c0c4") if rain else Color("f6dcb0")
	var bands: int = 12
	for i in range(bands):
		var t: float = float(i) / float(bands)
		draw_rect(Rect2(0, ground * t, size.x, ground / bands + 1.0), top.lerp(bottom, t))


func _draw_road(ground: float) -> void:
	_draw_sky(ground)
	var hill := Color("8fae6a") if not rain else Color("7d9468")
	for i in range(7):
		var x: float = fposmod(float(i) * 260.0 - _scroll * 0.2, size.x + 260.0) - 130.0
		draw_circle(Vector2(x, ground + 60.0), 170.0, hill.darkened(0.05 * (i % 2)))
	for i in range(9):
		var x: float = fposmod(float(i) * 190.0 - _scroll * 0.6, size.x + 190.0) - 95.0
		if i % 3 == 0:
			draw_rect(Rect2(x - 30, ground - 70, 60, 70), Color("d9b38c"))
			draw_colored_polygon(PackedVector2Array([Vector2(x - 38, ground - 70), Vector2(x, ground - 100), Vector2(x + 38, ground - 70)]), Color("a5503a"))
			draw_rect(Rect2(x - 8, ground - 30, 16, 30), Color("6b4a35"))
		else:
			draw_rect(Rect2(x - 4, ground - 40, 8, 40), Color("6b4a35"))
			draw_circle(Vector2(x, ground - 55), 26.0, Color("5f8f4a"))
	draw_rect(Rect2(0, ground - 6, size.x, size.y - ground + 6), Color("5d5a58"))
	draw_rect(Rect2(0, ground - 8, size.x, 4), Color("8c8a86"))
	for i in range(12):
		var x: float = fposmod(float(i) * 120.0 - _scroll, size.x + 120.0) - 60.0
		draw_rect(Rect2(x, ground + 16, 50, 5), Color("e8e2cf"))


func _draw_track(ground: float) -> void:
	_draw_sky(ground)
	draw_rect(Rect2(0, ground - 110, size.x, 60), Color("7a8a96"))
	for i in range(int(size.x / 18.0)):
		draw_circle(Vector2(i * 18.0 + 9.0, ground - 96.0 + (i % 3) * 14.0), 5.0, Color("c8b8a0").darkened(0.15 * (i % 4)))
	draw_rect(Rect2(0, ground - 50, size.x, size.y - ground + 50), Color("b5523e"))
	for lane in range(4):
		draw_line(Vector2(0, ground - 40 + lane * 22), Vector2(size.x, ground - 40 + lane * 22), Color("f0e6d8"), 2.0)
	for i in range(6):
		var x: float = fposmod(float(i) * 240.0 - _scroll, size.x + 240.0) - 120.0
		draw_line(Vector2(x, ground - 40), Vector2(x + 30, ground + 26), Color(1, 1, 1, 0.35), 2.0)


func _draw_shed(ground: float) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("a8774f"))
	for i in range(int(size.x / 46.0) + 1):
		draw_line(Vector2(i * 46.0, 0), Vector2(i * 46.0, ground), Color("8d6040"), 2.0)
	draw_rect(Rect2(0, 0, size.x, 22), Color("6d4a33"))
	var window := Rect2(size.x * 0.58, ground * 0.16, size.x * 0.17, ground * 0.32)
	draw_rect(window, Color("8a9aa6") if rain else Color("a9d4ee"))
	if rain:
		for i in range(14):
			var x: float = window.position.x + fposmod(i * 23.0 + phase * 40.0, window.size.x)
			draw_line(Vector2(x, window.position.y + 6), Vector2(x - 4, window.position.y + window.size.y - 6), Color(1, 1, 1, 0.5), 1.0)
	draw_rect(window, Color("5b3d2a"), false, 6.0)
	draw_line(window.get_center() - Vector2(0, window.size.y * 0.5), window.get_center() + Vector2(0, window.size.y * 0.5), Color("5b3d2a"), 4.0)
	var door := Rect2(size.x * 0.88, ground * 0.25, size.x * 0.1, ground * 0.75)
	draw_rect(door, Color("6b4430"))
	draw_circle(door.position + Vector2(door.size.x * 0.18, door.size.y * 0.55), 4.0, Color("d8b46a"))
	draw_rect(Rect2(0, ground, size.x, size.y - ground), Color("6e5845"))
	draw_line(Vector2(0, ground), Vector2(size.x, ground), Color("4e3c2e"), 3.0)
	draw_circle(Vector2(size.x * 0.42, 34), 9.0, Color("ffe9a8"))
	draw_line(Vector2(size.x * 0.42, 22), Vector2(size.x * 0.42, 26), Color("3a2a20"), 2.0)
	_draw_equipment(ground)
	if show_desk:
		draw_rect(Rect2(size.x * 0.27, ground - 52, 120, 10), Color("5b3d2a"))
		draw_rect(Rect2(size.x * 0.27 + 8, ground - 42, 8, 42), Color("5b3d2a"))
		draw_rect(Rect2(size.x * 0.27 + 104, ground - 42, 8, 42), Color("5b3d2a"))
		draw_rect(Rect2(size.x * 0.27 + 40, ground - 62, 34, 10), Color("e9e2d0"))


## The kit along the back wall: what the gym owns is what you see.
func _draw_equipment(ground: float) -> void:
	var x: float = 16.0
	if owned.has("dumbbells"):
		draw_rect(Rect2(x, ground - 70, 70, 6), Color("4a4a4a"))
		draw_rect(Rect2(x + 4, ground - 64, 6, 64), Color("4a4a4a"))
		draw_rect(Rect2(x + 60, ground - 64, 6, 64), Color("4a4a4a"))
		for i in range(5):
			draw_rect(Rect2(x + 8 + i * 12, ground - 80 - i, 8, 10 + i), Color("2e2e2e"))
	x += 86.0
	if owned.has("skipping_ropes"):
		draw_line(Vector2(x + 10, ground * 0.3), Vector2(x + 10, ground * 0.55), Color("d24f4f"), 3.0)
		draw_line(Vector2(x + 18, ground * 0.3), Vector2(x + 18, ground * 0.58), Color("4f7fd2"), 3.0)
		draw_circle(Vector2(x + 14, ground * 0.3), 4.0, Color("5b3d2a"))
	if owned.has("floor_mats"):
		draw_circle(Vector2(x + 14, ground - 12), 12.0, Color("4a7a8c"))
		draw_circle(Vector2(x + 34, ground - 12), 12.0, Color("6a8a5c"))
	x = size.x * 0.32
	if owned.has("step_box"):
		draw_rect(Rect2(x + 140, ground - 22, 44, 22), Color("8b5a3c"))
	if owned.has("foam_rollers"):
		for i in range(3):
			draw_circle(Vector2(x + 200 + i * 18, ground - 9), 9.0, Color("3fa7a0").darkened(i * 0.1))
	x = size.x * 0.62
	if owned.has("rowing_machine"):
		draw_rect(Rect2(x, ground - 14, 120, 6), Color("3a3a40"))
		draw_circle(Vector2(x + 120, ground - 20), 14.0, Color("2b2b30"))
	if owned.has("treadmill"):
		draw_rect(Rect2(x - 20, ground - 18, 150, 14), Color("2f3236"))
		draw_line(Vector2(x + 120, ground - 18), Vector2(x + 135, ground - 90), Color("50555a"), 5.0)
		draw_rect(Rect2(x + 118, ground - 100, 34, 14), Color("50555a"))
	if owned.has("barbell_rack"):
		var rx: float = size.x * 0.77
		draw_rect(Rect2(rx, ground - 150, 8, 150), Color("555555"))
		draw_rect(Rect2(rx + 60, ground - 150, 8, 150), Color("555555"))
		draw_line(Vector2(rx - 20, ground - 110), Vector2(rx + 88, ground - 110), Color("888888"), 4.0)
		draw_rect(Rect2(rx - 28, ground - 126, 10, 32), Color("222222"))
		draw_rect(Rect2(rx + 86, ground - 126, 10, 32), Color("222222"))


func _draw_rain() -> void:
	for i in range(60):
		var x: float = fposmod(i * 37.0 + phase * 90.0 + _scroll * 0.3, size.x)
		var y: float = fposmod(i * 53.0 + phase * 400.0, size.y)
		draw_line(Vector2(x, y), Vector2(x - 5, y + 14), Color(0.85, 0.9, 1.0, 0.55), 1.5)
