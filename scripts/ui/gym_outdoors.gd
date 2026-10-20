extends RefCounted
## The places training goes outside the shed: the suburban road loop and
## the running track. Layers scroll at different speeds while a client runs
## (`scroll` is distance in pixels), so near things pass faster than far ones.
const Shapes = preload("res://scripts/ui/shapes.gd")

const HOUSE_WALLS: Array = [Color("d9b38c"), Color("c9a27e"), Color("e0c9a6"), Color("b7c4b0")]
const ROOFS: Array = [Color("a5503a"), Color("6d5a52"), Color("8e4a3a")]


static func sky(ci: CanvasItem, size: Vector2, ground: float, scroll: float, rain: bool) -> void:
	var top: Color = Color("7e8c98") if rain else Color("7fb8e2")
	var bottom: Color = Color("b8c0c4") if rain else Color("f6dcb0")
	Shapes.vgradient(ci, Rect2(0, 0, size.x, ground), top, bottom)
	if not rain:
		var sun := Vector2(size.x * 0.82, ground * 0.22)
		Shapes.glow(ci, sun, ground * 0.35, Color(1.0, 0.95, 0.75, 0.35), 7)
		ci.draw_circle(sun, ground * 0.06, Color("fff4d0"))
	for i in range(5):
		var x: float = fposmod(float(i) * 290.0 + 60.0 - scroll * 0.04, size.x + 240.0) - 120.0
		var y: float = ground * (0.12 + 0.09 * float(i % 3))
		_cloud(ci, Vector2(x, y), ground * (0.05 + 0.015 * float(i % 2)), Color("8d969c") if rain else Color(1, 1, 1, 0.85))


static func _cloud(ci: CanvasItem, at: Vector2, r: float, colour: Color) -> void:
	for puff in [Vector2(-1.4, 0.3), Vector2(-0.5, -0.4), Vector2(0.6, -0.2), Vector2(1.5, 0.35), Vector2(0.0, 0.4)]:
		ci.draw_circle(at + puff * r, r * (1.0 if puff.y < 0.0 else 0.8), colour)


## A rolling skyline of hills; `offset` makes each range a different shape.
static func hills(ci: CanvasItem, size: Vector2, base: float, height: float, scroll: float, colour: Color, offset: float) -> void:
	var points := PackedVector2Array()
	var step: float = 24.0
	var count: int = int(size.x / step) + 2
	for i in range(count):
		var x: float = float(i) * step
		var w: float = x + scroll
		var y: float = base - height * (0.55 + 0.3 * sin(w * 0.006 + offset) + 0.15 * sin(w * 0.017 + offset * 2.0))
		points.append(Vector2(x, y))
	points.append(Vector2(float(count - 1) * step, base + 2.0))
	points.append(Vector2(0.0, base + 2.0))
	Shapes.fill(ci, points, colour)


