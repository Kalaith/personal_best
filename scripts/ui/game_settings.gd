extends "res://addons/hatchery/settings/settings_bundle.gd"
## The player's preferences (music volume, window, interface size and the
## coaching key and button) kept in user://settings.json, apart from the season save, and
## pushed to the engine whenever one changes. Builds the toolkit's settings
## page in the shed's colours, to open over any screen.
const KeyBindings = preload("res://addons/hatchery/input/key_bindings.gd")
const PadBindings = preload("res://addons/hatchery/input/pad_bindings.gd")
const Style = preload("res://scripts/ui/style.gd")
const SignalsClient = preload("res://addons/hatchery/telemetry/signals_client.gd")

## The interface size slider runs from 85 % to 125 %; 0.375 is 100 %.
const SCALE_MIN: float = 0.85
const SCALE_MAX: float = 1.25
const DEFAULTS: Dictionary = {"music": 0.6, "fullscreen": false, "ui_scale": 0.375, SignalsClient.SETTING_KEY: true}
const SECTIONS: Array = [
	{"title": "Sound", "sliders": ["music"]},
	{"title": "Display", "sliders": ["ui_scale"], "toggles": ["fullscreen", SignalsClient.SETTING_KEY]},
]
const ACTIONS: Dictionary = {"coach": "Coach (stop the marker)"}
const WORDS: Dictionary = {
	"setting_music": "Music", "setting_fullscreen": "Full screen", "setting_ui_scale": "Interface size",
	"settings_pad": "Gamepad button", "setting_" + SignalsClient.SETTING_KEY: SignalsClient.SETTING_LABEL,
}


func _init(scene_tree: SceneTree, path: String = "user://settings.json") -> void:
	super(DEFAULTS, scene_tree, {"Music": "music"}, path)
	engine.scale_min = SCALE_MIN
	engine.scale_max = SCALE_MAX
	sections = SECTIONS
	words = WORDS
	panel_size = Vector2(720, 560)
	store.keys = KeyBindings.new(ACTIONS)
	# B always goes back, so it cannot also coach.
	store.pad = PadBindings.new(ACTIONS, [JOY_BUTTON_B] as Array[int])


## The key that coaches right now, for "press Space" style instructions.
static func coach_key() -> String:
	var key: String = KeyBindings.hint("coach")
	return key if not key.is_empty() else "your coaching key"


## The settings page in the shed's colours.
func make_page(ui: UiKit = null) -> SettingsPanel:
	return super(ui if ui != null else Style.ui)
