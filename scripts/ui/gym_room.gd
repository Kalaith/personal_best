extends RefCounted
## The inside of the shed: board-and-batten walls lit by one hanging bulb,
## a window onto the garden (or the rain), the door, a whiteboard counting
## down the weeks, and a rubber-tiled floor. `k` is the scale of things on
## the back wall (1.0 is a 100-pixel person).
const Shapes = preload("res://scripts/ui/shapes.gd")

const BOARD := Color("a8774f")
const BEAM := Color("5e3f2b")
const FRAME := Color("5b3d2a")
const FLOOR_NEAR := Color("4b433c")
const FLOOR_FAR := Color("61574e")


## Walls, window, door, lamp and floor. `wall_base` is where the back wall
## meets the floor; `ground` is where the people stand.
static func draw(ci: CanvasItem, size: Vector2, wall_base: float, ground: float, k: float, phase: float, rain: bool) -> void:
	_walls(ci, size, wall_base, k)
	_window(ci, Rect2(size.x * 0.58, wall_base * 0.17, size.x * 0.17, wall_base * 0.4), k, phase, rain)
	var board_w: float = minf(size.x * 0.13, 92.0 * k)
	_whiteboard(ci, Rect2(size.x * 0.36, wall_base * 0.22, board_w, board_w * 0.62), k)
	_door(ci, Rect2(size.x * 0.875, wall_base - wall_base * 0.78, size.x * 0.1, wall_base * 0.78), k)
	_floor(ci, size, wall_base, ground, k)
	_lamp(ci, Vector2(size.x * 0.46, 0.0), wall_base, k, rain)


static func _walls(ci: CanvasItem, size: Vector2, wall_base: float, k: float) -> void:
	Shapes.vgradient(ci, Rect2(0, 0, size.x, wall_base), BOARD.darkened(0.12), BOARD.darkened(0.02))
	var plank: float = maxf(22.0, 30.0 * k)
	var count: int = int(size.x / plank) + 1
	for i in range(count):
		var x: float = float(i) * plank
		var tone: float = float((i * 37) % 5) * 0.025 - 0.05
		ci.draw_rect(Rect2(x, 0, plank, wall_base), Color(BOARD.darkened(maxf(tone, 0.0)).lightened(maxf(-tone, 0.0)), 0.55))
		for g in range(2):
			var gx: float = x + plank * (0.3 + 0.35 * float(g)) + float((i * 13 + g * 7) % 5)
			ci.draw_line(Vector2(gx, wall_base * 0.05), Vector2(gx + 1.5, wall_base), Color(0.35, 0.22, 0.13, 0.12), 1.0)
		if (i * 7) % 5 == 2:
			Shapes.ellipse(ci, Vector2(x + plank * 0.55, wall_base * (0.3 + float(i % 3) * 0.17)), 2.5 * k, 4.0 * k, Color(0.35, 0.22, 0.13, 0.28))
		ci.draw_line(Vector2(x, 0), Vector2(x, wall_base), Color("7d5236"), 2.0)
		ci.draw_line(Vector2(x + 2.0, 0), Vector2(x + 2.0, wall_base), Color(1, 0.9, 0.7, 0.08), 1.0)
	var beam_h: float = maxf(10.0, wall_base * 0.075)
	Shapes.vgradient(ci, Rect2(0, 0, size.x, beam_h), BEAM.darkened(0.25), BEAM)
	ci.draw_line(Vector2(0, beam_h), Vector2(size.x, beam_h), BEAM.darkened(0.4), 2.0)
	var rail_y: float = wall_base * 0.62
	ci.draw_rect(Rect2(0, rail_y, size.x, maxf(4.0, 5.0 * k)), Color("8d6040"))
	ci.draw_line(Vector2(0, rail_y + maxf(4.0, 5.0 * k)), Vector2(size.x, rail_y + maxf(4.0, 5.0 * k)), Color(0.2, 0.12, 0.07, 0.35), 2.0)
	ci.draw_rect(Rect2(0, wall_base - 8.0 * k, size.x, 8.0 * k), Color("6d4a33"))
	ci.draw_line(Vector2(0, wall_base - 8.0 * k), Vector2(size.x, wall_base - 8.0 * k), Color("8d6040"), 1.5)
	for side in [0.0, 1.0]:
		var edge := Rect2(side * (size.x - size.x * 0.08), 0, size.x * 0.08, wall_base)
		var outer := Color(0.1, 0.06, 0.03, 0.35)
		var inner := Color(0.1, 0.06, 0.03, 0.0)
		ci.draw_polygon(PackedVector2Array([edge.position, edge.position + Vector2(edge.size.x, 0), edge.end, edge.position + Vector2(0, edge.size.y)]),
			PackedColorArray([outer, inner, inner, outer] if side == 0.0 else [inner, outer, outer, inner]))