static func road(ci: CanvasItem, size: Vector2, ground: float, scroll: float, rain: bool, phase: float) -> void:
	sky(ci, size, ground, scroll, rain)
	var mist: float = 0.25 if rain else 0.0
	hills(ci, size, ground - 30.0, ground * 0.3, scroll * 0.08, Color("9bb6a0").lerp(Color("a0a8ac"), mist), 1.0)
	hills(ci, size, ground - 20.0, ground * 0.2, scroll * 0.18, Color("86ad6a").lerp(Color("8a9a8a"), mist), 4.0)
	var k: float = ground / 300.0
	for i in range(9):
		var x: float = fposmod(float(i) * 170.0 - scroll * 0.5, size.x + 340.0) - 170.0
		if i % 3 == 0:
			_house(ci, Vector2(x, ground - 22.0 * k), k, i, rain)
		elif i % 3 == 1:
			_tree(ci, Vector2(x, ground - 22.0 * k), k * (0.9 + 0.1 * float(i % 2)), rain)
		else:
			_pine(ci, Vector2(x, ground - 22.0 * k), k, rain)
	ci.draw_rect(Rect2(0, ground - 22.0 * k, size.x, 10.0 * k), Color("7da05a") if not rain else Color("6e8a5a"))
	for i in range(int(size.x / (14.0 * k)) + 2):
		var x: float = fposmod(float(i) * 14.0 * k - scroll * 0.75, size.x + 14.0 * k) - 7.0 * k
		ci.draw_rect(Rect2(x, ground - 34.0 * k, 4.0 * k, 22.0 * k), Color("efe6d4").darkened(0.15 if rain else 0.0))
	ci.draw_rect(Rect2(0, ground - 30.0 * k, size.x, 3.0 * k), Color("e2d8c4").darkened(0.15 if rain else 0.0))
	ci.draw_rect(Rect2(0, ground - 24.0 * k, size.x, 3.0 * k), Color("e2d8c4").darkened(0.15 if rain else 0.0))
	Shapes.vgradient(ci, Rect2(0, ground - 12.0 * k, size.x, 18.0 * k), Color("b8b2a8"), Color("a29c92"))
	for i in range(int(size.x / (40.0 * k)) + 2):
		var x: float = fposmod(float(i) * 40.0 * k - scroll, size.x + 40.0 * k) - 20.0 * k
		ci.draw_line(Vector2(x, ground - 12.0 * k), Vector2(x - 6.0 * k, ground + 6.0 * k), Color(0, 0, 0, 0.12), 1.0)
	ci.draw_rect(Rect2(0, ground + 6.0 * k, size.x, 5.0 * k), Color("d0ccc4"))
	ci.draw_rect(Rect2(0, ground + 11.0 * k, size.x, 2.0 * k), Color("6a6662"))
	Shapes.vgradient(ci, Rect2(0, ground + 13.0 * k, size.x, size.y - ground), Color("5d5a58").darkened(0.1 if rain else 0.0), Color("46433f"))
	for i in range(14):
		var x: float = fposmod(float(i) * 120.0 - scroll * 1.15, size.x + 120.0) - 60.0
		var y: float = ground + 13.0 * k + (size.y - ground - 13.0 * k) * 0.55
		Shapes.fill(ci, PackedVector2Array([Vector2(x, y), Vector2(x + 52.0, y), Vector2(x + 50.0, y + 4.0 * k), Vector2(x - 2.0, y + 4.0 * k)]), Color("e8e2cf"))
	if rain:
		for i in range(5):
			var x: float = fposmod(float(i) * 260.0 + 90.0 - scroll * 1.15, size.x + 260.0) - 130.0
			var puddle: Vector2 = Vector2(x, ground + 13.0 * k + (size.y - ground) * 0.3)
			Shapes.ellipse(ci, puddle, 30.0 * k, 4.0 * k, Color(0.75, 0.8, 0.88, 0.25))
			ci.draw_arc(puddle, (6.0 + fposmod(phase * 20.0 + float(i) * 7.0, 14.0)) * k, 0.0, TAU, 16, Color(1, 1, 1, 0.2), 1.0)


static func _house(ci: CanvasItem, foot: Vector2, k: float, index: int, rain: bool) -> void:
	var wall: Color = HOUSE_WALLS[index % HOUSE_WALLS.size()].darkened(0.12 if rain else 0.0)
	var roof: Color = ROOFS[index % ROOFS.size()].darkened(0.12 if rain else 0.0)
	var body := Rect2(foot + Vector2(-46.0, -64.0) * k, Vector2(92.0, 64.0) * k)
	Shapes.box(ci, body, wall, 1.0, 1.0)
	ci.draw_rect(Rect2(body.position + Vector2(64.0, -26.0) * k, Vector2(10.0, 18.0) * k), Color("8a5a46").darkened(0.12 if rain else 0.0))
	Shapes.poly(ci, PackedVector2Array([body.position + Vector2(-8.0, 2.0) * k, body.position + Vector2(46.0, -34.0) * k, body.position + Vector2(100.0, 2.0) * k]), roof, 1.0)
	for wx in [10.0, 58.0]:
		var pane := Rect2(body.position + Vector2(wx, 14.0) * k, Vector2(22.0, 18.0) * k)
		ci.draw_rect(pane.grow(2.0 * k), Color("f2ead8"))
		ci.draw_rect(pane, Color("ffd98a") if rain else Color("8cb4cc"))
		ci.draw_line(Vector2(pane.get_center().x, pane.position.y), Vector2(pane.get_center().x, pane.end.y), Color("f2ead8"), maxf(1.0, k))
	ci.draw_rect(Rect2(body.position + Vector2(39.0, 36.0) * k, Vector2(14.0, 28.0) * k), Color("4f6a7a"))
	ci.draw_circle(body.position + Vector2(50.0, 51.0) * k, maxf(1.0, k), Color("e0b86a"))


