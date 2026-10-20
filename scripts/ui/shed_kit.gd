extends "res://addons/hatchery/ui/ui_kit.gd"
## The toolkit's UiKit with every small size lifted so the shed still reads
## when the 1280×800 canvas is shrunk onto a phone. Screens keep asking for
## the sizes they always did; anything under heading size comes out larger,
## and the small-to-large order between sizes is kept.

## Sizes at or above this are left alone (headings already read on a phone).
const LIFT_UNTIL: int = 24


## The size a screen asked for, lifted for a phone: 13 → 17, 15 → 19,
## 17 → 20, 20 → 22, 24 and up unchanged.
static func readable(size: int) -> int:
	if size >= LIFT_UNTIL:
		return size
	return maxi(size, roundi(size * 0.6 + 9.6))


func label(value: String, size: int = -1, color: Variant = null) -> Label:
	return super.label(value, readable(palette.body_size if size < 0 else size), color)


func button(value: String, callback: Callable = Callable(), primary: bool = false, size: int = -1) -> Button:
	return super.button(value, callback, primary, readable(palette.body_size + 2 if size < 0 else size))


func toggle(value: String, callback: Callable = Callable(), size: int = -1) -> CheckButton:
	return super.toggle(value, callback, readable(palette.body_size + 1 if size < 0 else size))


func rich_heading(value: String, size: int = -1, color: Variant = null) -> String:
	return super.rich_heading(value, readable(palette.body_size + 6 if size < 0 else size), color)


## Controls the kit does not build (exercise pickers, tabs, popups) read at
## the lifted body size too.
func theme() -> Theme:
	var result: Theme = super.theme()
	result.default_font_size = readable(palette.body_size)
	return result
