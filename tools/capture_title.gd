extends "res://addons/hatchery/testing/title_capture.gd"
## Focused, silent windowed capture of the real startup screen (the toolkit's
## title capture).
## Run with --audio-driver Dummy --script res://tools/capture_title.gd [-- --details].


func window_size() -> Vector2i:
	return Vector2i(1280, 800)


func label() -> String:
	return "01_title"


## With --details: the question a new game asks over an existing save.
func details() -> void:
	main.screens.current.has_save = true
	await main.screens.current._ask_new()
	await seconds(0.3)
	await shot("title_new_game")