static func _window(ci: CanvasItem, glass: Rect2, k: float, phase: float, rain: bool) -> void:
	var frame: float = maxf(4.0, 6.0 * k)
	Shapes.vgradient(ci, glass, Color("7d8c98") if rain else Color("8cc4e8"), Color("aab4ba") if rain else Color("d8ecf6"))
	var hill := PackedVector2Array()
	for i in range(9):
		var t: float = float(i) / 8.0
		hill.append(Vector2(glass.position.x + glass.size.x * t, glass.end.y - glass.size.y * (0.3 + 0.08 * sin(t * 5.0))))
	hill.append(glass.end)
	hill.append(Vector2(glass.position.x, glass.end.y))
	Shapes.fill(ci, hill, Color("6f8f5a") if rain else Color("86b06a"))
	var tree: Vector2 = glass.position + Vector2(glass.size.x * 0.72, glass.size.y * 0.5)
	ci.draw_line(tree, tree + Vector2(0, glass.size.y * 0.25), Color("5b4030"), maxf(2.0, 2.5 * k))
	ci.draw_circle(tree, glass.size.y * 0.17, Color("4f7a40") if rain else Color("5f9a4a"))
	ci.draw_circle(tree + Vector2(-glass.size.y * 0.08, -glass.size.y * 0.06), glass.size.y * 0.11, Color("5a8a48") if rain else Color("74b058"))
	for i in range(6):
		var px: float = glass.position.x + glass.size.x * (0.05 + 0.18 * float(i))
		ci.draw_line(Vector2(px, glass.end.y - glass.size.y * 0.16), Vector2(px, glass.end.y), Color("d8c8a8"), maxf(2.0, 2.0 * k))
	ci.draw_line(Vector2(glass.position.x, glass.end.y - glass.size.y * 0.12), Vector2(glass.end.x, glass.end.y - glass.size.y * 0.12), Color("d8c8a8"), maxf(1.5, 1.5 * k))
	if rain:
		for i in range(16):
			var x: float = glass.position.x + fposmod(float(i) * 23.0 + phase * 40.0, glass.size.x)
			var y: float = glass.position.y + fposmod(float(i) * 37.0 + phase * 160.0, glass.size.y)
			ci.draw_line(Vector2(x, y), Vector2(x - 2.0, minf(y + 10.0 * k, glass.end.y)), Color(1, 1, 1, 0.45), 1.0)
	else:
		ci.draw_line(glass.position + Vector2(glass.size.x * 0.1, glass.size.y * 0.6), glass.position + Vector2(glass.size.x * 0.35, glass.size.y * 0.1), Color(1, 1, 1, 0.3), maxf(2.0, 4.0 * k))
		ci.draw_line(glass.position + Vector2(glass.size.x * 0.25, glass.size.y * 0.65), glass.position + Vector2(glass.size.x * 0.42, glass.size.y * 0.3), Color(1, 1, 1, 0.18), maxf(1.0, 2.0 * k))
	ci.draw_rect(glass.grow(frame * 0.5), FRAME, false, frame)
	ci.draw_line(Vector2(glass.get_center().x, glass.position.y), Vector2(glass.get_center().x, glass.end.y), FRAME, frame * 0.7)
	ci.draw_line(Vector2(glass.position.x, glass.get_center().y), Vector2(glass.end.x, glass.get_center().y), FRAME, frame * 0.5)
	Shapes.box(ci, Rect2(glass.position.x - frame * 2.0, glass.end.y + frame * 0.5, glass.size.x + frame * 4.0, frame * 1.2), Color("7a5236"), 1.0, 1.0)


static func _whiteboard(ci: CanvasItem, board: Rect2, k: float) -> void:
	Shapes.box(ci, board.grow(3.0 * k), Color("9aa0a6"), 2.0 * k, 1.0)
	ci.draw_rect(board, Color("f4f2ec"))
	var weeks: int = 12
	var cell: float = board.size.x * 0.84 / float(weeks)
	for i in range(weeks):
		var x: float = board.position.x + board.size.x * 0.08 + cell * float(i)
		var y: float = board.position.y + board.size.y * 0.22
		var tick := Rect2(x + 1, y, cell - 2, board.size.y * 0.16)
		if i < 4:
			ci.draw_rect(tick, Color("3a6fb0"))
		else:
			ci.draw_rect(tick, Color("c9c4bb"), false, 1.0)
	var line := PackedVector2Array()
	for i in range(7):
		var t: float = float(i) / 6.0
		line.append(board.position + Vector2(board.size.x * (0.1 + 0.8 * t), board.size.y * (0.86 - 0.36 * t * t - 0.05 * sin(t * 9.0))))
	ci.draw_polyline(line, Color("d0453a"), maxf(1.0, 1.5 * k), true)
	ci.draw_line(board.position + Vector2(board.size.x * 0.1, board.size.y * 0.5), board.position + Vector2(board.size.x * 0.1, board.size.y * 0.88), Color("555a60"), 1.0)
	ci.draw_line(board.position + Vector2(board.size.x * 0.1, board.size.y * 0.88), board.position + Vector2(board.size.x * 0.92, board.size.y * 0.88), Color("555a60"), 1.0)
	Shapes.box(ci, Rect2(board.position.x + board.size.x * 0.2, board.end.y + 3.0 * k, board.size.x * 0.6, 3.0 * k), Color("9aa0a6"), 1.0, 0.0)
	ci.draw_line(Vector2(board.position.x + board.size.x * 0.3, board.end.y + 3.0 * k), Vector2(board.position.x + board.size.x * 0.4, board.end.y + 3.0 * k), Color("2f62b8"), maxf(2.0, 2.0 * k))


