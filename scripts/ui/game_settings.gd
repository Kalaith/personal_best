extends RefCounted
## The player's preferences (music volume, window, interface size and the
## coaching key and button) kept in user://settings.json, apart from the season save, and
## pushed to the engine whenever one changes. Builds the toolkit's settings
## page in the shed's colours, to open over any screen.
const SettingsStore = preload("res://addons/hatchery/settings/settings_store.gd")
const SettingsPanel = preload("res://addons/hatchery/ui/settings_panel.gd")
const Display = preload("res://addons/hatchery/settings/display.gd")
const Levels = preload("res://addons/hatchery/audio/levels.gd")
const KeyBindings = preload("res://addons/hatchery/input/key_bindings.gd")
const PadBindings = preload("res://addons/hatchery/input/pad_bindings.gd")
const Style = preload("res://scripts/ui/style.gd")

## The interface size slider runs from 85 % to 125 %; 0.375 is 100 %.
const SCALE_MIN: float = 0.85
const SCALE_MAX: float = 1.25
const DEFAULTS: Dictionary = {"music": 0.6, "fullscreen": false, "ui_scale": 0.375}
const SECTIONS: Array = [
	{"title": "Sound", "sliders": ["music"]},
	{"title": "Display", "sliders": ["ui_scale"], "toggles": ["fullscreen"]},
]
const ACTIONS: Dictionary = {"coach": "Coach (stop the marker)"}
const WORDS: Dictionary = {
	"setting_music": "Music", "setting_fullscreen": "Full screen", "setting_ui_scale": "Interface size",
	"settings_pad": "Gamepad button",
}

var store: SettingsStore
var tree: SceneTree


func _init(scene_tree: SceneTree, path: String = "user://settings.json") -> void:
	tree = scene_tree
	Levels.ensure_bus("Music")
	store = SettingsStore.new(DEFAULTS, path)
	store.keys = KeyBindings.new(ACTIONS)
	# B always goes back, so it cannot also coach.
	store.pad = PadBindings.new(ACTIONS, [JOY_BUTTON_B] as Array[int])


func load_and_apply() -> void:
	store.load_settings()
	store.apply_bindings()
	apply_all()


func apply_all() -> void:
	for key in DEFAULTS:
		apply(key)


## Pushes one changed value to the engine ("" applies everything).
func apply(key: String) -> void:
	match key:
		"":
			apply_all()
		"music":
			Levels.set_bus("Music", float(store.values.music))
		"fullscreen":
			Display.set_fullscreen(bool(store.values.fullscreen))
		"ui_scale":
			Display.set_ui_scale(tree, ui_scale())


func ui_scale() -> float:
	return Display.scale_from_fraction(float(store.values.ui_scale), SCALE_MIN, SCALE_MAX)


## The key that coaches right now, for "press Space" style instructions.
static func coach_key() -> String:
	var key: String = KeyBindings.hint("coach")
	return key if not key.is_empty() else "your coaching key"


## The settings page, ready to add over the current screen. A browser can
## leave full screen on its own (Esc), so the toggle starts from the window.
func make_page() -> Control:
	if not Display.is_headless():
		store.values.fullscreen = Display.is_fullscreen()
	var page := SettingsPanel.new()
	page.store = store
	page.ui = Style.ui
	page.sections = SECTIONS
	page.panel_size = Vector2(720, 560)
	page.commit_on_release = ["ui_scale"]
	page.text = func(word: String, english: String) -> String: return WORDS.get(word, english)
	page.slider_text = func(word: String, value: float) -> String:
		if word == "ui_scale":
			return "%d%%" % roundi(Display.scale_from_fraction(value, SCALE_MIN, SCALE_MAX) * 100.0)
		return "%d%%" % roundi(value * 100.0)
	page.applied.connect(apply)
	return page