static func _tree(ci: CanvasItem, foot: Vector2, k: float, rain: bool) -> void:
	var leaf: Color = Color("5f8f4a").darkened(0.12 if rain else 0.0)
	Shapes.limb(ci, foot, foot + Vector2(0, -40.0 * k), 4.0 * k, 3.0 * k, Color("6b4a35"), 1.0)
	for puff in [Vector2(0, -62), Vector2(-16, -50), Vector2(16, -50), Vector2(-8, -74), Vector2(10, -72)]:
		ci.draw_circle(foot + puff * k, 19.0 * k + 1.0, leaf.darkened(0.45))
	for puff in [Vector2(0, -62), Vector2(-16, -50), Vector2(16, -50), Vector2(-8, -74), Vector2(10, -72)]:
		ci.draw_circle(foot + puff * k, 19.0 * k, leaf)
	for puff in [Vector2(-10, -72), Vector2(-20, -56), Vector2(4, -68)]:
		ci.draw_circle(foot + puff * k, 9.0 * k, leaf.lightened(0.12))


static func _pine(ci: CanvasItem, foot: Vector2, k: float, rain: bool) -> void:
	var leaf: Color = Color("3f6f4a").darkened(0.12 if rain else 0.0)
	ci.draw_rect(Rect2(foot + Vector2(-3.0, -14.0) * k, Vector2(6.0, 14.0) * k), Color("5b4030"))
	for tier in range(3):
		var y: float = -12.0 - float(tier) * 22.0
		var w: float = 26.0 - float(tier) * 6.0
		Shapes.poly(ci, PackedVector2Array([foot + Vector2(-w, y) * k, foot + Vector2(0, y - 36.0) * k, foot + Vector2(w, y) * k]), leaf.lightened(0.04 * float(tier)), 1.0)


static func track(ci: CanvasItem, size: Vector2, ground: float, scroll: float, rain: bool) -> void:
	sky(ci, size, ground, scroll, rain)
	var k: float = ground / 300.0
	hills(ci, size, ground - 120.0 * k, ground * 0.18, scroll * 0.08, Color("9bb6a0").lerp(Color("a0a8ac"), 0.25 if rain else 0.0), 2.0)
	var stand_top: float = ground - 150.0 * k
	ci.draw_rect(Rect2(0, stand_top, size.x, 100.0 * k), Color("6a7884"))
	Shapes.vgradient(ci, Rect2(0, stand_top - 14.0 * k, size.x, 14.0 * k), Color("e2e6ea"), Color("b0b8c0"))
	var crowd: Array = [Color("d24f4f"), Color("4f7fd2"), Color("f0b13c"), Color("e8e2cf"), Color("5f9a4a"), Color("c0567a"), Color("2b2b33")]
	for row in range(4):
		var y: float = stand_top + (14.0 + float(row) * 22.0) * k
		ci.draw_rect(Rect2(0, y + 8.0 * k, size.x, 3.0 * k), Color("56626c"))
		var gap: float = 13.0 * k
		for i in range(int(size.x / gap) + 2):
			if (i * 7 + row * 3) % 5 == 0:
				continue
			var x: float = fposmod(float(i) * gap + float(row) * 5.0 * k - scroll * 0.3, size.x + gap) - gap * 0.5
			var colour: Color = crowd[(i * 3 + row * 5) % crowd.size()]
			ci.draw_rect(Rect2(x - 3.5 * k, y + 1.0 * k, 7.0 * k, 8.0 * k), colour.darkened(0.1))
			ci.draw_circle(Vector2(x, y - 1.5 * k), 3.0 * k, Color("e0b090").darkened(float((i * 5) % 4) * 0.15))
	ci.draw_rect(Rect2(0, ground - 50.0 * k, size.x, 6.0 * k), Color("2f5a3a"))
	Shapes.vgradient(ci, Rect2(0, ground - 44.0 * k, size.x, size.y - ground + 44.0 * k), Color("c45c46"), Color("a34834"))
	for lane in range(5):
		var y: float = ground - 40.0 * k + float(lane) * 18.0 * k * (1.0 + float(lane) * 0.12)
		ci.draw_line(Vector2(0, y), Vector2(size.x, y), Color("f0e6d8"), maxf(1.5, 2.0 * k))
	for i in range(4):
		var x: float = fposmod(float(i) * 360.0 - scroll, size.x + 360.0) - 180.0
		ci.draw_line(Vector2(x, ground - 40.0 * k), Vector2(x + 26.0 * k, size.y), Color(1, 1, 1, 0.5), maxf(2.0, 3.0 * k))
	if rain:
		ci.draw_rect(Rect2(0, ground - 44.0 * k, size.x, size.y - ground + 44.0 * k), Color(0.6, 0.65, 0.75, 0.12))