static func _door(ci: CanvasItem, door: Rect2, k: float) -> void:
	var trim: float = maxf(4.0, 6.0 * k)
	ci.draw_rect(Rect2(door.position - Vector2(trim, trim), door.size + Vector2(trim * 2.0, trim)), FRAME.darkened(0.1))
	Shapes.vgradient(ci, door, Color("74503a"), Color("634330"))
	for row in range(2):
		var panel := Rect2(door.position + Vector2(door.size.x * 0.16, door.size.y * (0.08 + 0.48 * float(row))), Vector2(door.size.x * 0.68, door.size.y * 0.38))
		ci.draw_rect(panel, Color("5c3e2c"))
		ci.draw_line(panel.position, panel.position + Vector2(panel.size.x, 0), Color(0, 0, 0, 0.3), 2.0)
		ci.draw_line(panel.position + Vector2(0, panel.size.y), panel.end, Color(1, 0.9, 0.7, 0.15), 2.0)
	var knob: Vector2 = door.position + Vector2(door.size.x * 0.14, door.size.y * 0.53)
	Shapes.box(ci, Rect2(knob - Vector2(2.5, 7.0) * k, Vector2(5.0, 14.0) * k), Color("b08a4a"), 2.0 * k, 1.0)
	ci.draw_circle(knob, 3.2 * k, Color("e0b86a"))
	for y in [0.12, 0.85]:
		ci.draw_rect(Rect2(door.end.x - 3.0 * k, door.position.y + door.size.y * y, 3.0 * k, 9.0 * k), Color("3a3a3a"))


static func _floor(ci: CanvasItem, size: Vector2, wall_base: float, ground: float, k: float) -> void:
	var floor_rect := Rect2(0, wall_base, size.x, size.y - wall_base)
	Shapes.vgradient(ci, floor_rect, FLOOR_FAR, FLOOR_NEAR)
	var centre: float = size.x * 0.5
	var tile: float = maxf(36.0, 64.0 * k)
	var count: int = int(size.x / tile) + 4
	for i in range(-count / 2, count / 2 + 1):
		var x: float = centre + float(i) * tile
		ci.draw_line(Vector2(x, wall_base), Vector2(centre + (x - centre) * 1.6, size.y), Color(0, 0, 0, 0.16), 1.5)
	var depth: float = size.y - wall_base
	for row in range(1, 4):
		var t: float = pow(float(row) / 4.0, 1.4)
		ci.draw_line(Vector2(0, wall_base + depth * t), Vector2(size.x, wall_base + depth * t), Color(0, 0, 0, 0.12), 1.5)
	ci.draw_line(Vector2(0, wall_base), Vector2(size.x, wall_base), Color("3a2c22"), 2.0)
	var shine := Rect2(size.x * 0.3, wall_base + 2.0, size.x * 0.36, depth * 0.5)
	Shapes.ellipse(ci, shine.get_center(), shine.size.x * 0.5, shine.size.y * 0.5, Color(1.0, 0.85, 0.55, 0.06))


## The bulb on its flex with a tin shade, and the warm pool it throws.
static func _lamp(ci: CanvasItem, top: Vector2, wall_base: float, k: float, rain: bool) -> void:
	var bulb: Vector2 = top + Vector2(0, wall_base * 0.17)
	var warmth: float = 0.55 if rain else 0.4
	Shapes.glow(ci, bulb + Vector2(0, wall_base * 0.25), wall_base * 0.75, Color(1.0, 0.82, 0.5, 0.22 * warmth / 0.4), 8)
	ci.draw_line(top, bulb - Vector2(0, 6.0 * k), Color("2a2018"), maxf(1.5, 1.5 * k))
	Shapes.glow(ci, bulb + Vector2(0, 3.0 * k), 22.0 * k, Color(1.0, 0.9, 0.6, 0.5), 5)
	var shade := PackedVector2Array([bulb + Vector2(-3.0, -7.0) * k, bulb + Vector2(3.0, -7.0) * k, bulb + Vector2(10.0, 1.0) * k, bulb + Vector2(-10.0, 1.0) * k])
	Shapes.poly(ci, shade, Color("3d5a4a"), 1.0)
	ci.draw_circle(bulb + Vector2(0, 2.5 * k), 4.0 * k, Color("fff1c4"))
