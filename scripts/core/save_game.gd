extends RefCounted
## The campaign save: one JSON file under user://, written at the weekly
## planner. Leaving mid-week replays that week from its start; every roll is
## seeded by week, so it plays out the same way given the same choices.
const JsonSave = preload("res://addons/hatchery/storage/json_save.gd")
const DataRules = preload("res://addons/hatchery/core/data_rules.gd")
const Catalog = preload("res://scripts/core/catalog.gd")

const PATH: String = "user://personal_best_save.json"
const VERSION: int = 1

var store: JsonSave
var catalog: Catalog


func _init(source: Catalog) -> void:
	catalog = source
	store = JsonSave.new(PATH, VERSION, _valid)
	store.schema_key = "schema_version"
	store.noun = "the season save"


func has_save() -> bool:
	return not load_data().is_empty()


## The saved campaign (as GameState.to_dict) or {} when there is none.
func load_data() -> Dictionary:
	var data: Dictionary = store.load_data()
	return data.get("game", {}) if not data.is_empty() else {}


func save(game_data: Dictionary) -> bool:
	return store.save_data({"schema_version": VERSION, "game": game_data})


func last_error() -> String:
	return store.last_error


func _valid(data: Dictionary) -> bool:
	if not data.get("game") is Dictionary:
		return false
	var game: Dictionary = data.game
	var errors: Array[String] = []
	var rules := DataRules.new(errors, "save")
	rules.one_of(game, "phase", ["intake", "planner", "done"])
	rules.integer_between(game, "week", 1, 12)
	rules.integer(game, "cash")
	rules.integer(game, "rep_points")
	rules.integer(game, "seed")
	rules.integer_between(game, "intake_done", 0, 10)
	rules.text(game, "weather")
	for key in ["owned", "pending", "notes"]:
		rules.list(game, key)
	if rules.list(game, "clients", false):
		for entry in game.clients:
			_check_client(rules, entry)
	if errors.is_empty():
		for id in game.owned + game.pending:
			if not catalog.shop_items.has(id) and not catalog.starting_equipment.any(func(item: Dictionary) -> bool: return item.id == id):
				errors.append("unknown equipment " + str(id))
	return errors.is_empty()


func _check_client(rules: DataRules, entry: Variant) -> void:
	if not entry is Dictionary or catalog.client(str(entry.get("id"))).is_empty():
		rules.fail("unknown client")
		return
	for key in ["fatigue", "motivation", "rapport"]:
		rules.number_between(entry, key, 0.0, 100.0)
	for key in ["injured_weeks", "sessions_done", "fees_paid", "bonuses_paid"]:
		rules.integer(entry, key)
	for key in ["trained_this_week", "new_injury"]:
		rules.boolean(entry, key)
	for key in ["routine", "milestones", "readiness_history"]:
		rules.list(entry, key)
	rules.object(entry, "event_result")
	if not entry.get("routine_block") is String or not entry.get("booked_day") is String:
		rules.fail("routine_block and booked_day must be text")
	if rules.object(entry, "attributes"):
		for attribute in Catalog.ATTRIBUTES:
			rules.number_between(entry.attributes, attribute, 0.0, 100.0)
	if entry.get("routine") is Array:
		for item in entry.routine:
			if not item is Dictionary or not catalog.exercises.has(item.get("exercise")) or not DataRules.whole(item.get("sets")):
				rules.fail("bad routine entry")
