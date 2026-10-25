extends RefCounted
## The player's preferences (music volume, window, interface size and the
## coaching key and button) kept in user://settings.json, apart from the season save, and
## pushed to the engine whenever one changes. Builds the toolkit's settings
## page in the shed's colours, to open over any screen.
const SettingsStore = preload("res://addons/hatchery/settings/settings_store.gd")
const SettingsPanel = preload("res://addons/hatchery/ui/settings_panel.gd")
const Display = preload("res://addons/hatchery/settings/display.gd")
const EngineSettings = preload("res://addons/hatchery/settings/engine_settings.gd")
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
var engine: EngineSettings


func _init(scene_tree: SceneTree, path: String = "user://settings.json") -> void:
	store = SettingsStore.new(DEFAULTS, path)
	engine = EngineSettings.new(store, scene_tree, {"Music": "music"})
	engine.scale_min = SCALE_MIN
	engine.scale_max = SCALE_MAX
	store.keys = KeyBindings.new(ACTIONS)
	# B always goes back, so it cannot also coach.
	store.pad = PadBindings.new(ACTIONS, [JOY_BUTTON_B] as Array[int])


func load_and_apply() -> void:
	store.load_settings()
	store.apply_bindings()
	apply_all()


func apply_all() -> void:
	engine.apply_all()


## Pushes one changed value to the engine ("" applies everything).
func apply(key: String) -> void:
	engine.apply(key)


func ui_scale() -> float:
	return engine.ui_scale()


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
	page.slider_text = engine.slider_text
	page.applied.connect(apply)
	return page
