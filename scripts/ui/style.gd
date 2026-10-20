extends RefCounted
## The one look every screen is built from: a warm, wood-and-lamplight
## palette on the toolkit's UiKit, plus the few colours the game gives
## meaning to (signals, tones and attribute bars).
const Palette = preload("res://addons/hatchery/ui/palette.gd")
const UiKit = preload("res://scripts/ui/shed_kit.gd")

const GREEN := Color("7fcf6a")
const AMBER := Color("f0b13c")
const RED := Color("e0584a")
const PUSH := Color("e2803a")
const HOLD := Color("4f8fd0")
const INK := Color("2b211c")
const PAPER := Color("f4ead8")
const MUTED := Color("c4b196")
const ACCENT := Color("f0a35a")

static var ui: UiKit = UiKit.new(_palette())


static func _palette() -> Palette:
	var p := Palette.new()
	p.background = Color("2b211c")
	p.panel = Color("3a2d26")
	p.panel_light = Color("4b3b31")
	p.line = Color("6e5646")
	p.text = PAPER
	p.muted = MUTED
	p.accent = ACCENT
	p.good = GREEN
	p.warn = AMBER
	p.bad = RED
	p.button_fill = Color("4b3b31")
	p.button_primary = Color("8a4f2a")
	p.button_pressed = Color("a8622f")
	p.button_disabled = Color("332822")
	p.body_size = 17
	p.heading_size = 30
	# Tall enough to tap when the canvas is shrunk onto a phone.
	p.control_height = 50
	return p


static func make_theme() -> Theme:
	return ui.theme()


static func signal_color(signal_id: String) -> Color:
	return {"green": GREEN, "amber": AMBER, "red": RED}.get(signal_id, MUTED)


static func tone_color(tone: String) -> Color:
	return {"good": GREEN, "warn": AMBER, "bad": RED, "tip": Color("9cc4e4")}.get(tone, PAPER)


static func tone_mark(tone: String) -> String:
	return {"good": "+", "warn": "!", "bad": "×", "tip": "•"}.get(tone, "•")


## A full-rect screen with the backdrop, a margin and a vertical column.
static func screen(host: Control, separation: int = 12, margin: int = 28) -> VBoxContainer:
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.backdrop(host)
	var frame := MarginContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		frame.add_theme_constant_override("margin_" + side, margin)
	host.add_child(frame)
	var column: VBoxContainer = ui.vbox(separation)
	frame.add_child(column)
	return column


## A row for a value that changed: "34 → 41 (+7)" coloured by direction,
## the arrow drawn larger than the numbers so it still reads on a phone.
static func change_label(before: float, after: float, size: int = 15, suffix: String = "", higher_is_good: bool = true) -> HBoxContainer:
	var delta: float = after - before
	var colour: Color = MUTED
	if absf(delta) >= 0.5:
		colour = GREEN if (delta > 0.0) == higher_is_good else RED
	var row: HBoxContainer = ui.hbox(4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(ui.utility("%d" % int(round(before)), size, colour))
	row.add_child(ui.utility("→", size + 8, colour))
	row.add_child(ui.utility("%d%s  (%s%d)" % [int(round(after)), suffix, "+" if delta >= 0.0 else "", int(round(delta))], size, colour))
	for part in row.get_children():
		part.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return row


## A stretch of rich text in the body colour, word-wrapped and sized to fit.
static func rich(bbcode: String, size: int = -1) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.text = bbcode
	var shown: int = ui.readable(ui.palette.body_size if size < 0 else size)
	label.add_theme_font_size_override("normal_font_size", shown)
	label.add_theme_font_size_override("bold_font_size", shown)
	label.add_theme_color_override("default_color", PAPER)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


static func hex(colour: Color) -> String:
	return colour.to_html(false)