static func rain(ci: CanvasItem, size: Vector2, phase: float, scroll: float) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, size), Color(0.35, 0.4, 0.5, 0.12))
	for i in range(80):
		var x: float = fposmod(float(i) * 37.0 + phase * 90.0 + scroll * 0.3, size.x)
		var y: float = fposmod(float(i) * 53.0 + phase * 400.0, size.y)
		ci.draw_line(Vector2(x, y), Vector2(x - 5.0, y + 15.0), Color(0.85, 0.9, 1.0, 0.45), 1.2)


## Race-day dressing for the road: bunting overhead and a crowd along the
## fence, cheering as the runners pass.
static func race_day(ci: CanvasItem, size: Vector2, ground: float, scroll: float, phase: float) -> void:
	var k: float = ground / 300.0
	var crowd: Array = [Color("d24f4f"), Color("4f7fd2"), Color("f0b13c"), Color("e8e2cf"), Color("5f9a4a"), Color("c0567a")]
	var skins: Array = [Color("f0c8a8"), Color("c98e66"), Color("8d5a3b"), Color("e0b090")]
	var gap: float = 22.0 * k
	for i in range(int(size.x / gap) + 2):
		if (i * 5) % 7 == 3:
			continue
		var x: float = fposmod(float(i) * gap - scroll * 0.75, size.x + gap) - gap * 0.5
		var foot: Vector2 = Vector2(x, ground - 26.0 * k)
		var hop: float = maxf(0.0, sin(phase * TAU * 2.0 + float(i))) * 3.0 * k
		var shirt: Color = crowd[(i * 3) % crowd.size()]
		var skin: Color = skins[(i * 7) % skins.size()]
		Shapes.box(ci, Rect2(foot + Vector2(-5.0, -26.0) * k - Vector2(0, hop), Vector2(10.0, 18.0) * k), shirt, 3.0 * k, 1.0)
		ci.draw_circle(foot + Vector2(0, -31.0 * k - hop), 5.0 * k, skin)
		if i % 3 == 0:
			ci.draw_line(foot + Vector2(-4.0, -24.0) * k - Vector2(0, hop), foot + Vector2(-8.0, -38.0) * k - Vector2(0, hop), skin, maxf(1.5, 2.0 * k))
			ci.draw_line(foot + Vector2(4.0, -24.0) * k - Vector2(0, hop), foot + Vector2(8.0, -38.0) * k - Vector2(0, hop), skin, maxf(1.5, 2.0 * k))
	var span: float = 260.0 * k
	var flags: Array = [Color("d24f4f"), Color("f0b13c"), Color("4f7fd2"), Color("f4ead8")]
	for i in range(int(size.x / span) + 2):
		var left: float = fposmod(float(i) * span - scroll * 0.6, size.x + span) - span
		var a := Vector2(left, ground * 0.08)
		var z := Vector2(left + span, ground * 0.08)
		var line := PackedVector2Array()
		for s in range(13):
			var t: float = float(s) / 12.0
			line.append(a.lerp(z, t) + Vector2(0, sin(t * PI) * 18.0 * k))
		ci.draw_polyline(line, Color("3a2a20"), maxf(1.0, k), true)
		for s in range(1, 12):
			var p: Vector2 = line[s]
			Shapes.fill(ci, PackedVector2Array([p + Vector2(-5.0 * k, 0), p + Vector2(5.0 * k, 0), p + Vector2(0, 10.0 * k)]), flags[(s + i) % flags.size()])
